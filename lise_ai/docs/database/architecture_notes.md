# LiseAI — Production Database Architecture Notes

> Version 1.0.0 · 2026-05-24
> Platform: Supabase (PostgreSQL 15) · Client: Flutter / Dart

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Table Inventory](#2-table-inventory)
3. [Primary Key Strategy](#3-primary-key-strategy)
4. [Nullable Rules](#4-nullable-rules)
5. [Foreign Keys & Cascade Rules](#5-foreign-keys--cascade-rules)
6. [Optimistic Sync Fields](#6-optimistic-sync-fields)
7. [Conflict Resolution](#7-conflict-resolution)
8. [Index Strategy](#8-index-strategy)
9. [Row Level Security Strategy](#9-row-level-security-strategy)
10. [Retention Strategy](#10-retention-strategy)
11. [Estimated Storage](#11-estimated-storage)
12. [Future Extensions](#12-future-extensions)

---

## 1. Design Philosophy

LiseAI is **offline-first**. The canonical source of truth is the **client device** for the active session; Supabase is the durable cloud backup and cross-device sync layer. This shapes every decision:

| Principle | Implementation |
|---|---|
| Offline-first | All writes succeed locally; cloud push is async |
| Minimal latency | Single-table reads; denormalised hot-path fields |
| No PII in telemetry | `analytics_events.payload` must contain only behavioural data |
| Soft-delete everywhere | `deleted_at` column; hard-delete only via retention jobs |
| Predictable cost | TTL on analytics (90d) and short-term memory (24h) |
| Anonymous first | `users.is_anonymous = true` by default; upgrade path to email |

---

## 2. Table Inventory

| # | Table | Purpose | Rows/User (est.) | Write Freq |
|---|---|---|---|---|
| 1 | `users` | Public profile, auth mirror | 1 | Rare |
| 2 | `student_profiles` | Full learner model | 1 | Every session |
| 3 | `conversations` | Chat thread metadata | 5–200 | Daily |
| 4 | `conversation_messages` | Individual turns | 50–10 000 | Every message |
| 5 | `lesson_sessions` | Structured lesson outcomes | 20–500 | Per lesson |
| 6 | `memory_items` | Five-layer cognitive memory | 10–1 000 | Per session |
| 7 | `achievements` | Gamification badges | 10–50 | Rare |
| 8 | `streaks` | Daily streak counter | 1 | Daily |
| 9 | `analytics_events` | Telemetry (90d TTL) | 100–5 000 | Constant |
| 10 | `sync_queue` | Offline op audit log | 0–200 | On conflict |
| 11 | `subscriptions` | Billing state | 1 | On purchase |
| 12 | `feature_flags` | Flag overrides | 0–20 | Rare |

---

## 3. Primary Key Strategy

All tables use `uuid` PKs generated **client-side** with Dart's `Uuid` package.
This is critical for offline-first: the client can create a row locally and push to the server later without needing a server-assigned ID.

```
gen_random_uuid()   -- PostgreSQL default (server fallback)
Uuid().v4()         -- Dart client (preferred path)
```

The `users` table is the sole exception: its PK is `auth.users.id` (UUID assigned by Supabase Auth on sign-in).

---

## 4. Nullable Rules

### Always NOT NULL
- `id`, `user_id`, `created_at`, `updated_at`
- `sync_version`, `is_anonymous`
- Any enum column with a DEFAULT value

### Intentionally NULL
| Column | Table | Meaning when NULL |
|---|---|---|
| `email` | `users` | Anonymous user |
| `display_name` | `users` | Not yet set |
| `deleted_at` | everywhere | Row is live |
| `archived_at` | `conversations` | Not yet archived |
| `expires_at` | `memory_items` | Permanent memory |
| `expires_at` | `analytics_events` | Should never be NULL — has DEFAULT |
| `user_id` | `feature_flags` | Global flag (all users) |
| `family_owner_id` | `users` | Not a family member |
| `embedding` | `memory_items` | pgvector not yet enabled |
| `platform_receipt` | `subscriptions` | Free plan |
| `processed_at` | `sync_queue` | Not yet processed |
| `lesson_question` | `conversation_messages` | Not a board-trigger message |

### UNIQUE constraints
| Table | Columns | Reason |
|---|---|---|
| `users` | `email` | One account per email |
| `student_profiles` | `user_id` | 1:1 with users |
| `achievements` | `(user_id, achievement_key)` | One badge per type per user |
| `streaks` | `user_id` | One streak state per user |
| `subscriptions` | `user_id` | One active plan per user |
| `feature_flags` | `(user_id, flag_key)` | One value per flag per user |

---

## 5. Foreign Keys & Cascade Rules

```
auth.users
    └── users (ON DELETE CASCADE)
            ├── student_profiles     CASCADE  — profile dies with account
            ├── conversations        CASCADE  — history dies with account
            │       └── conversation_messages  CASCADE
            ├── lesson_sessions      CASCADE
            │       ╰── conversation_id → conversations  SET NULL
            ├── memory_items         CASCADE
            ├── achievements         CASCADE
            ├── streaks              CASCADE
            ├── analytics_events     CASCADE
            ├── sync_queue           CASCADE
            ├── subscriptions        CASCADE
            │       ╰── family_owner_id → users  SET NULL
            └── feature_flags        CASCADE
```

### Why SET NULL instead of CASCADE?
- `lesson_sessions.conversation_id`: a lesson session has independent analytical value even if the conversation is deleted. Stats must survive.
- `subscriptions.family_owner_id`: if the family owner account is removed, the family plan reference is NULLed; members keep their individual records.

---

## 6. Optimistic Sync Fields

Every table carries three columns for offline-first sync:

| Column | Type | Purpose |
|---|---|---|
| `sync_version` | `bigint NOT NULL DEFAULT 0` | Monotonic counter; bumped by server trigger on every UPDATE |
| `client_id` | `text` | Opaque device/client identifier written by the last client to push |
| `last_sync_at` | `timestamptz` | Timestamp of the last successful cloud sync for this row |

The client stores its own `sync_version` snapshot locally (Hive). On push:

1. Client sends `{payload, client_sync_version: N}`.
2. Server checks `current sync_version == N` (compare-and-swap).
3. If equal → apply write, bump `sync_version` to N+1.
4. If differs → conflict detected → log to `sync_queue` with `conflict_detected = true`.

---

## 7. Conflict Resolution

### Default: Last-Write-Wins (LWW)
Most tables use `conflict_strategy = 'last_write_wins'` stored on the `users` row.
The server uses Supabase `.upsert({ onConflict: 'id' })` which resolves by writing the incoming row if `updated_at` is newer.

```sql
-- Server-side LWW upsert (via PostgREST)
INSERT INTO conversations (id, user_id, title, ...)
VALUES (...)
ON CONFLICT (id) DO UPDATE
  SET title = EXCLUDED.title, ...
  WHERE EXCLUDED.updated_at > conversations.updated_at;
```

### Merge Strategy (future)
For `student_profiles` and `memory_items` where LWW could cause data loss (e.g. two devices both update `weak_topics`), the merge strategy applies array unions:

```
merged_weak_topics = local_weak_topics ∪ remote_weak_topics
merged_mastery_map = max(local[topic], remote[topic]) for each topic
```
This is implemented in `SupabaseSyncService.flush()` and logged to `sync_queue`.

### Server-Wins
Reserved for `subscriptions` and `feature_flags`: the server (or webhook) is always authoritative. Clients cache these locally but never push writes directly.

---

## 8. Index Strategy

### Guiding rules
1. **Covered queries first**: every `WHERE user_id = ? ORDER BY created_at DESC` pattern has a composite index.
2. **Partial indexes on soft-deleted tables**: `WHERE deleted_at IS NULL` keeps index small.
3. **Partial index on hot enums**: `WHERE status IN ('pending','failed')` on `sync_queue`.
4. **No index on high-churn booleans** (`has_board_lesson`): cardinality too low.
5. **TTL columns always indexed**: `expires_at` on `analytics_events` and `memory_items` for fast batch deletes.

### Hot-path query patterns

```sql
-- Load user's recent conversations (sidebar)
SELECT * FROM conversations
WHERE  user_id = $1 AND deleted_at IS NULL AND archived_at IS NULL
ORDER  BY created_at DESC LIMIT 50;
-- → uses idx_conversations_live

-- Load messages for a conversation (chat restore)
SELECT * FROM conversation_messages
WHERE  conversation_id = $1 AND deleted_at IS NULL
ORDER  BY created_at ASC;
-- → uses idx_messages_live

-- Retrieve active memory items by importance (context injection)
SELECT * FROM memory_items
WHERE  user_id = $1 AND memory_type = 'long_term' AND deleted_at IS NULL
ORDER  BY importance DESC LIMIT 20;
-- → uses idx_memory_user_type
```

---

## 9. Row Level Security Strategy

### Three-tier access model

```
Tier 1 — Own data:
  Every table: auth.uid() = user_id
  → Users see and write only their own rows.

Tier 2 — Family read-only:
  users, subscriptions:
  → Family members can read the owner's profile/subscription.
  → Write still requires auth.uid() = user_id (owner only).

Tier 3 — Global reads (no auth required for feature_flags):
  feature_flags WHERE user_id IS NULL:
  → All authenticated users can read global flags.
  → Only service_role can write flags.
```

### Anonymous guest isolation
Supabase anonymous sign-in generates a real `auth.users` row with a UUID. RLS uses `auth.uid()` which is always the anonymous UUID. This means:

- Anonymous users are **fully isolated**: no data leakage between sessions.
- Upgrading to email account (link anonymous → email) migrates the same UUID: all data is preserved automatically.
- Anonymous rows with `is_anonymous = true` older than 6 months are candidates for soft-deletion if never upgraded (scheduled via pg_cron).

### Service role
All pg_cron jobs, Edge Functions, and webhook handlers run under `service_role` which bypasses RLS. These must never be exposed client-side.

---

## 10. Retention Strategy

### Analytics events (TTL: 90 days)
```
analytics_events.expires_at = now() + interval '90 days'
pg_cron: DELETE WHERE expires_at < now()  [daily 03:00 UTC]
```
No PII stored in payload. After 90 days, only aggregated stats matter.

### Short-term memory (TTL: 24 hours)
```
memory_items WHERE memory_type = 'short_term'
  expires_at = now() + interval '24 hours'
pg_cron: DELETE WHERE expires_at < now()  [daily 03:05 UTC]
```

### Memory compression candidates
Working and episodic memory rows are flagged `compressed = false` while they accumulate. A background job (Edge Function or client-side MemorySummarizer) groups rows by `compression_group`, generates an LLM summary, stores it as a single `long_term` row, and deletes the source rows.

```
idx_memory_compress: WHERE NOT compressed AND memory_type IN ('short_term','episodic')
```

### Conversation archival (3-tier)
| Age | Action | Tier |
|---|---|---|
| < 90 days | No action | `hot` |
| 90–180 days | `archived_at = now()`, `archive_tier = 'warm'` | `warm` |
| > 180 days | Messages soft-deleted; summary stored in `conversations.summary` | `cold` |

The summary is generated by the client's `MemorySummarizer` before the conversation moves to warm tier, or by an Edge Function for server-side archival.

### Sync queue cleanup (TTL: 7 days post-processing)
```
pg_cron: DELETE WHERE status IN ('done','failed') AND processed_at < now() - interval '7 days'
```

---

## 11. Estimated Storage

Based on 10 000 active users, 6-month horizon:

| Table | Rows | Est. Size |
|---|---|---|
| `users` | 10 000 | ~2 MB |
| `student_profiles` | 10 000 | ~5 MB |
| `conversations` | 200 000 | ~40 MB |
| `conversation_messages` | 5 000 000 | ~3 GB |
| `lesson_sessions` | 500 000 | ~80 MB |
| `memory_items` | 2 000 000 | ~400 MB |
| `achievements` | 100 000 | ~15 MB |
| `streaks` | 10 000 | ~2 MB |
| `analytics_events` | 3 000 000 | ~600 MB (rolling 90d) |
| `sync_queue` | 50 000 | ~10 MB |
| `subscriptions` | 10 000 | ~3 MB |
| `feature_flags` | 500 | ~0.1 MB |
| **Total** | | **~4.2 GB** |

Supabase Pro plan includes 8 GB storage. Expected budget: comfortable for 12+ months.

---

## 12. Future Extensions

| Feature | Schema Impact |
|---|---|
| AI embeddings | Enable pgvector; uncomment `memory_items.embedding vector(1536)` |
| Family accounts | `users.family_owner_id`, `subscriptions.family_seat_limit` already present |
| Teacher mode | Add `teacher_profiles` table; add `is_teacher` to `users` |
| School accounts | Add `organizations` table; add `org_id` FK to `users` |
| Realtime collab | Add `shared_conversations` join table |
| Server-side AI | Add `ai_requests` table for cost tracking per model call |
| Analytics dashboard | Aggregate views / materialized views on `analytics_events` |
