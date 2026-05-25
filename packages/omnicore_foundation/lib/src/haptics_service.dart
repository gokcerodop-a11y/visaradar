import 'package:flutter/services.dart';

/// Centralised haptic feedback abstraction.
///
/// All haptic calls in the app go through here so that:
/// - haptics can be disabled globally in one place
/// - the intensity/pattern can be adjusted per platform without changes
///   scattered across the widget tree.
class HapticsService {
  HapticsService._();

  static bool _enabled = true;

  /// Globally enable or disable all haptic feedback.
  static void setEnabled(bool enabled) => _enabled = enabled;
  static bool get isEnabled => _enabled;

  // ── Feedback types ────────────────────────────────────────────────────────

  /// Light tap — use for selection changes, mode switches.
  static Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium tap — use for confirmations, sending a message.
  static Future<void> medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy tap — use for achievement unlocks, exam camp start.
  static Future<void> heavy() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Selection tick — use for scrolling through items.
  static Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Success pattern — double pulse for achievement/streak celebration.
  static Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }

  /// Error pattern — three short taps for wrong answer.
  static Future<void> error() async {
    if (!_enabled) return;
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
  }
}
