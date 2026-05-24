import 'dart:async';

/// Detects student idle/silence periods and fires tiered callbacks so the
/// teacher can naturally check in without being robotic.
///
/// Usage:
///   detector.arm(onCheckIn: ..., onDeepSilence: ...);  // after AI finishes
///   detector.disarm();                                   // on user input
///   detector.dispose();                                  // in widget dispose
class SilenceDetector {
  static const _checkInDelay = Duration(seconds: 32);
  static const _deepSilenceDelay = Duration(seconds: 90);

  Timer? _checkInTimer;
  Timer? _deepTimer;
  bool _disposed = false;

  /// Arm the detector. Fires [onCheckIn] after ~32 s then [onDeepSilence]
  /// after ~90 s. Both are cancelled automatically if [disarm] is called.
  void arm({
    required void Function() onCheckIn,
    required void Function() onDeepSilence,
  }) {
    if (_disposed) return;
    _cancel();
    _checkInTimer = Timer(_checkInDelay, () {
      if (_disposed) return;
      onCheckIn();
      // After check-in fires, schedule deeper prompt.
      _deepTimer = Timer(
        _deepSilenceDelay - _checkInDelay,
        () { if (!_disposed) onDeepSilence(); },
      );
    });
  }

  /// Call whenever the student sends input — cancels pending callbacks.
  void disarm() => _cancel();

  void _cancel() {
    _checkInTimer?.cancel();
    _deepTimer?.cancel();
    _checkInTimer = null;
    _deepTimer = null;
  }

  void dispose() {
    _disposed = true;
    _cancel();
  }
}
