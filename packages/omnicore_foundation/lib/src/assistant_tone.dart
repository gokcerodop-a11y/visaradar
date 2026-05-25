// assistant_tone.dart
// Domain-agnostic notion of an assistant's current emotional / interaction
// tone. Each vertical adapts its own enum (LiseAI's TeacherEmotionalState,
// PersonalAI's CompanionTone, etc.) by exposing a `.tone` extension that
// returns an [AssistantTone] handle.
//
// The interface is intentionally tiny: memory and voice modules only need
// to display the tone label.

abstract class AssistantTone {
  /// Short human-readable label (typically rendered in Turkish or English
  /// for prompt context — verticals pick the wording).
  String get label;
}
