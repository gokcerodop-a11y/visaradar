# omnicore_session

Session continuity + cold-start recovery for the OmniCore AI Engine.

## Contents

| Service | Key | Purpose |
|---|---|---|
| `SessionContinuityService` | `session_continuity_v1` | Cross-session topic context, confidence trend, frustration streak, used analogies, last-session summary. Builds the `[DERS SÜREKLİLİĞİ]` prompt block. |
| `SessionRecoveryService` | `session_snapshot_v1` | Saves the most recent session snapshot (topic, history length, last subtitle, emotional state, lesson mode). Restorable within 24 hours of close. |

Both services depend only on `package:omnicore_foundation/omnicore_foundation.dart`
for the `KeyValueStorage` interface. Vertical-specific helpers
(`extractHomework`, `buildReturnGreeting`) live in their host app.

## Usage

```dart
import 'package:omnicore_session/omnicore_session.dart';
import 'package:omnicore_foundation/omnicore_foundation.dart';

final KeyValueStorage storage = MyStorageImpl();
await storage.init();

final continuity = SessionContinuityService();
await continuity.init(storage);

await continuity.recordInteraction(
  topic: 'Trigonometri',
  successEstimate: 0.65,
);

print(continuity.buildContinuityPrompt());
```

## Stability

Both Hive keys (`session_continuity_v1`, `session_snapshot_v1`) and the
JSON serialization shape are stable. Migration plans are required before
either changes.
