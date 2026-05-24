# LiseAI — Offline Sync Strategy

> Version 1.0.0 · 2026-05-24
> Applies to: Flutter client ↔ Supabase PostgREST

---

## Overview

LiseAI uses a **local-first, async-push** sync model:

```
[User Action]
     │
     ▼
[Write to Hive (local)]   ← always succeeds, zero latency
     │
     ▼
[Push to Supabase]         ← async, may fail
     │
   ┌─┴────────────┐
   │ Success       │ Failure
   ▼               ▼
[Update         [Enqueue in
 sync_version]   offline queue]
                   │
                   ▼
               [Flush on reconnect]
```

The user **never waits** for the network. All reads come from local Hive. Supabase is a durable backup and cross-device sync layer.

---

## 1. Sync Versioning

### Per-row `sync_version` counter
Every table row carries a `sync_version bigint` that starts at 0 and is incremented by a PostgreSQL trigger on every UPDATE:

```sql
CREATE TRIGGER bump_sync_version
BEFORE UPDATE ON conversations
FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*)
EXECUTE FUNCTION trigger_bump_sync_version();
```

The client caches the last known `sync_version` for each row in Hive. When pushing an update:

```
Client sends:  { payload, client_sync_version: N }
Server checks: current_db_version == N ?
  Yes → apply, return new version N+1
  No  → conflict → log to sync_queue, return 409
```

### Client sync state (Hive)
```dart
// Stored per-table in Hive
Map<String, int> syncVersionCache = {
  'conversations/uuid-abc': 3,
  'student_profiles/uuid-xyz': 12,
};
```

### `client_id` tagging
Every write includes a `client_id` — an opaque string identifying the device (e.g. `ios-{install-uuid}`). This allows the server and other clients to know which device last wrote a row, enabling intelligent conflict display.

---

## 2. Last-Write-Wins (LWW)

**Applies to:** `conversations`, `conversation_messages`, `lesson_sessions`, `streaks`, `achievements`

LWW is used when data loss risk is low and simplicity is preferred.

### Implementation
```dart
// Client push via SupabaseSyncAdapter
await client.from('conversations').upsert(
  { 'id': id, 'title': title, 'updated_at': now, ... },
  onConflict: 'id',
);
```

On the server, the PostgREST upsert resolves to:
```sql
INSERT INTO conversations (...) VALUES (...)
ON CONFLICT (id) DO UPDATE SET ... WHERE EXCLUDED.updated_at > conversations.updated_at;
```

The `WHERE EXCLUDED.updated_at > conversations.updated_at` guard means an older write from a slow client cannot overwrite a newer write from a faster client.

### When LWW is safe
- Scalar fields that the user explicitly sets (title, grade_level, lesson_mode).
- Session outcome metrics (success_rate, duration_secs) — last session always wins.
- Streak counters — the device with `last_study_date = today` wins.

### When LWW is NOT safe
Arrays and maps that grow independently on multiple devices (see Merge Strategy).

---

## 3. Merge Strategy

**Applies to:** `student_profiles`, `memory_items`

When two devices independently add items to an array (e.g. `weak_topics`), LWW would silently drop one device's additions. Merge strategy unions the arrays:

```dart
// SupabaseSyncService.mergeProfile()
final remote = await syncAdapter.pull(collection: 'student_profiles', id: userId);
final local  = localProfile;

final merged = StudentProfile(
  weakTopics:   {...local.weakTopics, ...remote.weakTopics}.toList(),
  strongTopics: {...local.strongTopics, ...remote.strongTopics}.toList(),
  masteryMap:   _mergeMax(local.masteryMap, remote.masteryMap),
  // scalar fields: take the one with newer updated_at
  avgConfidence: local.updatedAt.isAfter(remote.updatedAt)
                 ? local.avgConfidence
                 : remote.avgConfidence,
);
```

```dart
// masteryMap merge: max value wins per topic
Map<String, double> _mergeMax(Map a, Map b) {
  final result = Map<String, double>.from(a);
  b.forEach((k, v) {
    result[k] = max(result[k] ?? 0.0, v as double);
  });
  return result;
}
```

The merged result is pushed back to Supabase and written to local Hive atomically.

---

## 4. Soft Delete

All user-generated content uses soft delete (`deleted_at timestamptz`). Hard deletes are performed only by server-side retention jobs.

### Why soft delete?
1. **Offline safety**: a delete on Device A while Device B is offline doesn't cause a ghost row on B — B pulls `deleted_at = now()` and hides the row locally.
2. **Undo**: accidental deletes can be recovered within the retention window.
3. **Analytics integrity**: `lesson_sessions` and `conversation_messages` with `deleted_at` set still contribute to aggregate stats.

### Client handling
```dart
// Soft delete — always succeeds locally
await hive.put(convId, conv.copyWith(deletedAt: DateTime.now()));

// Push soft delete to server
await syncAdapter.push(
  collection: 'conversations',
  id: convId,
  data: {'deleted_at': DateTime.now().toIso8601String()},
);
```

### Permanent delete (GDPR)
When a user requests account deletion, a Supabase Edge Function:
1. Sets `users.deleted_at = now()`.
2. After 30-day grace period, hard-deletes the `users` row.
3. CASCADE propagates to all child tables automatically.
4. `auth.users` row is deleted via `supabase.auth.admin.deleteUser(uid)`.

---

## 5. Offline Queue

### Local queue (Hive)
The `SupabaseSyncService` maintains a persisted queue in Hive box `sync_queue_v1`. Each entry is a `_QueuedOp`:

```dart
class _QueuedOp {
  final String collection;
  final String id;
  final Map<String, dynamic> data;
  final int enqueuedAt;
}
```

### Queue lifecycle

```
[Network fail]
     │
     ▼
_enqueue(collection, id, data)        ← persisted to Hive immediately
     │
[App restart / connectivity restore]
     │
     ▼
SupabaseSyncService.flush()
     │
     ├── for each queued op:
     │     push() → success → delete from queue
     │              failure → increment retry_count
     │
     └── status = synced (queue empty) | offline (queue not empty)
```

### Retry policy
- Max retries: **5** (configurable via `sync_queue.max_retries`)
- Backoff: 2ˢ seconds (1, 2, 4, 8, 16 seconds)
- After 5 failures: logged as `failed` in `sync_queue`; user is notified via `SyncStatusBadge`

### Cross-device queue (server-side)
Every op that passes through `SupabaseSyncService.push()` is mirrored to the `sync_queue` Supabase table as an audit log. This enables:
- Debugging sync issues in production
- Future server-side replay for conflict resolution

---

## 6. Conflict Detection & Resolution

### Detection
A conflict occurs when:
```
client_sync_version != server_current_sync_version
```

This means another client wrote the row after the current client last synced.

### Resolution decision tree

```
Conflict detected
      │
      ├── Table: student_profiles, memory_items
      │         → Merge strategy (Section 3)
      │
      ├── Table: subscriptions, feature_flags
      │         → Server wins (client discards local state)
      │
      ├── Table: conversations (title only)
      │         → LWW: newer updated_at wins
      │
      ├── Table: conversation_messages
      │         → Append-only: no conflict possible (inserts only)
      │
      └── Other tables
              → LWW: newer updated_at wins
```

### Conflict logging
```dart
// Logged to server sync_queue table
{
  'user_id': uid,
  'operation': 'upsert',
  'target_table': 'student_profiles',
  'record_id': profileId,
  'client_sync_version': N,
  'conflict_detected': true,
  'conflict_resolution': 'merge',
  'payload': mergedPayload,
}
```

### `SyncStatus.conflict` state
When a conflict cannot be automatically resolved, `SupabaseSyncService.status` becomes `SyncStatus.conflict` and the `SyncStatusBadge` displays an alert. In the initial implementation, all conflicts are auto-resolved — manual conflict UI is a future feature.

---

## 7. Sync Status State Machine

```
                    ┌──────────────┐
              ┌────►│  localOnly   │ ← isConfigured = false
              │     └──────────────┘
              │
              │     ┌──────────────┐
    init() ───┼────►│   offline    │ ← isConfigured = true, no network
              │     └──────┬───────┘
              │            │ network restore → flush()
              │            ▼
              │     ┌──────────────┐
              ├────►│   syncing    │ ← push/pull in progress
              │     └──────┬───────┘
              │            │
              │     ┌──────┴───────┐
              │     │              │
              │     ▼              ▼
              │  ┌──────────┐  ┌──────────┐
              │  │  synced  │  │ conflict │
              │  └────┬─────┘  └────┬─────┘
              │       │             │ auto-resolve
              │       │             ▼
              └───────┴──────────►synced
```

---

## 8. Per-Table Sync Policy

| Table | Strategy | Conflict | Push Auth | Pull |
|---|---|---|---|---|
| `users` | LWW | server_wins | self only | on init |
| `student_profiles` | Merge | merge arrays | self only | on session start |
| `conversations` | LWW | LWW | self only | on demand |
| `conversation_messages` | Append-only | N/A (inserts) | self only | on conv open |
| `lesson_sessions` | LWW | LWW | self only | never (write-only) |
| `memory_items` | Merge | merge | self only | on session start |
| `achievements` | LWW | LWW | self only | on demand |
| `streaks` | LWW | LWW | self only | on app start |
| `analytics_events` | Append-only | N/A | self only | never (write-only) |
| `sync_queue` | Append-only | N/A | self only | on flush |
| `subscriptions` | Server wins | server_wins | service_role | on app start |
| `feature_flags` | Server wins | server_wins | service_role | on app start |

---

## 9. Data Flow Diagram

```
Device A                    Supabase                    Device B
   │                           │                           │
   │ write(conv.title="Math")  │                           │
   ├──────────────────────────►│                           │
   │ sync_version: 3→4         │                           │
   │                           │                           │
   │                           │◄──────────────────────────┤
   │                           │ write(conv.title="Fizik") │
   │                           │ [conflict: version=3≠4]   │
   │                           │                           │
   │                           │ LWW: "Math" wins          │
   │                           │ (updated_at newer)        │
   │                           │                           │
   │                           ├──────────────────────────►│
   │                           │ return {title:"Math",      │
   │                           │         sync_version: 4}   │
   │                           │                           │
   │                           │                           │ update local Hive
```

---

## 10. Client Implementation Reference

| Component | File | Responsibility |
|---|---|---|
| Config | `lib/core/supabase_config.dart` | `--dart-define` key loading |
| Auth | `lib/services/adapters/supabase_auth_adapter.dart` | Anonymous/email/OAuth |
| Raw sync | `lib/services/adapters/supabase_sync_adapter.dart` | PostgREST push/pull |
| Orchestration | `lib/services/supabase_sync_service.dart` | Queue, flush, status |
| UI indicator | `lib/widgets/sync_status_badge.dart` | SyncStatus badge |
| Diagnostics | `lib/screens/database_preview_screen.dart` | Schema preview, health |
