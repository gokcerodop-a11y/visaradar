# OmniCore Phase 4 — Memory + Session Extraction Plan

**Version**: 1.0.0
**Date**: 2026-05-25
**Status**: planning only — no code changes
**Prerequisite**: Phase 3 completed (foundation package live, 8 utilities extracted)
**Target packages**: `omnicore_memory`, `omnicore_session`, with extensions to `omnicore_foundation`

This document supplements `omnicore_migration_plan.md` §5 Phase 4 with the
granular sub-phase plan, decoupling strategy per file, and per-step
verification checklist.

---

## 0. TL;DR

| | |
|---|---|
| **Files in scope** | 9 (5 memory layers + 3 memory orchestrators + 2 session services), one already extracted (`working_memory` in Phase 3B) |
| **True coupling points** | 4 LiseAI-domain types leak into the API surface: `TeacherEmotionalState`, `PacingAdjustment`, `HomeworkItem`, `TeacherIdentity` |
| **Hidden prerequisite** | All 5 of the remaining memory + session services need `StorageService`. Phase 3 deferred extracting it. Phase 4 must split it into a generic `KeyValueStorage` interface (Foundation) plus the LiseAI-specific `ConversationStorage` (stays in app) |
| **Call-site blast radius** | Tiny — only 2 assignment sites touch the LiseAI-coupled fields (`ai_os_screen.dart:973-974`). Storage usage is internal to each memory class. |
| **Sub-phases** | 6 (4A–4F), each shippable independently with a green build |
| **Risk profile** | 4A very low → 4B medium → 4C low → 4D low → 4E medium → 4F low |

---

## 1. Inventory and dependency map

### 1.1 Files in scope

| File | LOC | Storage? | LiseAI-domain coupling in API surface |
|---|---:|---|---|
| `working_memory.dart` | 129 | no | none — **already extracted in Phase 3B** |
| `short_term_memory.dart` | 112 | no | `TeacherEmotionalState`, `PacingAdjustment` (both as field types) |
| `long_term_memory.dart` | 301 | yes | none (own data classes `SubjectMastery` + `MistakePattern`) |
| `episodic_memory.dart` | 192 | yes | none (own `EpisodeType` enum, all data is opaque strings) |
| `semantic_memory.dart` | 319 | yes | none (own data classes) |
| `memory_summarizer.dart` | 235 | no | already on `AIProvider` (Phase 2B). Depends on episodic + long_term + short_term |
| `memory_retrieval_engine.dart` | 173 | no | depends on all 5 memory classes |
| `memory_prompt_layer.dart` | 95 | no | depends on all 5 + retrieval |
| `session_continuity_service.dart` | 297 | yes | `HomeworkItem` (extractHomework method), `TeacherIdentity` (getReturnGreeting method) |
| `session_recovery_service.dart` | 102 | yes | none — `LessonMode.name` only stored as opaque `String?` |

### 1.2 What "Storage?" means

The 5 storage-using services all call the same minimal subset of `StorageService`:

```dart
await storage.init();
storage.loadSetting(String key) → String?
await storage.saveSetting(String key, String value)
```

None of them touch `saveConversation` / `loadConversation` / `listConversations` (those are the LiseAI-specific bits). That makes the **storage split** straightforward: define `KeyValueStorage` interface with three methods; let `StorageService` implement it.

### 1.3 Caller blast radius

Outside the cluster, where memory + session services are referenced:

| File | What it touches |
|---|---|
| `lib/screens/ai_os_screen.dart` | Constructs all memory + session services; writes `recentEmotionalState` (line 973), `currentPacing` (line 974), `addTurn(ShortTermTurn(...))` (lines 647, 967); reads `MemoryPromptLayer.build(...)` |
| `lib/screens/progress_dashboard_screen.dart` | Reads from long-term + semantic for dashboard widgets |
| `lib/screens/settings_screen.dart` | Reads from long-term + episodic for export/clear actions |
| `lib/services/sync_repository.dart` | Mirrors memory state into Supabase sync; reads accessors |

Only `ai_os_screen.dart` writes to the **decoupled** field types. That's the only place Phase 4B has to update its assignment site.

---

## 2. Decoupling strategy per coupled type

### 2.1 `TeacherEmotionalState` in `short_term_memory.dart`

**Current** (line 34):
```dart
TeacherEmotionalState? recentEmotionalState;
```

Used in `buildContextBlock()` (line 79):
```dart
sb.writeln('- Son öğretmen tonu: ${recentEmotionalState!.label}');
```

**Decoupling approach**: introduce an `AssistantTone` interface in
`omnicore_foundation` (per §8.1). Two-axis design — label for humans,
kind for machines — so agentic / automation layers can branch on a
stable identifier across locales:

```dart
// in OmniCore
abstract class AssistantTone {
  String get label;   // human-readable, may be localized
  String get kind;    // stable machine identifier (locale-independent)
}
```

LiseAI maps its existing enum to this interface via an extension method:

```dart
// in lib/models/teacher_identity.dart (added, not breaking)
extension TeacherEmotionalStateTone on TeacherEmotionalState {
  AssistantTone get tone => _TeacherEmotionalAssistantTone(this);
}
class _TeacherEmotionalAssistantTone implements AssistantTone {
  final TeacherEmotionalState _e;
  const _TeacherEmotionalAssistantTone(this._e);
  @override String get label => _e.label;
  @override String get kind => _e.name;
}
```

`ShortTermMemory.recentEmotionalState` becomes `AssistantTone?`.
`ai_os_screen.dart:973` becomes:
```dart
_shortTermMem.recentEmotionalState = _identitySvc.emotionalState.tone;
```

The LiseAI-specific enum survives unchanged. Only one assignment site is touched.

### 2.2 `PacingAdjustment` in `short_term_memory.dart`

**Current** (line 35 + line 82):
```dart
PacingAdjustment? currentPacing;
// …
if (currentPacing != null && currentPacing != PacingAdjustment.none) {
  sb.writeln('- Tempo ayarı: ${currentPacing!.name}');
}
```

The memory layer reads only:
- `.name` (the enum value's symbolic name)
- equality check against `PacingAdjustment.none`

**Decoupling approach**: same shape as 2.1. Introduce `AssistantPacingHint`:

```dart
// in OmniCore
abstract class AssistantPacingHint {
  String get kind;      // stable machine identifier
  bool get isNoOp;
}
```

LiseAI's `PacingAdjustment` gets an extension:
```dart
extension PacingHintAdapter on PacingAdjustment {
  AssistantPacingHint get hint => _PacingHintAdapter(this);
}
class _PacingHintAdapter implements AssistantPacingHint {
  final PacingAdjustment _p;
  const _PacingHintAdapter(this._p);
  @override String get kind => _p.name;          // enum.name → stable id
  @override bool get isNoOp => _p == PacingAdjustment.none;
}
```

`ai_os_screen.dart:974` becomes:
```dart
_shortTermMem.currentPacing = _attentionEngine.currentSignal.adjustment.hint;
```

### 2.3 `HomeworkItem` + `TeacherIdentity` in `session_continuity_service.dart`

The current file has two domain-leaking helpers:

- `extractHomework(String aiReply, String currentTopic) → HomeworkItem?` (lines 202-216)
  Regex-matches `[ÖDEV: ...]` markers and constructs a `HomeworkItem`.
  This is **LiseAI homework-tracking logic** — not session-continuity logic.
- `getReturnGreeting(TeacherIdentity teacher) → String?` (lines 221-244)
  Composes "${teacher.teacherName}: …" strings. The string template is LiseAI-flavoured ("dersi", "konusunda kalmıştık").

**Decoupling approach**: move both helpers OUT of `SessionContinuityService` into LiseAI-side files.

- `extractHomework` → goes to `lib/services/learning_journal_service.dart` (which already owns `HomeworkItem` semantics).
- `getReturnGreeting` → new file `lib/services/return_greeting_builder.dart` or absorbed into `teacher_identity_service.dart`.

After the move, `SessionContinuityService` only persists `SessionContinuityData`
and exposes accessors. Its `buildContinuityPrompt()` block stays — that's
generic context text the agent system prompt uses, no domain-specific
references. (The string content mentions "ders" but the method itself only
emits strings; the prompt content is rebuildable by the consumer if needed.)

**Open question**: `buildContinuityPrompt()` writes Turkish lesson-context strings. Two views:

- **Keep in OmniCore Session as-is** — Turkish lesson framing is just *text*; verticals can override or ignore.
- **Move out** — same logic but framing-agnostic, with verticals providing the wording template.

For Phase 4 we **keep in OmniCore Session as-is** to minimize churn. Refactoring the prompt builder into a vertical-agnostic template is a future cleanup (Phase 5 or 7), not blocking.

### 2.4 `StorageService` — the storage split

The 5 storage-using services in Phase 4 all use the same minimal contract.
The other consumers of `StorageService` use additional methods
(`saveConversation`, `loadConversation`, `listConversations`,
`deleteConversation`, `generateId`).

**Approach**: introduce a tiny `KeyValueStorage` interface in
`omnicore_foundation`. Have LiseAI's `StorageService` `implement` it.

```dart
// packages/omnicore_foundation/lib/src/key_value_storage.dart
abstract class KeyValueStorage {
  Future<void> init();
  String? loadSetting(String key);
  Future<void> saveSetting(String key, String value);
}
```

```dart
// lib/services/storage_service.dart — add `implements KeyValueStorage`
class StorageService implements KeyValueStorage { … }
```

After 4A, every memory + session class can declare its dependency as
`KeyValueStorage` instead of `StorageService`. The concrete LiseAI
`StorageService` continues to provide everything else (conversations).
Other verticals (VisaRadar, future apps) will provide their own
`KeyValueStorage` implementation.

This is the smallest possible refactor that unblocks Phase 4D–F.

### 2.5 `LessonMode.name` in `session_recovery_service.dart`

`SessionSnapshot.lessonMode` is `String?` already. The value is `LessonMode.name`
written by the caller and re-parsed by the caller. **No coupling, no work.**

### 2.6 `learning_journal.dart` import in `session_continuity_service.dart`

After 4C removes `extractHomework`, the import drops naturally.

### 2.7 `teacher_identity.dart` import in `session_continuity_service.dart`

After 4C removes `getReturnGreeting`, the import drops naturally.

---

## 3. Sub-phase plan

Six sub-phases, each shippable on its own.

### 3.1 Phase 4A — `KeyValueStorage` + `AssistantTone` + `AssistantPacingHint` in Foundation

**Goal**: introduce the three new interfaces in `omnicore_foundation` without
changing any existing behavior.

**Changes**:

1. Add new files in the package:
   - `packages/omnicore_foundation/lib/src/key_value_storage.dart`
   - `packages/omnicore_foundation/lib/src/assistant_tone.dart`
   - `packages/omnicore_foundation/lib/src/assistant_pacing_hint.dart`
2. Add exports to `packages/omnicore_foundation/lib/omnicore_foundation.dart`.
3. Bump package identity to `0.4.0`.

**Risk**: very low. Pure additive interfaces, no implementations bound.

**Verification**:
- `flutter analyze` → 93 (baseline preserved).
- `flutter build ios --release --no-codesign` → green.
- `flutter build macos --release` → green.

**Commit message draft**:
```
omnicore: add KeyValueStorage + AssistantTone interfaces (Phase 4A)
```

---

### 3.2 Phase 4B — Adapt LiseAI types to the new interfaces

**Goal**: make LiseAI's `StorageService`, `TeacherEmotionalState`, and
`PacingAdjustment` compatible with the new OmniCore interfaces. Update
`ShortTermMemory` field types and the two `ai_os_screen.dart` assignment
sites.

**Changes**:

1. `lib/services/storage_service.dart` — add `implements KeyValueStorage`.
   Class body unchanged. (The shim file currently lives here too — verify
   this still works after the change.)
2. `lib/models/teacher_identity.dart` — append extension `TeacherEmotionalStateTone` + private adapter class. No edits to existing code.
3. `lib/services/attention_engine.dart` — append extension `PacingHintAdapter` + private adapter class. No edits to existing code.
4. `lib/services/short_term_memory.dart`:
   - Replace `TeacherEmotionalState? recentEmotionalState;` with `AssistantTone? recentEmotionalState;`.
   - Replace `PacingAdjustment? currentPacing;` with `AssistantPacingHint? currentPacing;`.
   - Update the `buildContextBlock()` reads:
     - `recentEmotionalState!.label` stays as `recentEmotionalState!.label` (interface has same method).
     - `currentPacing != PacingAdjustment.none` becomes `!currentPacing!.isNoOp`.
     - `currentPacing!.name` becomes `currentPacing!.kind`.
   - Drop the now-unused imports of `teacher_identity.dart` and `attention_engine.dart`.
   - Import the new interfaces from `omnicore_foundation`.
5. `lib/screens/ai_os_screen.dart`:
   - Line 973: `… = _identitySvc.emotionalState;` becomes `… = _identitySvc.emotionalState.tone;`
   - Line 974: `… = _attentionEngine.currentSignal.adjustment;` becomes `… = _attentionEngine.currentSignal.adjustment.hint;`

**Risk**: medium. Touches two production assignment sites. The new interface
methods have identical names/return types where possible to minimize
mechanical churn.

**Verification**:
- Manual test plan §4 (memory restore after restart) becomes the key
  validation. The `_shortTermMem.buildContextBlock()` output should be
  byte-identical for any given (emotional state, pacing) input.
- `flutter analyze` → 93.
- Builds green.

**Rollback**: revert two files (`short_term_memory.dart`, `ai_os_screen.dart`).
Extensions in `teacher_identity.dart` and `attention_engine.dart` can stay
(no harm).

---

### 3.3 Phase 4C — Move LiseAI helpers out of `session_continuity_service.dart`

**Goal**: strip the `extractHomework` and `getReturnGreeting` methods so
`SessionContinuityService` becomes truly domain-agnostic.

**Changes**:

1. `lib/services/learning_journal_service.dart` (existing file) — add a new
   public function/method `extractHomeworkFromReply(aiReply, currentTopic)`
   with identical logic to the current `SessionContinuityService.extractHomework`.
2. New file `lib/services/return_greeting_builder.dart` (or absorbed into
   `teacher_identity_service.dart`) — defines `buildReturnGreeting(SessionContinuityData data, TeacherIdentity teacher)` with logic identical to the current `getReturnGreeting`.
3. `lib/services/session_continuity_service.dart`:
   - Remove `import '../models/learning_journal.dart';`
   - Remove `import '../models/teacher_identity.dart';`
   - Delete the `extractHomework(...)` method (lines 202-216).
   - Delete the `getReturnGreeting(TeacherIdentity teacher)` method (lines 221-244).
4. Update any caller of `SessionContinuityService.extractHomework` / `.getReturnGreeting` to use the new locations.

**Caller audit** (must be done before applying):
- Grep for `.extractHomework(`, `.getReturnGreeting(` in lib/.

**Risk**: low. Pure internal rearrangement within LiseAI.

**Verification**:
- Manual QA §1.7 (reopen confirms no replay) — return-greeting behavior preserved.
- Manual QA §3.4 (history persistence) — homework extraction preserved.
- Builds green.

---

### 3.4 Phase 4D — Create `omnicore_memory` package + extract pure-storage memories

**Goal**: ship the memory package with the 3 cleanest extractions:
`long_term_memory`, `semantic_memory`, `episodic_memory`. After 4A's
storage split, these need only `KeyValueStorage`.

**Changes**:

1. Create `packages/omnicore_memory/` skeleton:
   - `pubspec.yaml` declaring `omnicore_foundation: { path: ../omnicore_foundation }` as a dep
   - `lib/omnicore_memory.dart` barrel
   - `lib/src/` directory
   - `analysis_options.yaml`
   - `README.md`
2. `melos.yaml` — no change (already manages `packages/*`).
3. Run `melos bootstrap`.
4. Copy three files to `packages/omnicore_memory/lib/src/`:
   - `long_term_memory.dart`
   - `semantic_memory.dart`
   - `episodic_memory.dart`
5. In each copied file, change `import 'storage_service.dart';` to `import 'package:omnicore_foundation/omnicore_foundation.dart' show KeyValueStorage;` and change the `init(StorageService …)` signature to `init(KeyValueStorage …)`.
6. Update `packages/omnicore_memory/lib/omnicore_memory.dart` to export all three.
7. Replace each LiseAI-side `lib/services/<file>.dart` with a re-export shim:
   ```dart
   export 'package:omnicore_memory/omnicore_memory.dart' show LongTermMemory, SubjectMastery, MistakePattern;
   ```
8. Update `lise_ai/pubspec.yaml` to add `omnicore_memory: { path: ../packages/omnicore_memory }`.
9. Update `lib/omnicore/memory.dart` barrel to keep pointing at `../services/...` (the shim does the right thing).
10. Bump versions: `omnicore_foundation` stays at `0.4.x`; `omnicore_memory` starts at `0.1.0`.

**Risk**: low. Same pattern as Phase 3, three files, no orchestrator logic.

**Verification**:
- Manual QA §5 (image upload — irrelevant), §8 (memory restore — critical).
- `flutter build` green.

**Critical check**: each memory loads its existing `_key` from the same Hive
box. After extraction the box is opened by LiseAI's `StorageService` (in
lise_ai) and passed via `KeyValueStorage` interface — should round-trip
existing data unchanged.

---

### 3.5 Phase 4E — Extract `short_term_memory` + 3 orchestrators

**Goal**: lift the four remaining files into `omnicore_memory`.

**Changes**:

1. Copy four files to `packages/omnicore_memory/lib/src/`:
   - `short_term_memory.dart` (uses `AssistantTone` + `AssistantPacingHint`, no other domain deps after 4B)
   - `memory_retrieval_engine.dart` (orchestrator)
   - `memory_summarizer.dart` (uses `AIProvider`; currently imports from `../omnicore/provider.dart` in the LiseAI tree — this import path must be updated to `package:lise_ai/...` OR we move `omnicore/provider` to a real package in a tag-along PR — see §5)
   - `memory_prompt_layer.dart` (orchestrator)
2. Update `omnicore_memory.dart` barrel.
3. Replace LiseAI-side files with shims.
4. `lib/omnicore/memory.dart` barrel unchanged (still points at `../services/...`).

**Risk**: medium. `memory_summarizer.dart` imports `AIProvider` from
`lise_ai/lib/omnicore/provider.dart`. We have two clean options:

- **Option A** (safer for Phase 4): keep `memory_summarizer.dart` in lise_ai
  for this phase. Extract only the other 3 files (short_term + retrieval +
  prompt_layer). Move memory_summarizer in Phase 5 when AIProvider has its
  own package.
- **Option B**: also create `packages/omnicore_provider/` in Phase 4 (out
  of scope, but unavoidable). Move AIProvider + ClaudeProvider + stubs to
  the package, then memory_summarizer can use the package import path.

**Decision**: go with **Option A**. Keep `memory_summarizer.dart` in
lise_ai for Phase 4. Extract it in Phase 5 alongside the provider package.

**Verification**:
- Manual QA §3 (basic AI chat with history), §5 (memory restore), §8 (long
  session) — all rely on the orchestrator chain.
- Builds green.

---

### 3.6 Phase 4F — Create `omnicore_session` package + extract session services

**Goal**: ship the session package with both services (now stripped of
LiseAI helpers thanks to 4C).

**Changes**:

1. Create `packages/omnicore_session/` skeleton (same pattern as 4D).
2. Add `omnicore_foundation` path dep in its pubspec.
3. Copy two files:
   - `session_continuity_service.dart`
   - `session_recovery_service.dart`
4. In each, replace `import 'storage_service.dart';` with `import 'package:omnicore_foundation/omnicore_foundation.dart' show KeyValueStorage;` and change init signatures.
5. Update barrel + LiseAI shims.
6. Update `lise_ai/pubspec.yaml` to add the path dep.

**Risk**: low. Two files, clean after 4C.

**Verification**:
- Manual QA §1 (first launch + onboarding), §1.7 (reopen no replay).
- Manual QA §8 (memory + session continuity).
- Builds green.

---

## 4. Cumulative risk map

| Phase | Failure mode | Detection signal | Rollback |
|---|---|---|---|
| 4A | Foundation analyze fails | `melos run analyze` | revert single commit |
| 4B | `_shortTermMem.recentEmotionalState` reads wrong label | Manual QA §8 (greeting tone mismatch) | revert short_term_memory + ai_os_screen |
| 4C | Return greeting missing or homework not extracted | Manual QA §1.7 + §3.4 | restore deleted methods from git history |
| 4D | Hive box opens but memory data is empty after relaunch | Diagnostics screen → memory section shows empty | check `_key` constants are unchanged; storage interface must round-trip strings byte-for-byte |
| 4E | System prompt missing context | AI replies feel disconnected from prior session | revert orchestrator extractions; check `MemoryPromptLayer.build()` returns same string for same inputs |
| 4F | Reopen prompts onboarding (session lost) | Manual QA §1.7 fails | revert session extractions; check `_key` is unchanged |

---

## 5. Out-of-scope for Phase 4 (deferred to Phase 5)

- **`omnicore_provider` package**: AIProvider + ClaudeProvider + OpenAI/Gemini stubs currently live in `lise_ai/lib/omnicore/provider/`. Move to a real package in Phase 5.
- **`omnicore_streaming` package**: `streaming_teacher_session.dart` extraction. Depends on `PacingProfile` (similar pattern to 4B's pacing decoupling).
- **Conversation storage split**: the LiseAI-specific bits of `StorageService` (StoredConversation, ConversationMeta, conversation CRUD) stay in lise_ai. A future cleanup might extract these into a `ConversationStore` interface, but they're not needed by any other vertical yet.
- **Vector / embedding memory**: noted in `memory_retrieval_engine.dart` as a "future hook". Not part of OmniCore v1.

---

## 6. Per-phase build verification checklist

Apply after EVERY sub-phase 4A→4F before committing:

- [ ] `cd lise_ai && flutter analyze` → ≤ baseline issues (currently 93), no new errors/warnings
- [ ] `flutter build ios --release --no-codesign` → green
- [ ] `flutter build macos --release` → green
- [ ] `melos bootstrap` (when a new package lands in 4D or 4F) → all packages resolve
- [ ] Manual QA `docs/qa/manual_test_execution.md` § relevant section to the phase's risk surface

Manual QA per phase:

| Phase | Relevant manual QA section |
|---|---|
| 4A | none (no behavior change) |
| 4B | §8 (memory restore — short-term tone preserved) |
| 4C | §1.7 (reopen no replay — return greeting), §3.4 (homework extraction during chat) |
| 4D | §5 (memory across restart), §8 (long-term mastery preserved) |
| 4E | §3 (basic AI chat), §8 (multi-session continuity) |
| 4F | §1 (first launch), §1.7 (reopen no replay), §8 (session continuity prompt block) |

---

## 7. Acceptance criteria for "Phase 4 done"

- [ ] `packages/omnicore_memory/` ships with 8 files (5 memory layers — `working_memory` re-exported from foundation — + 3 orchestrators — `memory_summarizer` may stay in lise_ai per §3.5 Option A)
- [ ] `packages/omnicore_session/` ships with 2 files
- [ ] `packages/omnicore_foundation/` adds 3 new interfaces (`KeyValueStorage`, `AssistantTone`, `AssistantPacingHint`)
- [ ] LiseAI's `lib/services/` retains re-export shims for all extracted files; every old import path still works
- [ ] `melos bootstrap` resolves all three packages cleanly
- [ ] All builds (analyze + iOS release + macOS release) green at every sub-phase
- [ ] Manual QA execution checklist § 5 + § 8 sign-off
- [ ] Single git tag `omnicore-phase-4-shipped` at the end

---

## 8. Open decisions before kicking off 4A

1. **Where do `AssistantTone` / `AssistantPacingHint` live?**
   - In `omnicore_foundation` (proposal — see §3.1)
   - In `omnicore_memory` (only used by memory cluster, so could live there)
   Recommendation: **foundation**. Other future modules (voice, session) may want assistant-tone too.

2. **Should `memory_summarizer` extract in Phase 4E or wait for Phase 5?**
   - 4E: simpler ordering, but requires `omnicore_provider` to also extract now.
   - Phase 5: cleaner separation, but `omnicore_memory` ships without its full orchestrator set.
   Recommendation: **wait for Phase 5** (Option A in §3.5).

3. **Should `extractHomework` go to `learning_journal_service.dart` or a new `homework_extractor.dart` helper?**
   - Inside learning_journal_service: convenient, single home for homework concerns.
   - Standalone helper: cleaner SRP, easier to test in isolation.
   Recommendation: **inside `learning_journal_service.dart`** (existing home).

4. **Should `getReturnGreeting` go to `teacher_identity_service.dart` or a new file?**
   - Inside teacher_identity_service: it composes "${teacher.teacherName}: …" strings, fits the teacher identity surface.
   - Standalone helper file: avoids growing teacher_identity_service.
   Recommendation: **new file `lib/services/return_greeting_builder.dart`** — single function, clean home.

---

**End of Phase 4 plan.** No code was changed by writing this document. Awaiting decisions on §8 before kicking off Phase 4A.
