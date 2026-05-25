// assistant_pacing_hint.dart
// Domain-agnostic pacing-adjustment signal. Verticals map their own enums
// (LiseAI's PacingAdjustment) via an extension that returns an
// [AssistantPacingHint] handle.
//
// Same two-axis design as [AssistantTone]:
//   • [kind]   — stable machine identifier (lowercase enum name).
//                Agentic logic branches on this.
//   • [isNoOp] — fast convenience for "no adjustment requested" branch.
//                Memory layers skip emitting context when this is true.
//
// Future evolution policy: optional reason / scope / urgency getters
// may be added later with default implementations.

abstract class AssistantPacingHint {
  /// Stable machine-readable identifier. Suggested format: lowercase
  /// snake_case matching the source enum value (e.g. "shorten_chunks",
  /// "add_example", "speed_up"). MUST be locale-independent.
  String get kind;

  /// True when the hint is effectively a no-op (the equivalent of
  /// "no adjustment requested"). Memory layers use this to skip
  /// including the hint in the context block.
  bool get isNoOp;
}
