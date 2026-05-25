# lib/omnicore/

Internal staging area for OmniCore extraction.

**Status — Phase 1**: code lives here additively. The existing services
under `lib/services/` are NOT modified. Once a module proves itself, it
will be moved to `packages/omnicore_*/` in a later phase.

## Current contents

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
