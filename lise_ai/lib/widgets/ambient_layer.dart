import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/ui_state_engine.dart';

// ── AmbientLayer ─────────────────────────────────────────────────────────────
//
// Full-screen animated background: gradient + floating particles.
// Driven by a single AnimationController (ticks at display rate).
// Gradient animates via TweenAnimationBuilder when mode/motivation changes.

class AmbientLayer extends StatefulWidget {
  final UIStateEngine uiEngine;
  final AnimationController particleCtrl;

  const AmbientLayer({
    super.key,
    required this.uiEngine,
    required this.particleCtrl,
  });

  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends State<AmbientLayer> {
  late final _ParticleSystem _particles;
  List<int> _prevGradient = [];

  @override
  void initState() {
    super.initState();
    _particles = _ParticleSystem(
      count: widget.uiEngine.particleCount,
      color: Color(widget.uiEngine.orbColorInt),
    );
    _prevGradient = widget.uiEngine.gradientInts;
  }

  @override
  void didUpdateWidget(AmbientLayer old) {
    super.didUpdateWidget(old);
    final newG = widget.uiEngine.gradientInts;
    if (newG != _prevGradient) {
      _prevGradient = newG;
    }
    // Update particle color when mode changes
    _particles.setColor(Color(widget.uiEngine.orbColorInt));
    _particles.targetCount = widget.uiEngine.particleCount;
  }

  @override
  Widget build(BuildContext context) {
    final gradInts = widget.uiEngine.gradientInts;
    final g0 = Color(gradInts[0]);
    final g1 = Color(gradInts[1]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [g0, g1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: widget.particleCtrl,
          builder: (_, __) {
            _particles.update(
              widget.particleCtrl.value,
              widget.uiEngine.animSpeed,
              widget.uiEngine.speechAmplitude,
            );
            return CustomPaint(
              painter: _ParticlePainter(_particles),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

// ── Particle ──────────────────────────────────────────────────────────────────

class _Particle {
  double x; // 0-1
  double y; // 0-1
  double radius;
  double speed;
  double phase;
  double opacity;

  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = 1.5 + rng.nextDouble() * 2.0,
        speed = 0.0008 + rng.nextDouble() * 0.0014,
        phase = rng.nextDouble() * 2 * math.pi,
        opacity = 0.15 + rng.nextDouble() * 0.25;
}

// ── Particle system ───────────────────────────────────────────────────────────

class _ParticleSystem {
  final _rng = math.Random();
  final List<_Particle> _particles = [];
  Color _color;
  int targetCount;
  double _lastT = 0;

  _ParticleSystem({required int count, required Color color})
      : _color = color,
        targetCount = count {
    for (int i = 0; i < count; i++) {
      _particles.add(_Particle(_rng));
    }
  }

  void setColor(Color c) => _color = c;

  Color get color => _color;

  void update(double t, double speed, double amp) {
    final dt = (t - _lastT).abs();
    _lastT = t;

    // Gradually add/remove particles to reach targetCount
    if (_particles.length < targetCount && _rng.nextDouble() < 0.02) {
      _particles.add(_Particle(_rng));
    } else if (_particles.length > targetCount && _rng.nextDouble() < 0.02) {
      _particles.removeAt(0);
    }

    for (final p in _particles) {
      // Drift upward
      p.y -= p.speed * dt * 60 * speed * (1 + amp * 2.5);
      // Horizontal drift (sine wave)
      p.x += math.sin(p.y * 8 + p.phase + t * 4) * 0.0004 * speed;

      // Wrap
      if (p.y < -0.05) {
        p.y = 1.05;
        p.x = _rng.nextDouble();
      }
      p.x = p.x.clamp(0.0, 1.0);
    }
  }

  List<_Particle> get particles => _particles;
}

// ── Particle painter ──────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final _ParticleSystem system;

  const _ParticlePainter(this.system);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in system.particles) {
      final pos = Offset(p.x * size.width, p.y * size.height);

      // Outer soft glow
      canvas.drawCircle(
        pos,
        p.radius * 3.5,
        Paint()
          ..color = system.color.withValues(alpha: p.opacity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Core dot
      canvas.drawCircle(
        pos,
        p.radius,
        Paint()..color = system.color.withValues(alpha: p.opacity * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true; // always repaint on tick
}
