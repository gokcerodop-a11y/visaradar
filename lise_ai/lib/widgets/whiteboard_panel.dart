import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/whiteboard_element.dart';

// ── Public panel widget ───────────────────────────────────────────────────────

enum WhiteboardState { closed, loading, ready }

class WhiteboardPanel extends StatelessWidget {
  final WhiteboardState state;
  final WhiteboardData? data;
  final VoidCallback onClose;
  final VoidCallback onReplay;

  const WhiteboardPanel({
    super.key,
    required this.state,
    required this.data,
    required this.onClose,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF060612),
        border: Border(left: BorderSide(color: Color(0xFF1A1A3A), width: 1)),
      ),
      child: Column(
        children: [
          _Header(
            title: data?.title ?? 'Tahta',
            onClose: onClose,
            onReplay: onReplay,
            state: state,
          ),
          Expanded(
            child: switch (state) {
              WhiteboardState.loading => const _LoadingView(),
              WhiteboardState.ready =>
                _WhiteboardCanvas(data: data!),
              WhiteboardState.closed => const SizedBox(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Header bar ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback onReplay;
  final WhiteboardState state;

  const _Header({
    required this.title,
    required this.onClose,
    required this.onReplay,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B1E),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A3A))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3D2E8A), Color(0xFF7C6BF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state == WhiteboardState.ready) ...[
            GestureDetector(
              onTap: onReplay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A3A),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF2A2A5A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_rounded, color: Color(0xFF9B8BFB), size: 13),
                    SizedBox(width: 5),
                    Text('Tekrar Oynat',
                        style: TextStyle(
                            color: Color(0xFF9B8BFB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              size: const Size(72, 72),
              painter: _SpinnerPainter(_ctrl.value),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tahta hazırlanıyor…',
            style: TextStyle(
                color: Color(0xFF9B8BFB),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Claude adımları çiziyor',
            style: TextStyle(color: Color(0xFF374151), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double t;
  _SpinnerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const r = 28.0;

    canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0xFF1A1A3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      t * 2 * math.pi - math.pi / 2,
      math.pi * 1.3,
      false,
      Paint()
        ..color = const Color(0xFF7C6BF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Center spark
    canvas.drawCircle(center, 9, Paint()..color = const Color(0xFF0B0B1E));
    final icon = TextPainter(
      text: const TextSpan(
          text: '✦', style: TextStyle(color: Color(0xFF7C6BF8), fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, center - Offset(icon.width / 2, icon.height / 2));
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.t != t;
}

// ── Whiteboard canvas ─────────────────────────────────────────────────────────

class _WhiteboardCanvas extends StatefulWidget {
  final WhiteboardData data;

  const _WhiteboardCanvas({required this.data});

  @override
  State<_WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<_WhiteboardCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _time;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final dur = widget.data.totalDuration;
    _ctrl = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: (dur * 1000).round().clamp(2000, 40000)),
    )..forward();
    _time = Tween<double>(begin: 0, end: dur)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(_WhiteboardCanvas old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _ctrl.dispose();
      _start();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _time,
      builder: (_, __) => CustomPaint(
        painter: _WhiteboardPainter(
          elements: widget.data.elements,
          time: _time.value,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Whiteboard painter ────────────────────────────────────────────────────────

class _WhiteboardPainter extends CustomPainter {
  final List<WhiteboardElement> elements;
  final double time;

  static const _purple = Color(0xFF9B8BFB);
  static const _bg = Color(0xFF060612);

  const _WhiteboardPainter({required this.elements, required this.time});

  @override
  bool shouldRepaint(_WhiteboardPainter old) => old.time != time;

  // ── Draw duration per element type ─────────────────────────────────────────

  static double _drawDur(WBType t) {
    switch (t) {
      case WBType.point:
        return 0.25;
      case WBType.step:
        return 0.35;
      case WBType.text:
        return 0.55;
      case WBType.formula:
        return 0.70;
      case WBType.line:
      case WBType.arrow:
      case WBType.vector:
        return 0.65;
      case WBType.circle:
      case WBType.rect:
      case WBType.triangle:
        return 0.90;
      case WBType.axes:
        return 1.10;
      case WBType.curve:
        return 0.85;
      case WBType.parabola:
      case WBType.sine:
        return 1.30;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _bg,
    );

    _paintGrid(canvas, size);

    for (final el in elements) {
      if (time < el.delay) continue;
      final progress = ((time - el.delay) / _drawDur(el.type)).clamp(0.0, 1.0);
      _drawElement(canvas, size, el, progress);
    }
  }

  // ── Dot / line grid ────────────────────────────────────────────────────────

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D0D24)
      ..strokeWidth = 1.0;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Dot overlay
    final dot = Paint()..color = const Color(0xFF14143A);
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  // ── Dispatch ───────────────────────────────────────────────────────────────

  void _drawElement(Canvas canvas, Size size, WhiteboardElement el, double p) {
    switch (el.type) {
      case WBType.text:
        _drawText(canvas, size, el, p, formula: false);
      case WBType.formula:
        _drawText(canvas, size, el, p, formula: true);
      case WBType.step:
        _drawStep(canvas, size, el, p);
      case WBType.line:
        _drawLine(canvas, size, el, p);
      case WBType.arrow:
        _drawArrow(canvas, size, el, p, thick: false);
      case WBType.vector:
        _drawArrow(canvas, size, el, p, thick: true);
      case WBType.circle:
        _drawCircle(canvas, size, el, p);
      case WBType.rect:
        _drawRect(canvas, size, el, p);
      case WBType.axes:
        _drawAxes(canvas, size, el, p);
      case WBType.curve:
        _drawCurve(canvas, size, el, p);
      case WBType.point:
        _drawPoint(canvas, size, el, p);
      case WBType.parabola:
        _drawParabola(canvas, size, el, p);
      case WBType.sine:
        _drawSine(canvas, size, el, p);
      case WBType.triangle:
        _drawTriangle(canvas, size, el, p);
    }
  }

  // ── Chalk paint helpers ────────────────────────────────────────────────────

  Paint _chalk(Color color, double width, {double opacity = 1.0}) => Paint()
    ..color = color.withValues(alpha: opacity)
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  /// Draws a path with a soft chalk glow underneath, then the crisp stroke on top.
  void _chalkPath(Canvas canvas, Path path, Color color, double width,
      {double opacity = 1.0}) {
    // Soft glow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.18)
        ..strokeWidth = width * 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    // Crisp stroke
    canvas.drawPath(path, _chalk(color, width, opacity: opacity));
  }

  // ── Text / formula ─────────────────────────────────────────────────────────

  void _drawText(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required bool formula}) {
    if (el.content == null || el.x == null || el.y == null) return;

    final color = formula ? const Color(0xFFEDE0FF) : Colors.white;
    final fontSize = formula ? (el.fontSize * 1.15).clamp(16.0, 28.0) : el.fontSize;

    final tp = _makeTP(
      el.content!,
      color.withValues(alpha: p),
      fontSize,
      bold: formula,
      maxWidth: size.width * 0.88,
    );

    final pos = Offset(el.x! * size.width, el.y! * size.height);

    if (formula) {
      final padH = 12.0, padV = 7.0;
      final boxRect = Rect.fromLTWH(
          pos.dx - padH, pos.dy - padV, tp.width + padH * 2, tp.height + padV * 2);

      // Purple glow behind box
      canvas.drawRRect(
        RRect.fromRectXY(boxRect.inflate(4), 12, 12),
        Paint()
          ..color = _purple.withValues(alpha: p * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Dark background pill
      canvas.drawRRect(
        RRect.fromRectXY(boxRect, 9, 9),
        Paint()..color = const Color(0xFF0E0825).withValues(alpha: p),
      );
      // Purple border
      canvas.drawRRect(
        RRect.fromRectXY(boxRect, 9, 9),
        Paint()
          ..color = _purple.withValues(alpha: p * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Chalk left-to-right reveal: clip to growing rect
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, pos.dx + tp.width * p + 4, size.height));
    tp.paint(canvas, pos);
    canvas.restore();
  }

  // ── Step marker ────────────────────────────────────────────────────────────

  void _drawStep(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.y == null) return;
    const r = 12.0;
    final center = Offset(el.x! * size.width + r, el.y! * size.height + r);

    // Glow
    canvas.drawCircle(
        center,
        r * p * 1.6,
        Paint()
          ..color = _purple.withValues(alpha: p * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawCircle(center, r * p,
        Paint()..color = _purple.withValues(alpha: p));

    if (p > 0.5 && el.content != null) {
      final tp = _makeTP(el.content!, Colors.white.withValues(alpha: (p - 0.5) * 2), 11,
          bold: true);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    if (p > 0.65 && el.label != null) {
      final ltp = _makeTP(el.label!,
          Colors.white.withValues(alpha: ((p - 0.65) / 0.35).clamp(0.0, 1.0)), 13);
      ltp.paint(canvas, Offset(center.dx + r + 7, center.dy - ltp.height / 2));
    }
  }

  // ── Line ───────────────────────────────────────────────────────────────────

  void _drawLine(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x1 == null) return;
    final start = Offset(el.x1! * size.width, el.y1! * size.height);
    final end = Offset(el.x2! * size.width, el.y2! * size.height);
    final cur = Offset.lerp(start, end, p)!;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(cur.dx, cur.dy);
    _chalkPath(canvas, path, el.color, 1.8, opacity: 0.9);
  }

  // ── Arrow / Vector ─────────────────────────────────────────────────────────

  void _drawArrow(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required bool thick}) {
    if (el.x1 == null) return;
    final start = Offset(el.x1! * size.width, el.y1! * size.height);
    final end = Offset(el.x2! * size.width, el.y2! * size.height);
    final cur = Offset.lerp(start, end, p)!;

    final sw = thick ? 3.0 : 2.0;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(cur.dx, cur.dy);
    _chalkPath(canvas, path, el.color, sw);

    if (p > 0.65) {
      final ap = ((p - 0.65) / 0.35).clamp(0.0, 1.0);
      _paintArrowhead(canvas, start, cur, el.color.withValues(alpha: ap),
          size: (thick ? 13 : 10) * ap);
    }

    if (p > 0.75 && el.label != null) {
      final labelProg = ((p - 0.75) / 0.25).clamp(0.0, 1.0);
      if (thick) {
        // Vector: label perpendicular to shaft
        final mid = Offset.lerp(start, cur, 0.5)!;
        final angle = (end - start).direction;
        final perp = Offset(-math.sin(angle) * 16, math.cos(angle) * 16);
        final tp = _makeTP(el.label!, el.color.withValues(alpha: labelProg), 13, bold: true);
        tp.paint(canvas, mid + perp - Offset(tp.width / 2, tp.height / 2));
      } else {
        final mid = Offset.lerp(start, end, 0.5)!;
        final tp = _makeTP(el.label!, el.color.withValues(alpha: labelProg), 12, bold: true);
        tp.paint(canvas, mid + const Offset(4, -18));
      }
    }
  }

  void _paintArrowhead(Canvas canvas, Offset from, Offset to, Color color,
      {double size = 10}) {
    if ((to - from).distance < 1) return;
    final angle = (to - from).direction;
    const spread = 0.45;
    final p1 = to +
        Offset(size * math.cos(angle + math.pi - spread),
            size * math.sin(angle + math.pi - spread));
    final p2 = to +
        Offset(size * math.cos(angle + math.pi + spread),
            size * math.sin(angle + math.pi + spread));
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  // ── Circle ─────────────────────────────────────────────────────────────────

  void _drawCircle(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.cx == null || el.r == null) return;
    final center = Offset(el.cx! * size.width, el.cy! * size.height);
    final radius = el.r! * math.min(size.width, size.height);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Glow
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..color = el.color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p,
      false,
      _chalk(el.color, 2.2),
    );

    if (p > 0.9 && el.label != null) {
      final labelOp = ((p - 0.9) * 10).clamp(0.0, 1.0);
      final tp = _makeTP(el.label!, el.color.withValues(alpha: labelOp), 12);
      tp.paint(canvas, center + Offset(radius + 7, -tp.height / 2));
    }
  }

  // ── Rect ───────────────────────────────────────────────────────────────────

  void _drawRect(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.w == null) return;
    final rect = Rect.fromLTWH(
      el.x! * size.width,
      el.y! * size.height,
      el.w! * size.width,
      el.h! * size.height,
    );

    final perimeter = 2 * (rect.width + rect.height);
    final drawn = perimeter * p;

    final path = Path()..moveTo(rect.left, rect.top);
    double rem = drawn;
    final segments = [
      [rect.right, rect.top],
      [rect.right, rect.bottom],
      [rect.left, rect.bottom],
      [rect.left, rect.top],
    ];
    for (final seg in segments) {
      if (rem <= 0) break;
      final to = Offset(seg[0], seg[1]);
      final last = path.getBounds();
      final from = Offset(last.right == to.dx ? last.right : last.left,
          last.bottom == to.dy ? last.bottom : last.top);
      final segLen = (to - from).distance;
      if (rem >= segLen) {
        path.lineTo(to.dx, to.dy);
        rem -= segLen;
      } else {
        final t = rem / segLen;
        path.lineTo(
            from.dx + (to.dx - from.dx) * t, from.dy + (to.dy - from.dy) * t);
        rem = 0;
      }
    }

    _chalkPath(canvas, path, el.color, 1.8);
  }

  // ── Coordinate axes ────────────────────────────────────────────────────────

  void _drawAxes(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.w == null) return;
    final ox = el.x! * size.width;
    final oy = el.y! * size.height;
    final w = el.w! * size.width;
    final h = el.h! * size.height;

    final axisColor = el.color.withValues(alpha: p * 0.85);

    // Phase 1 (p 0..0.5): draw X axis
    // Phase 2 (p 0.5..1): draw Y axis
    final xP = (p / 0.5).clamp(0.0, 1.0);
    final yP = ((p - 0.5) / 0.5).clamp(0.0, 1.0);

    final xPath = Path()
      ..moveTo(ox, oy)
      ..lineTo(ox + w * xP, oy);
    _chalkPath(canvas, xPath, axisColor, 1.8, opacity: 0.85);

    if (p > 0.5) {
      final yPath = Path()
        ..moveTo(ox, oy)
        ..lineTo(ox, oy - h * yP);
      _chalkPath(canvas, yPath, el.color, 1.8, opacity: 0.85 * yP);
    }

    if (p > 0.88) {
      final ap = ((p - 0.88) / 0.12).clamp(0.0, 1.0);
      _paintArrowhead(canvas, Offset(ox, oy), Offset(ox + w, oy),
          el.color.withValues(alpha: ap), size: 7 * ap);
      _paintArrowhead(canvas, Offset(ox, oy), Offset(ox, oy - h),
          el.color.withValues(alpha: ap), size: 7 * ap);

      // Tick marks
      const ticks = 4;
      final tickPaint = Paint()
        ..color = el.color.withValues(alpha: ap * 0.6)
        ..strokeWidth = 1.0;
      for (int i = 1; i <= ticks; i++) {
        final tx = ox + (w / ticks) * i;
        final ty = oy - (h / ticks) * i;
        canvas.drawLine(Offset(tx, oy - 3), Offset(tx, oy + 3), tickPaint);
        canvas.drawLine(Offset(ox - 3, ty), Offset(ox + 3, ty), tickPaint);
      }

      if (el.label != null) {
        final parts = el.label!.split(',');
        final labelColor = el.color.withValues(alpha: ap * 0.8);
        if (parts.isNotEmpty) {
          _makeTP(parts[0].trim(), labelColor, 11)
              .paint(canvas, Offset(ox + w + 4, oy - 6));
        }
        if (parts.length >= 2) {
          _makeTP(parts[1].trim(), labelColor, 11)
              .paint(canvas, Offset(ox + 6, oy - h - 16));
        }
      }
    }
  }

  // ── Generic curve (polyline) ───────────────────────────────────────────────

  void _drawCurve(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.points == null || el.points!.length < 2) return;

    final pts = el.points!
        .map((pt) => Offset(pt[0] * size.width, pt[1] * size.height))
        .toList();

    final totalPts = pts.length;
    final drawn = ((totalPts - 1) * p).clamp(0.0, totalPts - 1.0);
    final full = drawn.floor();
    final frac = drawn - full;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i <= full && i < totalPts; i++) {
      if (i + 1 < totalPts) {
        // Smooth cubic: midpoint between segments
        final mid = Offset(
            (pts[i].dx + pts[i - 1].dx) / 2,
            (pts[i].dy + pts[i - 1].dy) / 2);
        path.quadraticBezierTo(
            pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }

    // Partial last segment
    if (full < totalPts - 1 && frac > 0) {
      final from = pts[full];
      final to = pts[full + 1];
      path.lineTo(
          from.dx + (to.dx - from.dx) * frac,
          from.dy + (to.dy - from.dy) * frac);
    }

    _chalkPath(canvas, path, el.color, 2.2);

    if (p > 0.9 && el.label != null) {
      final tip = full < totalPts ? pts[full] : pts.last;
      final tp =
          _makeTP(el.label!, el.color.withValues(alpha: (p - 0.9) * 10), 12, bold: true);
      tp.paint(canvas, tip + const Offset(6, -18));
    }
  }

  // ── Parabola ───────────────────────────────────────────────────────────────

  void _drawParabola(Canvas canvas, Size size, WhiteboardElement el, double p) {
    // Vertex at (cx, cy), coefficient 'a', x range [x1..x2]
    final cx = (el.cx ?? 0.5) * size.width;
    final cy = (el.cy ?? 0.5) * size.height;
    final xStart = (el.x1 ?? 0.05) * size.width;
    final xEnd = (el.x2 ?? 0.95) * size.width;
    final aScaled = (el.a ?? 2.0) * size.height; // curvature in pixels

    final xCur = xStart + (xEnd - xStart) * p;

    const steps = 80;
    final path = Path();
    bool first = true;
    for (int i = 0; i <= steps; i++) {
      final x = xStart + (xCur - xStart) * i / steps;
      if (x > xCur + 1) break;
      final dx = (x - cx) / size.width; // normalized offset from vertex
      final y = cy + aScaled * dx * dx;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    _chalkPath(canvas, path, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final labelX = xCur + 5;
      final dx = (xCur - cx) / size.width;
      final labelY = cy + aScaled * dx * dx - 16;
      final tp =
          _makeTP(el.label!, el.color.withValues(alpha: (p - 0.92) * 12.5), 12, bold: true);
      tp.paint(canvas, Offset(labelX, labelY.clamp(4.0, size.height - 20)));
    }
  }

  // ── Sine / cosine wave ─────────────────────────────────────────────────────

  void _drawSine(Canvas canvas, Size size, WhiteboardElement el, double p) {
    final x1 = (el.x1 ?? 0.05) * size.width;
    final x2 = (el.x2 ?? 0.95) * size.width;
    final cy = (el.y ?? 0.5) * size.height;
    final amplitude = (el.amplitude ?? 0.15) * size.height;
    final frequency = el.frequency ?? 2.0;
    final phase = el.phase ?? 0.0;

    final xCur = x1 + (x2 - x1) * p;
    const steps = 120;

    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final x = x1 + (xCur - x1) * i / steps;
      if (x > xCur + 1) break;
      final t = (x - x1) / (x2 - x1);
      final y = cy - amplitude * math.sin(t * frequency * 2 * math.pi + phase);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    _chalkPath(canvas, path, el.color, 2.2);

    if (p > 0.9 && el.label != null) {
      final endT = (xCur - x1) / (x2 - x1);
      final endY = cy - amplitude * math.sin(endT * frequency * 2 * math.pi + phase);
      final tp =
          _makeTP(el.label!, el.color.withValues(alpha: (p - 0.9) * 10), 12, bold: true);
      tp.paint(canvas, Offset(xCur + 5, endY - 12));
    }
  }

  // ── Triangle ───────────────────────────────────────────────────────────────

  void _drawTriangle(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.points == null || el.points!.length < 3) return;

    final verts = el.points!
        .map((pt) => Offset(pt[0] * size.width, pt[1] * size.height))
        .toList();

    final sides = [
      [verts[0], verts[1]],
      [verts[1], verts[2]],
      [verts[2], verts[0]],
    ];

    final segLens = sides.map((s) => (s[1] - s[0]).distance).toList();
    final perimeter = segLens.reduce((a, b) => a + b);
    final drawn = perimeter * p;

    final path = Path()..moveTo(verts[0].dx, verts[0].dy);
    double rem = drawn;
    for (int i = 0; i < 3; i++) {
      if (rem <= 0) break;
      final from = sides[i][0];
      final to = sides[i][1];
      final len = segLens[i];
      if (rem >= len) {
        path.lineTo(to.dx, to.dy);
        rem -= len;
      } else {
        final t = rem / len;
        path.lineTo(
            from.dx + (to.dx - from.dx) * t,
            from.dy + (to.dy - from.dy) * t);
        rem = 0;
      }
    }

    _chalkPath(canvas, path, el.color, 2.0, opacity: 0.9);

    // Fill with very transparent color
    if (p > 0.95) {
      final fillProg = ((p - 0.95) / 0.05).clamp(0.0, 1.0);
      final fillPath = Path()
        ..moveTo(verts[0].dx, verts[0].dy)
        ..lineTo(verts[1].dx, verts[1].dy)
        ..lineTo(verts[2].dx, verts[2].dy)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = el.color.withValues(alpha: fillProg * 0.08)
          ..style = PaintingStyle.fill,
      );
    }

    if (p > 0.88 && el.label != null) {
      final labels = el.label!.split(',');
      const labelOffsets = [
        Offset(-10, -20),
        Offset(10, 4),
        Offset(-12, 4),
      ];
      for (int i = 0; i < math.min(labels.length, 3); i++) {
        final lp = ((p - 0.88) / 0.12).clamp(0.0, 1.0);
        final tp =
            _makeTP(labels[i].trim(), el.color.withValues(alpha: lp), 12, bold: true);
        tp.paint(canvas, verts[i] + labelOffsets[i]);
      }
    }
  }

  // ── Point ──────────────────────────────────────────────────────────────────

  void _drawPoint(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null) return;
    final center = Offset(el.x! * size.width, el.y! * size.height);

    // Outer glow
    canvas.drawCircle(
        center,
        8 * p,
        Paint()
          ..color = el.color.withValues(alpha: p * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawCircle(center, 4.5 * p, Paint()..color = el.color.withValues(alpha: p));

    canvas.drawCircle(
      center,
      4.5 * p,
      Paint()
        ..color = el.color.withValues(alpha: p * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (p > 0.55 && el.label != null) {
      final lp = ((p - 0.55) / 0.45).clamp(0.0, 1.0);
      final tp = _makeTP(el.label!, el.color.withValues(alpha: lp), 11);
      tp.paint(canvas, center + const Offset(8, -14));
    }
  }

  // ── TextPainter helper ─────────────────────────────────────────────────────

  TextPainter _makeTP(
    String text,
    Color color,
    double fontSize, {
    bool bold = false,
    double maxWidth = double.infinity,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.35,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }
}
