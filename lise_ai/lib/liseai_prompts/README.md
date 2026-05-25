# lib/liseai_prompts/

LiseAI-specific prompt construction.

**Status — Phase 1**: thin delegate over `AnthropicService.buildSystemPrompt`.
The actual prompt strings still live in `services/anthropic_service.dart`
(the canonical source). This module exists so new call sites depend on a
stable interface and future phases can move the strings here without
churning every caller.

## Usage

```dart
import 'package:lise_ai/liseai_prompts/liseai_prompts.dart';

const builder = LiseAIPromptBuilder();
final prompt = builder.build(
  mode: LessonMode.ogretmenGibi,
  level: StudentLevel.sinif11,
);
```

## Future migration

Per `docs/architecture/omnicore_migration_plan.md` §5 Phase 5:

1. Move `_basePersona`, `_latexRules`, `_modeInstructions` and `_wbSystemPrompt`
   strings from `anthropic_service.dart` into this directory as named
   constants/templates.
2. Reverse the dependency: `AnthropicService.buildSystemPrompt` will delegate
   INTO `LiseAIPromptBuilder` instead of the current direction.
3. Once stable, extract this module as its own `liseai_prompts` package
   under `packages/liseai_prompts/` so the LiseAI app can be built
   alongside other OmniCore-based verticals without prompt leakage.
