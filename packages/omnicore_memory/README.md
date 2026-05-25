# omnicore_memory

Five-layer cognitive memory subsystem for the OmniCore AI Engine.

## Status — Phase 4D (active)

Three pure-storage memory layers live here today:

| Layer | Purpose |
|---|---|
| `LongTermMemory` | Persisted cross-session profile — subject mastery, mistake patterns, learning styles, motivation trend, strategies, exam readiness, favorite analogy domain |
| `EpisodicMemory` | Teacher's memory of meaningful moments — breakthroughs, struggles, milestones |
| `SemanticMemory` | Topic knowledge graph + misconceptions + analogy success tracking |

All three depend only on:
- `package:omnicore_foundation/omnicore_foundation.dart` (for `KeyValueStorage`)
- `dart:convert` (JSON serialization)
- `package:flutter/foundation.dart` (for `debugPrint`)

No LiseAI domain types reach the public API.

## Pending (Phase 4E)

Four more files land here:

- `ShortTermMemory` — sliding-window session state (Phase 4B made it type-clean)
- `MemoryRetrievalEngine` — context-aware retrieval over all 5 layers
- `MemoryPromptLayer` — assembles all layers into a system-prompt block
- `MemorySummarizer` — *deferred to Phase 5* (depends on AIProvider which still lives in `lise_ai/lib/omnicore/provider/`)

## Usage

```dart
import 'package:omnicore_memory/omnicore_memory.dart';
import 'package:omnicore_foundation/omnicore_foundation.dart';

final KeyValueStorage storage = MyStorageImpl();  // app-provided
await storage.init();

final lt = LongTermMemory();
await lt.init(storage);

await lt.updateSubjectMastery('Trigonometri', 0.05);
print(lt.buildLongTermBlock());
```

## Storage contract

Each memory class persists under a fixed key in the backing KV store:

| Class | Key |
|---|---|
| `LongTermMemory` | `cognitive_long_term_v2` |
| `EpisodicMemory` | `cognitive_episodic_v1` |
| `SemanticMemory` | `cognitive_semantic_v1` |

These keys are versioned and **must not change** between releases without
a migration plan — they encode existing user data.
