import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/ui_state_engine.dart';

// ── OrbRenderer ───────────────────────────────────────────────────────────────
//
// Reusable orb widget. All animation values are passed in — no internal state.
// breathe: 0-1 slow pulse
// wave:    0-1 fast cycle (for speaking/solving waves)
// flash:   0-1 interrupt flash (decays quickly)
// amp:     0-1 speech amplitude (reactive glow expansion)

class OrbRenderer extends StatelessWidget {
  final OrbVisualState state;
  final Color orbColor;
  final double breathe;
  final double wave;
  final double flash;
  final double amp;
  final double size;

  const OrbRenderer({
    super.key,
    required this.state,
    required this.orbColor,
    required this.breathe,
    required this.wave,
    required this.flash,
    required this.amp,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _OrbPainter(
          state: state,
          orbColor: orbColor,
          breathe: breathe,
          wave: wave,
          flash: flash,
          amp: amp,
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _OrbPainter extends CustomPainter {
  final OrbVisualState state;
  final Color orbColor;
  final double breathe;
  final double wave;
  final double flash;
  final double amp;

  const _OrbPainter({
    required this.state,
    required this.orbColor,
    required this.breathe,
    required this.wave,
    required this.flash,
    required this.amp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    _drawOuterRings(canvas, c, maxR);
    _drawAmplitudeHalo(canvas, c, maxR);
    _drawHalo(canvas, c, maxR);
    _drawInterruptFlash(canvas, c, maxR);
    _drawCore(canvas, c, maxR);
    _drawHighlight(canvas, c, maxR);
    _drawSurfaceDetail(canvas, c, maxR);
    _drawInnerIcon(canvas, c, maxR);
  }

  // ── Outer animated rings ──────────────────────────────────────────────────

  void _drawOuterRings(Canvas canvas, Offset c, double maxR) {
    switch (state) {
      case OrbVisualState.listening:
        // Expanding blue concentric rings
        for (int i = 4; i >= 1; i--) {
          final expand = breathe;
          final r = maxR * (0.9 + i * 0.13 * expand);
          final opacity = 0.035 * (5 - i) * expand;
          _drawRing(canvas, c, r, orbColor.withValues(alpha: opacity));
        }

      case OrbVisualState.speaking:
        // Rapid wave rings (sound emission)
        for (int i = 5; i >= 1; i--) {
          final phase = (wave + i * 0.17) % 1.0;
          final expand = math.sin(phase * 2 * math.pi).abs();
          final r = maxR * (0.85 + i * 0.11 * expand);
          final opacity = 0.025 * (6 - i) * expand;
          _drawRing(canvas, c, r, orbColor.withValues(alpha: opacity));
        }

      case OrbVisualState.teaching:
        // Warm slow bloom
        for (int i = 3; i >= 1; i--) {
          final r = maxR * (0.88 + i * 0.09 * (0.6 + 0.4 * breathe));
          final opacity = 0.04 * (4 - i) * breathe;
          _drawRing(canvas, c, r, orbColor.withValues(alpha: opacity));
        }

      case OrbVisualState.solving:
        // Rotating segmented ring (geometric feel)
        for (int i = 3; i >= 0; i--) {
          final angle = wave * 2 * math.pi + i * math.pi / 2;
          final r = maxR * (0.90 + i * 0.06);
          final offset = c + Offset(math.cos(angle) * r * 0.05, math.sin(angle) * r * 0.05);
          final opacity = 0.05 * breathe;
          _drawRing(canvas, offset, r * 0.92, orbColor.withValues(alpha: opacity), width: 2);
        }

      case OrbVisualState.thinking:
        // Gentle slow expansion
        for (int i = 2; i >= 1; i--) {
          final r = maxR * (0.85 + i * 0.07 * (0.4 + 0.6 * breathe));
          final opacity = 0.05 * breathe;
          _drawRing(canvas, c, r, orbColor.withValues(alpha: opacity));
        }

      default:
        break;
    }
  }

  // ── Amplitude-reactive halo ───────────────────────────────────────────────

  void _drawAmplitudeHalo(Canvas canvas, Offset c, double maxR) {
    if (amp <= 0.02) return;
    final r = maxR * (1.0 + amp * 0.4);
    final opacity = amp * 0.25;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        orbColor.withValues(alpha: opacity),
        orbColor.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  // ── Soft halo ─────────────────────────────────────────────────────────────

  void _drawHalo(Canvas canvas, Offset c, double maxR) {
    final haloOpacity = switch (state) {
      OrbVisualState.idle  => 0.08 + 0.04 * breathe,
      OrbVisualState.paused => 0.04,
      _ => 0.14 + 0.08 * breathe,
    };
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        orbColor.withValues(alpha: haloOpacity),
        orbColor.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: c, radius: maxR * 1.15));
    canvas.drawCircle(c, maxR * 1.15, paint);
  }

  // ── Interrupt flash ───────────────────────────────────────────────────────

  void _drawInterruptFlash(Canvas canvas, Offset c, double maxR) {
    if (flash <= 0.01) return;
    final opacity = flash * math.sin(flash * math.pi) * 0.35;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFF87171).withValues(alpha: opacity),
        const Color(0xFFF87171).withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: c, radius: maxR * 1.3));
    canvas.drawCircle(c, maxR * 1.3, paint);
  }

  // ── Core orb ─────────────────────────────────────────────────────────────

  void _drawCore(Canvas canvas, Offset c, double maxR) {
    final breathScale = state == OrbVisualState.idle ? 0.07 : 0.05;
    final innerR = maxR * (0.66 + breathScale * breathe);

    final dark = _darken(orbColor, 0.65);
    final mid = _darken(orbColor, 0.25);

    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 1.1,
        colors: [
          dark,
          mid,
          orbColor.withValues(alpha: 0.80),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: innerR));
    canvas.drawCircle(c, innerR, paint);
  }

  // ── Specular highlight ────────────────────────────────────────────────────

  void _drawHighlight(Canvas canvas, Offset c, double maxR) {
    final innerR = maxR * (0.66 + 0.05 * breathe);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.45),
        radius: 0.50,
        colors: [
          Colors.white.withValues(alpha: 0.24),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: innerR));
    canvas.drawCircle(c, innerR, paint);
  }

  // ── Surface detail: waves / arcs ──────────────────────────────────────────

  void _drawSurfaceDetail(Canvas canvas, Offset c, double maxR) {
    final innerR = maxR * 0.68;

    if (state == OrbVisualState.speaking) {
      // Amplitude bars
      for (int i = 0; i < 7; i++) {
        final phase = (wave + i / 7.0) % 1.0;
        final h = innerR * 0.38 * math.sin(phase * 2 * math.pi).abs() + 3;
        final x = c.dx - innerR * 0.52 + i * (innerR * 1.04 / 6);
        final barRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, c.dy), width: 2.5, height: h),
          const Radius.circular(2),
        );
        canvas.drawRRect(barRect,
            Paint()..color = Colors.white.withValues(alpha: 0.45));
      }
    }

    if (state == OrbVisualState.solving) {
      // Rotating geometric overlay (faint hexagonal arc)
      final paint = Paint()
        ..color = orbColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (int i = 0; i < 6; i++) {
        final a1 = wave * 2 * math.pi + i * math.pi / 3;
        final a2 = a1 + math.pi / 3;
        final p = Path();
        p.moveTo(c.dx + innerR * 0.5 * math.cos(a1),
                 c.dy + innerR * 0.5 * math.sin(a1));
        p.lineTo(c.dx + innerR * 0.5 * math.cos(a2),
                 c.dy + innerR * 0.5 * math.sin(a2));
        canvas.drawPath(p, paint);
      }
    }

    if (state == OrbVisualState.teaching) {
      // Slow rotating halo arc (wisdom ring)
      final paint = Paint()
        ..color = orbColor.withValues(alpha: 0.18 * breathe)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: innerR * 0.80),
        wave * 2 * math.pi,
        math.pi * 1.4,
        false,
        paint,
      );
    }
  }

  // ── Center icon / dots ────────────────────────────────────────────────────

  void _drawInnerIcon(Canvas canvas, Offset c, double maxR) {
    switch (state) {
      case OrbVisualState.thinking:
        // Three rotating dots
        for (int i = 0; i < 3; i++) {
          final angle = wave * 2 * math.pi + i * 2 * math.pi / 3;
          final r = maxR * 0.20;
          final pos = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
          canvas.drawCircle(pos, 3.5,
              Paint()..color = Colors.white.withValues(alpha: 0.55));
        }

      case OrbVisualState.paused:
        // Pause bars
        final p = Paint()..color = Colors.white.withValues(alpha: 0.45);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c - const Offset(6, 0), width: 4, height: 14),
              const Radius.circular(2)),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c + const Offset(6, 0), width: 4, height: 14),
              const Radius.circular(2)),
          p,
        );

      case OrbVisualState.interrupted:
        // X mark
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        const d = 8.0;
        canvas.drawLine(c - Offset(d, d), c + Offset(d, d), p);
        canvas.drawLine(c - Offset(-d, d), c + Offset(-d, -d), p);

      default:
        break;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _drawRing(Canvas canvas, Offset c, double r, Color color,
      {double width = 0}) {
    final paint = Paint()..color = color;
    if (width > 0) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = width;
    }
    canvas.drawCircle(c, r, paint);
  }

  Color _darken(Color c, double amount) => Color.fromARGB(
        c.alpha,
        (c.red * (1 - amount)).round().clamp(0, 255),
        (c.green * (1 - amount)).round().clamp(0, 255),
        (c.blue * (1 - amount)).round().clamp(0, 255),
      );

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.state != state ||
      old.orbColor != orbColor ||
      old.breathe != breathe ||
      old.wave != wave ||
      old.flash != flash ||
      old.amp != amp;
}

