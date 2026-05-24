import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/correction_annotation.dart';

// ── VisualCorrectionLayer ─────────────────────────────────────────────────────
//
// Animated overlay drawn on top of a student work image.
// "Human teacher marking paper" aesthetic:
//   - Step-by-step reveal (teacher doesn't show everything at once)
//   - Annotations appear with entry animations
//   - Spotlight draws attention before circling
//   - Arrows animate from source to target
//   - Error text fades in after the circle
//
// All coordinates in annotations are normalized 0-1.
// This widget scales them to its actual render size.

class VisualCorrectionLayer extends StatefulWidget {
  final List<CorrectionAnnotation> annotations;
  final int currentRevealStep; // how many steps revealed (0 = none, 1 = first, etc.)
  final Offset? spotlightCenter; // normalized, for manual spotlight override

  const VisualCorrectionLayer({
    super.key,
    required this.annotations,
    required this.currentRevealStep,
    this.spotlightCenter,
  });

  @override
  State<VisualCorrectionLayer> createState() => _VisualCorrectionLayerState();
}

class _VisualCorrectionLayerState extends State<VisualCorrectionLayer>
    with TickerProviderStateMixin {
  // Per-annotation animation controllers (entry animation)
  final Map<String, AnimationController> _controllers = {};
  final Map<String, Animation<double>> _animations = {};

  // Arrow dash animation
  late AnimationController _dashCtrl;

  // Spotlight pulse
  late AnimationController _spotCtrl;

  @override
  void initState() {
    super.initState();
    _dashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _spotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _setupAnnotationControllers();
  }

  @override
  void didUpdateWidget(VisualCorrectionLayer old) {
    super.didUpdateWidget(old);
    _setupAnnotationControllers();
    _triggerNewAnnotations(old.currentRevealStep);
  }

  void _setupAnnotationControllers() {
    for (final ann in widget.annotations) {
      if (!_controllers.containsKey(ann.id)) {
        final ctrl = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        );
        _controllers[ann.id] = ctrl;
        _animations[ann.id] = CurvedAnimation(
          parent: ctrl,
          curve: Curves.easeOutBack,
        );
      }
    }
  }

  void _triggerNewAnnotations(int prevStep) {
    for (final ann in widget.annotations) {
      if (ann.revealStep < widget.currentRevealStep &&
          ann.revealStep >= prevStep) {
        _controllers[ann.id]?.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _dashCtrl.dispose();
    _spotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.annotations
        .where((a) => a.revealStep < widget.currentRevealStep)
        .toList();

    return AnimatedBuilder(
      animation: Listenable.merge([_dashCtrl, _spotCtrl]),
      builder: (_, __) {
        return CustomPaint(
          painter: _CorrectionPainter(
            annotations: visible,
            animations: _animations,
            dashProgress: _dashCtrl.value,
            spotPulse: _spotCtrl.value,
            spotlightCenter: widget.spotlightCenter,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

// ── _CorrectionPainter ────────────────────────────────────────────────────────

class _CorrectionPainter extends CustomPainter {
  final List<CorrectionAnnotation> annotations;
  final Map<String, Animation<double>> animations;
  final double dashProgress;
  final double spotPulse;
  final Offset? spotlightCenter;

  const _CorrectionPainter({
    required this.annotations,
    required this.animations,
    required this.dashProgress,
    required this.spotPulse,
    this.spotlightCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw spotlight first (behind other annotations)
    final spotAnns = annotations.where((a) => a.type == AnnotationType.spotlight);
    for (final ann in spotAnns) {
      _drawSpotlight(canvas, size, ann);
    }

    // Draw other annotations
    for (final ann in annotations) {
      if (ann.type == AnnotationType.spotlight) continue;
      final t = animations[ann.id]?.value ?? 1.0;
      _drawAnnotation(canvas, size, ann, t);
    }

    // Manual spotlight override
    if (spotlightCenter != null) {
      _drawSpotlightAt(
        canvas,
        size,
        spotlightCenter!,
        0.12 + 0.02 * spotPulse,
      );
    }
  }

  Rect _toPixelRect(Rect norm, Size size) {
    return Rect.fromLTWH(
      norm.left * size.width,
      norm.top * size.height,
      norm.width * size.width,
      norm.height * size.height,
    );
  }

  Offset _toPixel(Offset norm, Size size) =>
      Offset(norm.dx * size.width, norm.dy * size.height);

  void _drawAnnotation(Canvas canvas, Size size, CorrectionAnnotation ann, double t) {
    if (t <= 0) return;
    final rect = _toPixelRect(ann.region, size);

    switch (ann.type) {
      case AnnotationType.errorCircle:
        _drawErrorCircle(canvas, rect, ann, t);
      case AnnotationType.correctMark:
        _drawCorrectMark(canvas, rect, ann, t);
      case AnnotationType.correctionArrow:
        _drawCorrectionArrow(canvas, size, ann, t);
      case AnnotationType.textMarker:
        _drawTextMarker(canvas, rect, ann, t);
      case AnnotationType.highlightLine:
        _drawHighlightLine(canvas, rect, ann, t);
      case AnnotationType.crossOut:
        _drawCrossOut(canvas, rect, ann, t);
      case AnnotationType.underline:
        _drawUnderline(canvas, rect, ann, t);
      case AnnotationType.bubbleNote:
        _drawBubbleNote(canvas, rect, ann, t);
      case AnnotationType.spotlight:
        break; // handled separately
    }
  }

  // ── Error circle ────────────────────────────────────────────────────────────

  void _drawErrorCircle(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    final center = rect.center;
    final rx = rect.width / 2 + 6;
    final ry = rect.height / 2 + 4;
    final color = ann.baseColor;

    // Soft glow
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2 * t, height: ry * 2 * t),
      Paint()
        ..color = color.withValues(alpha: 0.08 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main circle (drawn as dashed-ish arc for handwritten feel)
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85 * t)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(t, t);
    canvas.translate(-center.dx, -center.dy);

    // Slight wobble: draw as path with tiny offsets
    final path = Path();
    for (int i = 0; i <= 40; i++) {
      final angle = -math.pi / 2 + (i / 40) * 2 * math.pi;
      final wobble = 0.5 * math.sin(angle * 3);
      final x = center.dx + (rx + wobble) * math.cos(angle);
      final y = center.dy + (ry + wobble) * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();

    // Label text
    if (ann.label != null && t > 0.7) {
      _drawLabel(canvas, Offset(center.dx, rect.bottom + ry + 6), ann.label!, color, t);
    }
  }

  // ── Correct mark ────────────────────────────────────────────────────────────

  void _drawCorrectMark(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    final center = rect.center;
    final s = math.min(rect.width, rect.height) * 0.5;
    final color = ann.baseColor;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.90 * t)
      ..strokeWidth = 2.5 * t
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw checkmark
    final path = Path()
      ..moveTo(center.dx - s, center.dy)
      ..lineTo(center.dx - s * 0.2, center.dy + s * 0.6)
      ..lineTo(center.dx + s, center.dy - s * 0.5);

    // Animate partial path draw
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * t);
    canvas.drawPath(partial, paint);
  }

  // ── Correction arrow ────────────────────────────────────────────────────────

  void _drawCorrectionArrow(Canvas canvas, Size size, CorrectionAnnotation ann, double t) {
    if (ann.arrowTarget == null) return;

    final start = _toPixel(ann.region.center, size);
    final end = _toPixel(ann.arrowTarget!, size);

    // Animate: arrow grows from start to end
    final current = Offset.lerp(start, end, t)!;

    final paint = Paint()
      ..color = ann.baseColor.withValues(alpha: 0.85 * t)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Line
    canvas.drawLine(start, current, paint);

    // Arrowhead
    if (t > 0.85) {
      final dir = (end - start).direction;
      final headLen = 10.0;
      final arrowPaint = Paint()
        ..color = ann.baseColor.withValues(alpha: 0.90 * t)
        ..style = PaintingStyle.fill;

      final p1 = current +
          Offset(math.cos(dir + 2.5) * headLen, math.sin(dir + 2.5) * headLen);
      final p2 = current +
          Offset(math.cos(dir - 2.5) * headLen, math.sin(dir - 2.5) * headLen);
      canvas.drawPath(
        Path()..moveTo(current.dx, current.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(),
        arrowPaint,
      );
    }
  }

  // ── Text marker ────────────────────────────────────────────────────────────

  void _drawTextMarker(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    if (ann.label == null) return;
    final color = ann.baseColor;
    final center = Offset(rect.left, rect.center.dy);

    // Small dot
    canvas.drawCircle(
        center,
        4 * t,
        Paint()..color = color.withValues(alpha: 0.9 * t));

    // Horizontal tick line
    canvas.drawLine(
      center,
      Offset(center.dx + 14 * t, center.dy),
      Paint()
        ..color = color.withValues(alpha: 0.8 * t)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    if (t > 0.5) {
      _drawLabel(canvas, Offset(center.dx + 16, center.dy - 8), ann.label!, color, (t - 0.5) * 2);
    }
  }

  // ── Highlight line ──────────────────────────────────────────────────────────

  void _drawHighlightLine(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    final color = ann.baseColor.withValues(alpha: 0.28 * t);
    canvas.drawRect(
      Rect.fromLTWH(
          rect.left, rect.top, rect.width * t, rect.height),
      Paint()..color = color,
    );
  }

  // ── Cross out ──────────────────────────────────────────────────────────────

  void _drawCrossOut(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    final paint = Paint()
      ..color = ann.baseColor.withValues(alpha: 0.8 * t)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final start = Offset(rect.left, rect.center.dy);
    final end = Offset(rect.left + rect.width * t, rect.center.dy);
    canvas.drawLine(start, end, paint);
  }

  // ── Underline ──────────────────────────────────────────────────────────────

  void _drawUnderline(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    final paint = Paint()
      ..color = ann.baseColor.withValues(alpha: 0.75 * t)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rect.left, rect.bottom + 2),
      Offset(rect.left + rect.width * t, rect.bottom + 2),
      paint,
    );
  }

  // ── Bubble note ────────────────────────────────────────────────────────────

  void _drawBubbleNote(Canvas canvas, Rect rect, CorrectionAnnotation ann, double t) {
    if (ann.label == null) return;
    final color = ann.baseColor;
    final bubbleRect = Rect.fromCenter(
      center: Offset(rect.right + 40, rect.center.dy),
      width: 90,
      height: 28,
    );

    final rrect = RRect.fromRectAndRadius(bubbleRect, const Radius.circular(8));

    // Background
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: 0.12 * t),
    );
    // Border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.40 * t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Text
    if (t > 0.6) {
      _drawLabel(canvas, bubbleRect.center - const Offset(0, 4), ann.label!, color, (t - 0.6) / 0.4);
    }
  }

  // ── Spotlight ──────────────────────────────────────────────────────────────

  void _drawSpotlight(Canvas canvas, Size size, CorrectionAnnotation ann) {
    _drawSpotlightAt(canvas, size, ann.region.center, ann.region.height / 2 + 0.04);
  }

  void _drawSpotlightAt(Canvas canvas, Size size, Offset center, double radiusNorm) {
    final px = _toPixel(center, size);
    final r = radiusNorm * size.shortestSide * (0.9 + 0.1 * spotPulse);

    // Dark overlay with oval cutout
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerPath = Path()..addRect(fullRect);
    final innerPath = Path()
      ..addOval(Rect.fromCenter(center: px, width: r * 2 * 1.8, height: r * 2));
    final combined = Path.combine(PathOperation.difference, outerPath, innerPath);

    canvas.drawPath(
      combined,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Subtle glow ring around spotlight
    canvas.drawCircle(
      px,
      r * 1.1,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06 + 0.04 * spotPulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // ── Label helper ───────────────────────────────────────────────────────────

  void _drawLabel(Canvas canvas, Offset pos, String text, Color color, double t) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.95 * t),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5 * t),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CorrectionPainter old) =>
      old.annotations != annotations ||
      old.dashProgress != dashProgress ||
      old.spotPulse != spotPulse ||
      old.spotlightCenter != spotlightCenter;
}
