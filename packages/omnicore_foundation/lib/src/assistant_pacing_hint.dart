// assistant_pacing_hint.dart
// Domain-agnostic pacing-adjustment signal. Verticals map their own enums
// (LiseAI's PacingAdjustment) via an extension that returns an
// [AssistantPacingHint] handle.

abstract class AssistantPacingHint {
  /// Symbolic name (enum-style identifier) for the pacing state.
  /// Memory/log layers serialize this verbatim.
  String get name;

  /// True when the hint is effectively a no-op (the equivalent of
  /// "no adjustment requested"). Memory layers use this to skip
  /// including the hint in the context block.
  bool get isNoOp;
}
