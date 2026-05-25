// liseai_prompt_builder.dart
// Public surface for building LiseAI-specific system prompts.
//
// Phase 1: this module is a thin delegate over the existing static
// methods on AnthropicService. The actual prompt strings still live in
// anthropic_service.dart (the canonical source). This file exists so
// new call sites can depend on a stable interface, and so future phases
// can move the strings here without changing any caller.
//
// Phase 5 (per docs/architecture/omnicore_migration_plan.md):
//   1. Move _basePersona, _latexRules, _modeInstructions string
//      constants into this file.
//   2. Have AnthropicService.buildSystemPrompt delegate INTO this
//      module, reversing the dependency.
//   3. Then extract LiseAI prompts as their own package.

import '../models/lesson_mode.dart'; // exports LessonMode + StudentLevel
import '../services/anthropic_service.dart';

/// Builds the LiseAI teacher persona + LaTeX rules + mode instructions
/// system prompt that steers the Claude conversation.
class LiseAIPromptBuilder {
  const LiseAIPromptBuilder();

  /// Compose the full LiseAI system prompt for a given mode + student level.
  ///
  /// Currently delegates to [AnthropicService.buildSystemPrompt] — the canonical
  /// source of the LiseAI prompt strings. When Phase 5 of the migration moves
  /// the strings here, this delegation will reverse.
  String build({
    required LessonMode mode,
    required StudentLevel level,
  }) {
    return AnthropicService.buildSystemPrompt(mode, level);
  }

  /// Default LiseAI prompt — "Öğretmen Gibi Anlat" mode at 9. sınıf.
  /// Use only when no explicit mode/level context is available.
  String buildDefault() => build(
        mode: LessonMode.ogretmenGibi,
        level: StudentLevel.sinif9,
      );
}
