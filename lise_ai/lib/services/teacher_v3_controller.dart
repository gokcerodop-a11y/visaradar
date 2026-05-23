import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/lesson_timeline.dart';

/// Master clock for Teacher Mode V3.
/// Drives board animation time AND chat text reveal from one timer.
class TeacherV3Controller {
  final LessonTimeline lesson;

  // ── Public notifiers ─────────────────────────────────────────────────────
  final animTimeNotifier      = ValueNotifier<double>(0.0);
  final stepIndexNotifier     = ValueNotifier<int>(0);
  final revealedCharsNotifier = ValueNotifier<int>(0);
  final isPlayingNotifier     = ValueNotifier<bool>(false);

  // ── Speed (decoupled) ─────────────────────────────────────────────────────
  double _boardSpeedMul; // board animation playback rate (0.40 slow → 1.4 fast)
  double _textCps;       // chat text chars per second (independent of board)

  // ── Internal ──────────────────────────────────────────────────────────────
  Timer? _timer;
  double _elapsed = 0.0; // real seconds since playback started
  int _lastStep = 0;

  static const _tickMs = 50; // 20fps tick

  TeacherV3Controller({
    required this.lesson,
    double boardSpeedMul = 0.40,
    double textCps = 5.83, // 70 WPM = 70 × 5 chars/word / 60s
  })  : _boardSpeedMul = boardSpeedMul,
        _textCps = textCps;

  // Full chat text = all step texts joined with double newline
  String get fullText => lesson.steps.map((s) => s.text).join('\n\n');
  int get _totalChars => fullText.length;

  // Board animation time (board-seconds)
  double get _boardTime => _elapsed * _boardSpeedMul;

  // Total lesson board duration (at 1× speed)
  double get _totalDuration => lesson.whiteboardData.totalDuration;

  void start() {
    if (isPlayingNotifier.value) return;
    isPlayingNotifier.value = true;
    debugPrint('[TeacherV3] playback started');
    // Defer first tick to next event loop turn so we don't fire
    // during the Flutter frame that's currently building the canvas.
    Timer(Duration.zero, () {
      if (isPlayingNotifier.value) {
        _timer = Timer.periodic(const Duration(milliseconds: _tickMs), _tick);
      }
    });
  }

  void _tick(Timer timer) {
    _elapsed += _tickMs / 1000.0;

    // ── Board animation time ────────────────────────────────────────────────
    final bt = _boardTime;
    animTimeNotifier.value = bt;

    // ── Step index (driven by board time) ──────────────────────────────────
    int newStep = 0;
    for (int i = lesson.steps.length - 1; i >= 0; i--) {
      if (bt >= lesson.stepStartTime(i)) {
        newStep = i;
        break;
      }
    }
    if (newStep != _lastStep) {
      _lastStep = newStep;
      stepIndexNotifier.value = newStep;
      debugPrint('[TeacherV3] step changed → $newStep');
    }

    // ── Chat text reveal (fixed chars/sec, independent of board) ───────────
    final chars = math.min(_totalChars, (_elapsed * _textCps).round());
    revealedCharsNotifier.value = chars;

    // ── Done: both board drawn and text fully revealed ──────────────────────
    final boardDone = bt >= _totalDuration + 3.0;
    final textDone  = chars >= _totalChars;
    if (boardDone && textDone) {
      timer.cancel();
      isPlayingNotifier.value = false;
      debugPrint('[TeacherV3] playback finished');
    }
  }

  /// Update playback speed. Affects both board animation and text reveal rate.
  /// [boardMul]: board speed multiplier (0.40=slow, 0.80=normal, 1.4=fast)
  /// [textCps]: chat text chars per second (5.83=70WPM, 9.17=110WPM, 12.5=150WPM)
  void setSpeed(double boardMul, double textCps) {
    _boardSpeedMul = boardMul;
    _textCps = textCps;
  }

  void replay() {
    _timer?.cancel();
    _elapsed = 0.0;
    _lastStep = 0;
    animTimeNotifier.value = 0.0;
    stepIndexNotifier.value = 0;
    revealedCharsNotifier.value = 0;
    isPlayingNotifier.value = true;
    Timer(Duration.zero, () {
      if (isPlayingNotifier.value) {
        _timer = Timer.periodic(const Duration(milliseconds: _tickMs), _tick);
      }
    });
    debugPrint('[TeacherV3] playback started (replay)');
  }

  void dispose() {
    _timer?.cancel();
    animTimeNotifier.dispose();
    stepIndexNotifier.dispose();
    revealedCharsNotifier.dispose();
    isPlayingNotifier.dispose();
  }
}
