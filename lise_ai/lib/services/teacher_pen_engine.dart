import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ── PenMode ───────────────────────────────────────────────────────────────────

enum PenMode {
  redCorrection,      // red, thick — marking mistakes
  blueExplanation,    // blue, medium — annotating steps
  greenConfirmation,  // green, thin — marking correct items
  chalk,              // off-white, slightly rough — board aesthetic
  geometry,           // thin, precise, dark blue — geometric constructions
}

extension PenModeExt on PenMode {
  Color get color => switch (this) {
        PenMode.redCorrection    => const Color(0xFFF87171),
        PenMode.blueExplanation  => const Color(0xFF60A5FA),
        PenMode.greenConfirmation => const Color(0xFF4ADE80),
        PenMode.chalk            => const Color(0xFFE5E7EB),
        PenMode.geometry         => const Color(0xFF818CF8),
      };

  double get baseWidth => switch (this) {
        PenMode.redCorrection    => 3.2,
        PenMode.blueExplanation  => 2.4,
        PenMode.greenConfirmation => 1.8,
        PenMode.chalk            => 2.8,
        PenMode.geometry         => 1.4,
      };

  bool get hasTexture => this == PenMode.chalk;
  bool get isSmooth   => this == PenMode.geometry;
}

// ── PenPoint ──────────────────────────────────────────────────────────────────

class PenPoint {
  final Offset position;  // normalized 0-1
  final double pressure;  // 0-1 simulated
  final int timeMs;       // milliseconds from stroke start

  const PenPoint({
    required this.position,
    required this.pressure,
    required this.timeMs,
  });
}

// ── PenStroke ─────────────────────────────────────────────────────────────────

class PenStroke {
  final List<PenPoint> points;
  final PenMode mode;

  // Stroke-level metadata
  final Duration prePause;   // teacher "thinks" before marking
  final Duration postPause;  // pause after stroke completes

  const PenStroke({
    required this.points,
    required this.mode,
    this.prePause = Duration.zero,
    this.postPause = const Duration(milliseconds: 300),
  });

  Duration get totalDuration {
    if (points.isEmpty) return Duration.zero;
    return Duration(milliseconds: points.last.timeMs);
  }
}

// ── TeacherPenEngine ──────────────────────────────────────────────────────────
//
// Manages a list of teacher strokes with animated replay.
// "Human realism":
//   - Pause before first stroke (teacher studies the work)
//   - Variable speed (slows at important moments)
//   - Pressure simulation (soft start → firm → release)
//   - Pre-pause before each new mark (teacher "considers")

class TeacherPenEngine extends ChangeNotifier {
  final List<PenStroke> _strokes = [];

  // Replay state
  bool _isReplaying = false;
  int _currentStrokeIndex = 0;
  int _currentPointIndex = 0;  // how far through current stroke
  Timer? _replayTimer;
  final _rng = math.Random();

  List<PenStroke> get strokes => List.unmodifiable(_strokes);
  bool get isReplaying => _isReplaying;
  int get currentStrokeIndex => _currentStrokeIndex;
  int get currentPointIndex => _currentPointIndex;

  // ── Stroke management ──────────────────────────────────────────────────────

  void addStroke(PenStroke stroke) {
    _strokes.add(stroke);
    notifyListeners();
  }

  void addStrokes(List<PenStroke> strokes) {
    _strokes.addAll(strokes);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _currentStrokeIndex = 0;
    _currentPointIndex = 0;
    _isReplaying = false;
    _replayTimer?.cancel();
    notifyListeners();
  }

  // ── Replay ────────────────────────────────────────────────────────────────

  /// Animate through all strokes from the beginning.
  /// Each stroke plays with its natural timing + pre/post pauses.
  Future<void> replayAll({VoidCallback? onComplete}) async {
    if (_strokes.isEmpty) return;
    _isReplaying = true;
    _currentStrokeIndex = 0;
    _currentPointIndex = 0;
    notifyListeners();

    for (int si = 0; si < _strokes.length; si++) {
      if (!_isReplaying) break;
      _currentStrokeIndex = si;
      _currentPointIndex = 0;
      notifyListeners();

      final stroke = _strokes[si];

      // Pre-pause: teacher "studies" before marking
      if (stroke.prePause.inMilliseconds > 0) {
        await Future.delayed(stroke.prePause);
        if (!_isReplaying) break;
      }

      // Animate through points
      for (int pi = 0; pi < stroke.points.length; pi++) {
        if (!_isReplaying) break;
        _currentPointIndex = pi;
        notifyListeners();

        // Delay until next point
        if (pi < stroke.points.length - 1) {
          final dtMs = stroke.points[pi + 1].timeMs - stroke.points[pi].timeMs;
          await Future.delayed(Duration(milliseconds: dtMs.clamp(8, 80)));
        }
      }

      // Post-pause
      if (stroke.postPause.inMilliseconds > 0 && _isReplaying) {
        await Future.delayed(stroke.postPause);
      }
    }

    _isReplaying = false;
    notifyListeners();
    onComplete?.call();
  }

  void stopReplay() {
    _isReplaying = false;
    _replayTimer?.cancel();
    notifyListeners();
  }

  // ── Stroke generation helpers ──────────────────────────────────────────────

  /// Generate a circle stroke around a normalized [rect].
  static PenStroke circle(
    Rect rect,
    PenMode mode, {
    Duration prePause = const Duration(milliseconds: 600),
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2 * 1.15; // slightly larger than the region
    final ry = rect.height / 2 * 1.3;
    final points = <PenPoint>[];

    const steps = 36;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = -math.pi / 2 + t * 2 * math.pi; // start at top
      final jitter = 0.003 * (math.Random().nextDouble() - 0.5); // tiny wobble
      final x = cx + rx * math.cos(angle) + jitter;
      final y = cy + ry * math.sin(angle) + jitter;

      // Pressure: builds mid-stroke, releases at end
      final pressure = i == 0 || i == steps
          ? 0.3
          : 0.5 + 0.5 * math.sin(t * math.pi);

      points.add(PenPoint(
        position: Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)),
        pressure: pressure,
        timeMs: (i * 25).round(), // ~900ms total for circle
      ));
    }

    return PenStroke(
      points: points,
      mode: mode,
      prePause: prePause,
      postPause: const Duration(milliseconds: 400),
    );
  }

  /// Generate a horizontal line stroke across a [rect].
  static PenStroke line(
    Rect rect,
    PenMode mode, {
    bool strikethrough = false,
    Duration prePause = const Duration(milliseconds: 300),
  }) {
    final y = strikethrough
        ? rect.center.dy
        : rect.bottom + 0.005; // underline below
    final points = <PenPoint>[];
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = rect.left + t * rect.width;
      points.add(PenPoint(
        position: Offset(x, y),
        pressure: 0.4 + 0.5 * math.sin(t * math.pi),
        timeMs: (i * 15).round(),
      ));
    }
    return PenStroke(
      points: points,
      mode: mode,
      prePause: prePause,
      postPause: const Duration(milliseconds: 200),
    );
  }

  /// Generate a checkmark stroke at the center of [rect].
  static PenStroke checkmark(
    Rect rect,
    PenMode mode, {
    Duration prePause = const Duration(milliseconds: 200),
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final s = math.min(rect.width, rect.height) * 0.4;

    // Checkmark: down-left then up-right
    final pts = [
      Offset(cx - s, cy),
      Offset(cx - s * 0.3, cy + s * 0.5),
      Offset(cx + s, cy - s * 0.5),
    ];

    final points = <PenPoint>[];
    int ms = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      const steps = 10;
      for (int j = 0; j <= steps; j++) {
        final t = j / steps;
        final pos = Offset.lerp(pts[i], pts[i + 1], t)!;
        points.add(PenPoint(
          position: pos,
          pressure: 0.5 + 0.3 * math.sin(t * math.pi),
          timeMs: ms,
        ));
        ms += 12;
      }
    }
    return PenStroke(
      points: points,
      mode: mode,
      prePause: prePause,
      postPause: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    super.dispose();
  }
}

// ── TeacherPenCanvas ──────────────────────────────────────────────────────────
//
// Renders pen strokes on a canvas. Listens to TeacherPenEngine.
// Uses CustomPainter for efficient rendering.

class TeacherPenCanvas extends StatelessWidget {
  final TeacherPenEngine engine;
  final Size imageSize; // widget pixel size — strokes are normalized to this

  const TeacherPenCanvas({
    super.key,
    required this.engine,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (_, __) => CustomPaint(
        painter: _PenPainter(
          strokes: engine.strokes,
          currentStroke: engine.currentStrokeIndex,
          currentPoint: engine.currentPointIndex,
          isReplaying: engine.isReplaying,
          imageSize: imageSize,
        ),
        size: imageSize,
      ),
    );
  }
}

class _PenPainter extends CustomPainter {
  final List<PenStroke> strokes;
  final int currentStroke;
  final int currentPoint;
  final bool isReplaying;
  final Size imageSize;

  const _PenPainter({
    required this.strokes,
    required this.currentStroke,
    required this.currentPoint,
    required this.isReplaying,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int si = 0; si < strokes.length; si++) {
      final stroke = strokes[si];
      final isCurrentlyDrawing = isReplaying && si == currentStroke;
      final maxPoint = isCurrentlyDrawing
          ? currentPoint
          : (isReplaying && si > currentStroke ? -1 : stroke.points.length - 1);

      if (maxPoint < 0) continue; // not yet revealed
      if (stroke.points.isEmpty) continue;

      _drawStroke(canvas, size, stroke, maxPoint);
    }
  }

  void _drawStroke(Canvas canvas, Size size, PenStroke stroke, int maxPoint) {
    if (stroke.points.length < 2) return;
    final limit = maxPoint.clamp(0, stroke.points.length - 1);

    final path = Path();
    final first = _toPixel(stroke.points.first.position, size);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i <= limit; i++) {
      final prev = _toPixel(stroke.points[i - 1].position, size);
      final curr = _toPixel(stroke.points[i].position, size);
      // Quadratic bezier through midpoint for smooth curves
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }

    final p = stroke.points[limit];
    final paint = Paint()
      ..color = stroke.mode.color.withValues(alpha: 0.88)
      ..strokeWidth = stroke.mode.baseWidth * (0.7 + 0.6 * p.pressure)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.mode.hasTexture) {
      // Chalk: draw twice with slight offset for texture
      paint.color = stroke.mode.color.withValues(alpha: 0.60);
      paint.strokeWidth *= 1.4;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
      canvas.drawPath(path, paint);
      paint.color = stroke.mode.color.withValues(alpha: 0.90);
      paint.strokeWidth /= 1.8;
      paint.maskFilter = null;
    }

    // Soft glow for correction pen
    if (stroke.mode == PenMode.redCorrection) {
      final glowPaint = Paint()
        ..color = stroke.mode.color.withValues(alpha: 0.12)
        ..strokeWidth = paint.strokeWidth * 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, glowPaint);
    }

    canvas.drawPath(path, paint);
  }

  Offset _toPixel(Offset norm, Size size) =>
      Offset(norm.dx * size.width, norm.dy * size.height);

  @override
  bool shouldRepaint(_PenPainter old) =>
      old.currentPoint != currentPoint ||
      old.currentStroke != currentStroke ||
      old.isReplaying != isReplaying ||
      old.strokes.length != strokes.length;
}
