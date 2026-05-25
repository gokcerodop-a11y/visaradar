// assistant_tone.dart
// Domain-agnostic notion of an assistant's current emotional / interaction
// tone. Each vertical adapts its own enum (LiseAI's TeacherEmotionalState,
// PersonalAI's CompanionTone, etc.) by exposing a `.tone` extension that
// returns an [AssistantTone] handle.
//
// Two-axis design:
//   • [label]  — human-readable, localized (Turkish in LiseAI, English in
//                PersonalAI, etc.). Goes into UI and prompt context.
//   • [kind]   — stable machine-readable identifier. Same across locales.
//                Agentic / automation layers branch on [kind], never on
//                [label]. Persisted to logs and analytics.
//
// Future evolution:
//   May grow optional valence / intensity getters when an agentic vertical
//   needs to reason about tone strength. Additions land as non-abstract
//   default implementations so existing implementations don't break.

abstract class AssistantTone {
  /// Short human-readable label (typically localized). Used in UI and
  /// in prompt context blocks the assistant sends to the LLM.
  String get label;

  /// Stable machine-readable identifier. MUST be locale-independent and
  /// MUST NOT change between releases for the same conceptual tone.
  /// Suggested format: lowercase snake_case matching the source enum
  /// value (e.g. "calm", "excited", "encouraging").
  String get kind;
}
