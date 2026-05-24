import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/ambient_engine.dart';

// ── AtmosphereLayer ───────────────────────────────────────────────────────────
//
// Sits above AmbientLayer. Adds:
//   - Mode-driven radial glow (extremely subtle, opacity ≤ 0.18)
//   - Transient success pulse (green bloom)
//   - Transient urgency pulse (red bloom for exam mode)
//   - Focus mode vignette (soft dark edges when focus mode active)
//
// All effects are meant to be felt, not seen. No flashy aesthetics.

class AtmosphereLayer extends StatelessWidget {
  final AmbientEngine engine;
  final AnimationController breatheCtrl;
  final bool focusMode; // dims edges when true

  const AtmosphereLayer({
    super.key,
    required this.engine,
    required this.breatheCtrl,
    this.focusMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breatheCtrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _AtmospherePainter(
            config: engine.config,
            breathe: breatheCtrl.value,
            focusMode: focusMode,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final AtmosphereConfig config;
  final double breathe; // 0–1 from breatheCtrl
  final bool focusMode;

  const _AtmospherePainter({
    required this.config,
    required this.breathe,
    required this.focusMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final base = size.shortestSide;

    // ── 1. Center radial glow ────────────────────────────────────────────────
    final glowRadius = base * config.glowRadius * (0.94 + 0.06 * breathe);
    final glowOpacity = config.glowOpacity * (0.88 + 0.12 * breathe);

    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        glowRadius,
        [
          config.glowColor.withValues(alpha: glowOpacity),
          config.glowColor.withValues(alpha: 0),
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(center, glowRadius, glowPaint);

    // ── 2. Success pulse (green) ─────────────────────────────────────────────
    if (config.successPulse > 0.01) {
      final sp = config.successPulse;
      final successPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          base * 0.7,
          [
            const Color(0xFF4ADE80).withValues(alpha: sp * 0.14),
            const Color(0xFF4ADE80).withValues(alpha: 0),
          ],
        );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        successPaint,
      );
    }

    // ── 3. Urgency pulse (red) ───────────────────────────────────────────────
    if (config.urgencyPulse > 0.01) {
      final up = config.urgencyPulse * (0.85 + 0.15 * breathe);
      // Corners glow red for exam urgency
      for (final corner in [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ]) {
        final urgencyPaint = Paint()
          ..shader = ui.Gradient.radial(
            corner,
            base * 0.55,
            [
              const Color(0xFFF87171).withValues(alpha: up * 0.12),
              const Color(0xFFF87171).withValues(alpha: 0),
            ],
          );
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          urgencyPaint,
        );
      }
    }

    // ── 4. Focus mode vignette ───────────────────────────────────────────────
    if (focusMode) {
      // Soft dark vignette around edges — makes center feel more immersive
      final vignette = Paint()
        ..shader = ui.Gradient.radial(
          center,
          base * 0.72,
          [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
          [0.5, 1.0],
        );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        vignette,
      );
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.config != config ||
      old.breathe != breathe ||
      old.focusMode != focusMode;
}

// ── AtmosphereModeBadge ───────────────────────────────────────────────────────
//
// Tiny indicator in top-right corner showing current atmosphere mode.
// Tappable to cycle modes.

class AtmosphereModeBadge extends StatelessWidget {
  final AtmosphereMode mode;
  final VoidCallback onTap;

  const AtmosphereModeBadge({
    super.key,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForMode(mode);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: mode.label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForMode(mode), color: color, size: 9),
              const SizedBox(width: 4),
              Text(
                mode.label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForMode(AtmosphereMode m) => switch (m) {
        AtmosphereMode.focusRoom => const Color(0xFF7C6BF8),
        AtmosphereMode.classroom => const Color(0xFF93C5FD),
        AtmosphereMode.examMode  => const Color(0xFFF87171),
        AtmosphereMode.lateNight => const Color(0xFF60A5FA),
        AtmosphereMode.energetic => const Color(0xFFFBBF24),
        AtmosphereMode.silent    => const Color(0xFF4B5563),
      };

  IconData _iconForMode(AtmosphereMode m) => switch (m) {
        AtmosphereMode.focusRoom => Icons.center_focus_strong_rounded,
        AtmosphereMode.classroom => Icons.school_rounded,
        AtmosphereMode.examMode  => Icons.timer_rounded,
        AtmosphereMode.lateNight => Icons.nights_stay_rounded,
        AtmosphereMode.energetic => Icons.bolt_rounded,
        AtmosphereMode.silent    => Icons.do_not_disturb_on_rounded,
      };
}

// ── AtmospherePicker ──────────────────────────────────────────────────────────

class AtmospherePicker extends StatelessWidget {
  final AtmosphereMode current;
  final ValueChanged<AtmosphereMode> onSelected;

  const AtmospherePicker({
    super.key,
    required this.current,
    required this.onSelected,
  });

  static Future<AtmosphereMode?> show(
    BuildContext context, {
    required AtmosphereMode current,
  }) {
    return showModalBottomSheet<AtmosphereMode>(
      context: context,
      backgroundColor: const Color(0xFF0C0C18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AtmospherePicker(
        current: current,
        onSelected: (m) => Navigator.pop(context, m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ortam Modu',
              style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AtmosphereMode.values.map((m) {
              final isSelected = m == current;
              return GestureDetector(
                onTap: () => onSelected(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF7C6BF8).withValues(alpha: 0.14)
                        : const Color(0xFF111122),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF7C6BF8).withValues(alpha: 0.45)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  child: Text(
                    m.label,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF9B8BFB) : const Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
