# lib/omnicore/

Internal staging area for OmniCore extraction.

**Status — Phase 1**: code lives here additively. The existing services
under `lib/services/` are NOT modified. Once a module proves itself, it
will be moved to `packages/omnicore_*/` in a later phase.

## Current contents

### Barrels (Phase 2)

| Barrel | Future package | Re-exports |
|---|---|---|
| `foundation.dart` | `omnicore_foundation` | api_client, app_logger, app_version_service, connectivity_service, crash_reporter, error_handler, haptics_service, runtime_stability_monitor, runtime_validation_service, storage_service |
| `memory.dart` | `omnicore_memory` | 5 memory layers + 3 orchestrators |
| `session.dart` | `omnicore_session` | session_continuity_service, session_recovery_service |
| `streaming.dart` | `omnicore_streaming` | streaming_teacher_session |
| `voice.dart` | `omnicore_voice` | speech_service, teacher_voice_service, voice_command_detector, voice_playback_queue, silence_detector |
| `vision.dart` | `omnicore_vision` | visual_reasoning_engine, pdf_service, image_context_model |
| `sync.dart` | `omnicore_sync` | supabase_sync_service, sync_queue, sync_repository, backend_provider_service, auth_service, adapters |
| `observability.dart` | `omnicore_observability` | telemetry_service, release_validator, runtime monitors, scenario_runner, stress_test_runner, crash_reporter |
| `cost.dart` | `omnicore_cost` | ai_cost_tracker |
| `provider.dart` | `omnicore_provider` | AIProvider + ClaudeProvider + OpenAI/Gemini stubs |

Some files (crash_reporter, runtime_stability_monitor) appear in two
barrels temporarily; Phase 6 chooses a canonical location for each.

### `provider/`
Provider-agnostic LLM interface plus three implementations:

| File | Role |
|---|---|
| `ai_message.dart` | Role + text + optional image attachments value object |
| `ai_provider.dart` | Abstract interface + capabilities + not-ready exception |
| `claude_provider.dart` | Thin adapter over the existing `AnthropicService` |
| `openai_provider.dart` | Phase-1 stub — throws `AIProviderNotReadyException` |
| `gemini_provider.dart` | Phase-1 stub — throws `AIProviderNotReadyException` |
| `../provider.dart` | Barrel re-exporting all of the above |

### Usage today

Existing call sites continue to use `AnthropicService` directly — nothing
changes. New code can opt into the abstraction:

```dart
import 'package:lise_ai/omnicore/provider.dart';

final AIProvider ai = ClaudeProvider(anthropicService, hasKey: keyExists);
await for (final chunk in ai.streamMessage(history, systemPrompt: ...)) {
  print(chunk);
}
```

OpenAI and Gemini providers will start working in Phase 5 of the
migration plan (`docs/architecture/omnicore_migration_plan.md`).
