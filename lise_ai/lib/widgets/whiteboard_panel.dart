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
      color: const Color(0xFF070714),
      child: Column(
        children: [
          _Header(title: data?.title ?? 'Tahta', onClose: onClose, onReplay: onReplay, state: state),
          Expanded(
            child: switch (state) {
              WhiteboardState.loading => const _LoadingView(),
              WhiteboardState.ready => _WhiteboardCanvas(data: data!),
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
        color: Color(0xFF0D0D20),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A3A))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A3A),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF7C6BF8), size: 16),
          ),
          const SizedBox(width: 8),
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
          if (state == WhiteboardState.ready)
            GestureDetector(
              onTap: onReplay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A3A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_rounded, color: Color(0xFF7C6BF8), size: 13),
                    SizedBox(width: 4),
                    Text('Tekrar', style: TextStyle(color: Color(0xFF7C6BF8), fontSize: 11)),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded, color: Color(0xFF4B5563), size: 18),
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

class _LoadingViewState extends State<_LoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
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
              size: const Size(64, 64),
              painter: _SpinnerPainter(_ctrl.value),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tahta hazırlanıyor…',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Claude adım adım çiziyor',
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
    const r = 26.0;

    // Background ring
    canvas.drawCircle(center, r, Paint()
      ..color = const Color(0xFF1A1A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);

    // Animated arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      t * 2 * math.pi - math.pi / 2,
      math.pi * 1.2,
      false,
      Paint()
        ..color = const Color(0xFF7C6BF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Center icon
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF1A1A3A));
    final icon = TextPainter(
      text: const TextSpan(
        text: '✦',
        style: TextStyle(color: Color(0xFF7C6BF8), fontSize: 12),
      ),
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
    final duration = widget.data.totalDuration;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (duration * 1000).round().clamp(1000, 30000)),
    )..forward();
    _time = Tween<double>(begin: 0, end: duration)
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

  void replay() {
    _ctrl.reset();
    _ctrl.forward();
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

  static const _accentPurple = Color(0xFF7C6BF8);

  const _WhiteboardPainter({required this.elements, required this.time});

  @override
  bool shouldRepaint(_WhiteboardPainter old) => old.time != time;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF070714),
    );

    // Subtle dot grid
    _paintGrid(canvas, size);

    // Elements
    for (final el in elements) {
      if (time < el.delay) continue;
      final drawDuration = el.type == WBType.text || el.type == WBType.formula ||
              el.type == WBType.step
          ? 0.35
          : 0.55;
      final progress = ((time - el.delay) / drawDuration).clamp(0.0, 1.0);
      _drawElement(canvas, size, el, progress);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F0F28)
      ..strokeWidth = 0.5;
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

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
        _drawArrow(canvas, size, el, p);
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
    }
  }

  // ── Text / formula ──────────────────────────────────────────────────────────

  void _drawText(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required bool formula}) {
    if (el.content == null || el.x == null || el.y == null) return;

    final color = formula ? const Color(0xFFE9D5FF) : Colors.white;
    final fontSize = formula ? (el.fontSize * 1.15) : el.fontSize;

    if (formula) {
      // Subtle pill background
      final tp = _makeTP(el.content!, color.withOpacity(0), fontSize, bold: true);
      final pos = Offset(el.x! * size.width, el.y! * size.height);
      final bg = RRect.fromRectXY(
        Rect.fromLTWH(pos.dx - 8, pos.dy - 4, tp.width + 16, tp.height + 8),
        6, 6,
      );
      canvas.drawRRect(bg, Paint()..color = const Color(0xFF1A0F3A).withOpacity(p));
    }

    final tp = _makeTP(el.content!, color.withOpacity(p), fontSize,
        bold: formula, maxWidth: size.width * 0.85);
    tp.paint(canvas, Offset(el.x! * size.width, el.y! * size.height));
  }

  // ── Step marker (numbered circle) ───────────────────────────────────────────

  void _drawStep(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.y == null) return;
    const r = 11.0;
    final center = Offset(el.x! * size.width + r, el.y! * size.height + r);

    canvas.drawCircle(
      center, r * p,
      Paint()..color = _accentPurple.withOpacity(p),
    );

    if (p > 0.5 && el.content != null) {
      final tp = _makeTP(el.content!, Colors.white.withOpacity((p - 0.5) * 2), 11, bold: true);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    // Label to the right
    if (p > 0.7 && el.label != null) {
      final ltp = _makeTP(el.label!, Colors.white.withOpacity((p - 0.7) * 3.3), 13);
      ltp.paint(canvas, Offset(center.dx + r + 6, center.dy - ltp.height / 2));
    }
  }

  // ── Line ────────────────────────────────────────────────────────────────────

  void _drawLine(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x1 == null) return;
    final start = Offset(el.x1! * size.width, el.y1! * size.height);
    final end = Offset(el.x2! * size.width, el.y2! * size.height);
    final current = Offset.lerp(start, end, p)!;

    canvas.drawLine(
      start, current,
      Paint()
        ..color = el.color.withOpacity(0.85)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Arrow ───────────────────────────────────────────────────────────────────

  void _drawArrow(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x1 == null) return;
    final start = Offset(el.x1! * size.width, el.y1! * size.height);
    final end = Offset(el.x2! * size.width, el.y2! * size.height);
    final current = Offset.lerp(start, end, p)!;

    final paint = Paint()
      ..color = el.color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, current, paint);

    // Arrowhead appears in last 30%
    if (p > 0.7) {
      final ap = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
      _paintArrowhead(canvas, start, current, el.color, size: 10 * ap);
    }

    // Label near midpoint
    if (p > 0.8 && el.label != null) {
      final mid = Offset.lerp(start, end, 0.5)!;
      final tp = _makeTP(el.label!, el.color.withOpacity((p - 0.8) * 5), 12, bold: true);
      tp.paint(canvas, mid + const Offset(4, -16));
    }
  }

  void _paintArrowhead(Canvas canvas, Offset from, Offset to, Color color, {double size = 10}) {
    if ((to - from).distance < 1) return;
    final angle = (to - from).direction;
    const spread = 0.5;
    final p1 = to + Offset(size * math.cos(angle + math.pi - spread), size * math.sin(angle + math.pi - spread));
    final p2 = to + Offset(size * math.cos(angle + math.pi + spread), size * math.sin(angle + math.pi + spread));
    canvas.drawPath(
      Path()..moveTo(to.dx, to.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  // ── Circle ──────────────────────────────────────────────────────────────────

  void _drawCircle(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.cx == null || el.r == null) return;
    final center = Offset(el.cx! * size.width, el.cy! * size.height);
    final radius = el.r! * math.min(size.width, size.height);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..color = el.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    if (p > 0.9 && el.label != null) {
      final tp = _makeTP(el.label!, el.color.withOpacity((p - 0.9) * 10), 12);
      tp.paint(canvas, center + Offset(radius + 6, -tp.height / 2));
    }
  }

  // ── Rect ────────────────────────────────────────────────────────────────────

  void _drawRect(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.w == null) return;
    final rect = Rect.fromLTWH(
      el.x! * size.width,
      el.y! * size.height,
      el.w! * size.width,
      el.h! * size.height,
    );
    // Draw perimeter progressively
    final perimeter = 2 * (rect.width + rect.height);
    final drawn = perimeter * p;
    final path = Path();
    if (drawn <= rect.width) {
      path.moveTo(rect.left, rect.top);
      path.lineTo(rect.left + drawn, rect.top);
    } else if (drawn <= rect.width + rect.height) {
      path.moveTo(rect.left, rect.top);
      path.lineTo(rect.right, rect.top);
      path.lineTo(rect.right, rect.top + (drawn - rect.width));
    } else if (drawn <= 2 * rect.width + rect.height) {
      path.moveTo(rect.left, rect.top);
      path.lineTo(rect.right, rect.top);
      path.lineTo(rect.right, rect.bottom);
      path.lineTo(rect.right - (drawn - rect.width - rect.height), rect.bottom);
    } else {
      path.moveTo(rect.left, rect.top);
      path.lineTo(rect.right, rect.top);
      path.lineTo(rect.right, rect.bottom);
      path.lineTo(rect.left, rect.bottom);
      path.lineTo(rect.left, rect.bottom - (drawn - 2 * rect.width - rect.height));
    }
    canvas.drawPath(path, Paint()..color = el.color..strokeWidth = 1.8..style = PaintingStyle.stroke);
  }

  // ── Coordinate axes ─────────────────────────────────────────────────────────

  void _drawAxes(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.w == null) return;
    final ox = el.x! * size.width;
    final oy = el.y! * size.height;
    final w = el.w! * size.width;
    final h = el.h! * size.height;

    final axisPaint = Paint()
      ..color = const Color(0xFF6B7280).withOpacity(p)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // X axis (draw progressively)
    canvas.drawLine(Offset(ox, oy), Offset(ox + w * p, oy), axisPaint);
    // Y axis
    canvas.drawLine(Offset(ox, oy), Offset(ox, oy - h * p), axisPaint);

    if (p > 0.9) {
      final ap = ((p - 0.9) / 0.1).clamp(0.0, 1.0);
      final arrowPaint = Paint()..color = const Color(0xFF6B7280).withOpacity(ap);
      _paintArrowhead(canvas, Offset(ox, oy), Offset(ox + w, oy), arrowPaint.color, size: 7 * ap);
      _paintArrowhead(canvas, Offset(ox, oy), Offset(ox, oy - h), arrowPaint.color, size: 7 * ap);

      // Tick marks
      final ticks = 4;
      for (int i = 1; i <= ticks; i++) {
        final tx = ox + (w / ticks) * i;
        final ty = oy - (h / ticks) * i;
        canvas.drawLine(Offset(tx, oy - 3), Offset(tx, oy + 3), axisPaint);
        canvas.drawLine(Offset(ox - 3, ty), Offset(ox + 3, ty), axisPaint);
      }

      // Axis labels
      if (el.label != null) {
        final parts = el.label!.split(',');
        if (parts.length >= 2) {
          _makeTP(parts[0].trim(), const Color(0xFF9CA3AF).withOpacity(ap), 11)
              .paint(canvas, Offset(ox + w - 4, oy + 6));
          _makeTP(parts[1].trim(), const Color(0xFF9CA3AF).withOpacity(ap), 11)
              .paint(canvas, Offset(ox + 6, oy - h - 4));
        }
      }
    }
  }

  // ── Curve / function plot ───────────────────────────────────────────────────

  void _drawCurve(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.points == null || el.points!.length < 2) return;

    final pts = el.points!
        .map((pt) => Offset(pt[0] * size.width, pt[1] * size.height))
        .toList();

    final count = ((pts.length - 1) * p).round().clamp(1, pts.length - 1);

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i <= count; i++) {
      if (i < pts.length) path.lineTo(pts[i].dx, pts[i].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = el.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Curve label near last drawn point
    if (p > 0.85 && el.label != null && count < pts.length) {
      final tip = pts[count];
      final tp = _makeTP(el.label!, el.color.withOpacity((p - 0.85) * 6.7), 12, bold: true);
      tp.paint(canvas, tip + const Offset(6, -16));
    }
  }

  // ── Point ───────────────────────────────────────────────────────────────────

  void _drawPoint(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null) return;
    final center = Offset(el.x! * size.width, el.y! * size.height);

    canvas.drawCircle(center, 4 * p, Paint()..color = el.color.withOpacity(p));
    canvas.drawCircle(center, 4 * p, Paint()
      ..color = el.color.withOpacity(p * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    if (p > 0.6 && el.label != null) {
      final tp = _makeTP(el.label!, el.color.withOpacity((p - 0.6) * 2.5), 11);
      tp.paint(canvas, center + const Offset(7, -14));
    }
  }

  // ── TextPainter helper ──────────────────────────────────────────────────────

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
