import 'package:flutter/material.dart';

import '../models/teacher_identity.dart';
import '../services/streaming_teacher_session.dart';

// ── AtmosphereMode ────────────────────────────────────────────────────────────

enum AtmosphereMode {
  focusRoom,   // dark, still — deep concentration
  classroom,   // warm, soft presence — normal teaching
  examMode,    // tense, urgent — exam drills
  lateNight,   // cool blue, calm — quiet study
  energetic,   // warm amber, alive — motivational
  silent,      // near-zero motion — pure focus
}

extension AtmosphereModeExt on AtmosphereMode {
  String get label => switch (this) {
        AtmosphereMode.focusRoom => 'Odak Odası',
        AtmosphereMode.classroom => 'Sınıf',
        AtmosphereMode.examMode  => 'Sınav',
        AtmosphereMode.lateNight => 'Gece Çalışması',
        AtmosphereMode.energetic => 'Motivasyon',
        AtmosphereMode.silent    => 'Sessiz',
      };
}

// ── AtmosphereConfig ──────────────────────────────────────────────────────────
//
// Pure data — no Flutter state. Consumed by AtmosphereLayer widget.

class AtmosphereConfig {
  final Color glowColor;
  final double glowRadius;    // 0–1 relative to screen shortestSide
  final double glowOpacity;   // absolute opacity, kept very low (≤ 0.18)
  final double motionScale;   // particle speed multiplier
  final int particleDelta;    // additive offset to UIStateEngine.particleCount
  final Duration breatheDuration;

  // Overlay effects (transient)
  final double successPulse;  // 0–1: green glow fade-in then fade-out
  final double urgencyPulse;  // 0–1: red glow for exam pressure

  const AtmosphereConfig({
    required this.glowColor,
    this.glowRadius = 0.55,
    this.glowOpacity = 0.06,
    this.motionScale = 1.0,
    this.particleDelta = 0,
    this.breatheDuration = const Duration(milliseconds: 1800),
    this.successPulse = 0.0,
    this.urgencyPulse = 0.0,
  });

  static const quiet = AtmosphereConfig(
    glowColor: Color(0xFF7C6BF8),
    glowOpacity: 0.04,
    motionScale: 0.7,
  );
}

// ── AmbientEngine ─────────────────────────────────────────────────────────────
//
// Manages atmosphere mode and derives AtmosphereConfig.
// Pure in-memory: no persistence needed (resets per session is fine).

class AmbientEngine {
  AtmosphereMode _mode = AtmosphereMode.focusRoom;
  double _successPulse = 0.0;
  double _urgencyPulse = 0.0;
  double _topicDifficulty = 0.5;     // 0 easy → 1 hard
  TeacherEmotionalState _teacherState = TeacherEmotionalState.calm;
  TeacherLiveState _liveState = TeacherLiveState.idle;

  AtmosphereMode get mode => _mode;

  // ── Public mutators ────────────────────────────────────────────────────────

  void setMode(AtmosphereMode mode) {
    _mode = mode;
    _urgencyPulse = mode == AtmosphereMode.examMode ? 0.12 : 0.0;
  }

  void reactToTeacherLiveState(TeacherLiveState state) {
    _liveState = state;
  }

  void reactToEmotionalState(TeacherEmotionalState state) {
    _teacherState = state;
    // Auto-upgrade atmosphere based on emotional state
    if (state == TeacherEmotionalState.excited && _mode == AtmosphereMode.focusRoom) {
      _mode = AtmosphereMode.energetic;
    } else if (state == TeacherEmotionalState.encouraging) {
      _successPulse = (_successPulse + 0.3).clamp(0.0, 0.8);
    }
  }

  void reactToTopicDifficulty(double difficulty) {
    _topicDifficulty = difficulty.clamp(0.0, 1.0);
  }

  /// Call after a student breakthrough (high success estimate, breakthrough journal entry).
  void triggerSuccessPulse() {
    _successPulse = 0.9;
  }

  /// Tick down transient pulses (call every ~200 ms from a timer).
  /// Sum of active transient pulse values — used by the UI tick to detect
  /// whether a repaint is actually needed.
  double get currentIntensity => _successPulse + _urgencyPulse;

  void tick() {
    if (_successPulse > 0) _successPulse = (_successPulse - 0.04).clamp(0.0, 1.0);
    if (_urgencyPulse > 0 && _mode != AtmosphereMode.examMode) {
      _urgencyPulse = (_urgencyPulse - 0.02).clamp(0.0, 1.0);
    }
  }

  /// Clear all transient effects (e.g. when switching topics).
  void clearTransients() {
    _successPulse = 0.0;
    if (_mode != AtmosphereMode.examMode) _urgencyPulse = 0.0;
  }

  // ── Config derivation ──────────────────────────────────────────────────────

  AtmosphereConfig get config {
    final base = _baseForMode(_mode);
    // Modulate by teacher live state
    final liveOpacity = _liveOpacityMod;
    // Modulate by difficulty (harder → slightly cooler glow)
    final difficultyColor = Color.lerp(base.glowColor, const Color(0xFF3B82F6), _topicDifficulty * 0.25)!;

    return AtmosphereConfig(
      glowColor: _teacherColorOverride ?? difficultyColor,
      glowRadius: base.glowRadius + (_liveState == TeacherLiveState.explaining ? 0.05 : 0.0),
      glowOpacity: (base.glowOpacity * liveOpacity).clamp(0.0, 0.18),
      motionScale: base.motionScale * (_liveState == TeacherLiveState.thinking ? 0.6 : 1.0),
      particleDelta: base.particleDelta,
      breatheDuration: base.breatheDuration,
      successPulse: _successPulse,
      urgencyPulse: _urgencyPulse,
    );
  }

  double get _liveOpacityMod => switch (_liveState) {
        TeacherLiveState.thinking   => 0.8,
        TeacherLiveState.explaining => 1.2,
        TeacherLiveState.waiting    => 0.9,
        TeacherLiveState.idle       => 0.7,
        _                           => 1.0,
      };

  Color? get _teacherColorOverride => switch (_teacherState) {
        TeacherEmotionalState.excited      => const Color(0xFFFBBF24),
        TeacherEmotionalState.encouraging  => const Color(0xFF4ADE80),
        TeacherEmotionalState.corrective   => const Color(0xFFF87171),
        TeacherEmotionalState.challengeMode => const Color(0xFF818CF8),
        _ => null,
      };

  static AtmosphereConfig _baseForMode(AtmosphereMode mode) => switch (mode) {
        AtmosphereMode.focusRoom => const AtmosphereConfig(
          glowColor: Color(0xFF7C6BF8),
          glowRadius: 0.52,
          glowOpacity: 0.06,
          motionScale: 0.75,
          particleDelta: -3,
          breatheDuration: Duration(milliseconds: 2200),
        ),
        AtmosphereMode.classroom => const AtmosphereConfig(
          glowColor: Color(0xFF93C5FD),
          glowRadius: 0.58,
          glowOpacity: 0.07,
          motionScale: 1.0,
          breatheDuration: Duration(milliseconds: 1600),
        ),
        AtmosphereMode.examMode => const AtmosphereConfig(
          glowColor: Color(0xFFF87171),
          glowRadius: 0.48,
          glowOpacity: 0.10,
          motionScale: 1.3,
          particleDelta: 4,
          breatheDuration: Duration(milliseconds: 900),
        ),
        AtmosphereMode.lateNight => const AtmosphereConfig(
          glowColor: Color(0xFF60A5FA),
          glowRadius: 0.50,
          glowOpacity: 0.05,
          motionScale: 0.55,
          particleDelta: -5,
          breatheDuration: Duration(milliseconds: 2800),
        ),
        AtmosphereMode.energetic => const AtmosphereConfig(
          glowColor: Color(0xFFFBBF24),
          glowRadius: 0.62,
          glowOpacity: 0.09,
          motionScale: 1.4,
          particleDelta: 6,
          breatheDuration: Duration(milliseconds: 1100),
        ),
        AtmosphereMode.silent => const AtmosphereConfig(
          glowColor: Color(0xFF374151),
          glowRadius: 0.40,
          glowOpacity: 0.03,
          motionScale: 0.3,
          particleDelta: -8,
          breatheDuration: Duration(milliseconds: 3500),
        ),
      };

  // ── Auto-mode detection (call after each interaction) ──────────────────────

  /// Suggest an atmosphere mode based on time of day and session context.
  static AtmosphereMode suggestMode({
    required DateTime now,
    required bool isExamSession,
    required double avgConfidence,
    required int frustrationStreak,
  }) {
    if (isExamSession) return AtmosphereMode.examMode;

    final hour = now.hour;
    if (hour >= 22 || hour < 6) return AtmosphereMode.lateNight;

    if (frustrationStreak >= 2) return AtmosphereMode.energetic;
    if (avgConfidence >= 0.75) return AtmosphereMode.classroom;

    return AtmosphereMode.focusRoom;
  }
}
