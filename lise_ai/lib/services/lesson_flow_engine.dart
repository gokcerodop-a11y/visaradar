import '../models/cognitive_profile.dart';
import '../models/lesson_flow.dart';
import '../models/lesson_mode.dart';
import '../models/student_profile.dart';
import '../services/learning_graph_engine.dart';
import '../services/storage_service.dart';
import '../services/teacher_engine.dart';

// ── StructuredLessonFlowEngine ────────────────────────────────────────────────
//
// Manages the 7-phase structured lesson flow per topic session.
// Integrates: TeachingSignal, LessonMode, StudentLevel, CognitiveProfile,
// weak topics list, and LearningGraphEngine mastery data.

class StructuredLessonFlowEngine {
  static const _key = 'lesson_flow_v1';

  LessonFlowState _state = LessonFlowState();
  StorageService? _storage;

  // ── Public accessors ───────────────────────────────────────────────────────

  StructuredPhase get currentPhase => _state.phase;
  String? get currentTopic => _state.topic;
  bool get isActive => _state.isActive;
  LessonFlowState get state => _state;

  // ── Init / persist ─────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      try {
        _state = LessonFlowState.fromJsonString(raw);
      } catch (_) {
        _state = LessonFlowState();
      }
    }
  }

  void reset() {
    _state = LessonFlowState();
    _save();
  }

  Future<void> _save() async {
    await _storage?.saveSetting(_key, _state.toJsonString());
  }

  // ── Main entry point ───────────────────────────────────────────────────────

  /// Call after each complete user↔AI turn.
  ///
  /// [signal]     — from TeacherEngine.lastSignal
  /// [topic]      — detected topic (null = unknown)
  /// [mode]       — current lesson mode
  /// [level]      — student level
  /// [cogProfile] — cognitive profile snapshot
  /// [weakTopics] — from StudentProfile
  /// [graphEngine]— for mastery lookup
  Future<void> advance({
    required TeachingSignal signal,
    required String? topic,
    required LessonMode mode,
    required StudentLevel level,
    required CognitiveProfile cogProfile,
    required List<String> weakTopics,
    required LearningGraphEngine graphEngine,
  }) async {
    _state.isActive = true;
    _state.totalTurns++;

    final resolvedTopic = topic ?? _state.topic;

    // Topic change → restart flow for new topic
    if (resolvedTopic != null &&
        resolvedTopic != 'Genel' &&
        resolvedTopic != _state.topic) {
      _restartForTopic(resolvedTopic, mode, level, cogProfile, graphEngine, weakTopics);
      await _save();
      return;
    }

    if (resolvedTopic != null && _state.topic == null) {
      _state.topic = resolvedTopic;
    }

    _state.turnsInPhase++;

    final next = _computeNextPhase(
      signal: signal,
      mode: mode,
      level: level,
      cogProfile: cogProfile,
      weakTopics: weakTopics,
      graphEngine: graphEngine,
    );

    if (next != _state.phase) {
      if (next == StructuredPhase.miniSoru) _state.checkAttempts++;
      _state.phase = next;
      _state.turnsInPhase = 0;
    }

    await _save();
  }

  // ── Phase transition logic ─────────────────────────────────────────────────

  void _restartForTopic(
    String topic,
    LessonMode mode,
    StudentLevel level,
    CognitiveProfile cogProfile,
    LearningGraphEngine graphEngine,
    List<String> weakTopics,
  ) {
    _state.topic = topic;
    _state.turnsInPhase = 0;
    _state.checkAttempts = 0;

    // Determine starting phase based on mode + mastery
    final mastery = graphEngine.allMastery[topic]?.masteryScore ?? 0;
    final isWeak = weakTopics.contains(topic) || mastery < 30;

    if (mode == LessonMode.hizliCevap) {
      // Fast mode: skip intro, go directly to concept
      _state.phase = StructuredPhase.kavram;
    } else if (mode == LessonMode.sadaceIpucu) {
      // Hint mode: skip to example where hints apply
      _state.phase = StructuredPhase.ornek;
    } else if (mastery >= 70 && !isWeak) {
      // Already mastered → skip to mini soru to verify
      _state.phase = StructuredPhase.miniSoru;
      _state.checkAttempts++;
    } else {
      _state.phase = StructuredPhase.giris;
    }
  }

  StructuredPhase _computeNextPhase({
    required TeachingSignal signal,
    required LessonMode mode,
    required StudentLevel level,
    required CognitiveProfile cogProfile,
    required List<String> weakTopics,
    required LearningGraphEngine graphEngine,
  }) {
    final p = _state.phase;
    final turns = _state.turnsInPhase;
    final attempts = _state.checkAttempts;

    // Mode-specific fast paths
    if (mode == LessonMode.hizliCevap) return _fastPath(p, turns, signal);
    if (mode == LessonMode.sadaceIpucu) return _hintPath(p, turns, signal);
    if (mode == LessonMode.soruSorarak) return _questionPath(p, turns, signal, cogProfile);
    if (mode == LessonMode.sinavKocu) return _examPath(p, turns, signal, attempts);

    // Default structured flow
    return _defaultPath(p, turns, signal, cogProfile, level, weakTopics, attempts);
  }

  // ── Mode-specific paths ────────────────────────────────────────────────────

  /// hizliCevap: giris(0) → kavram(1) → özet(1)
  StructuredPhase _fastPath(StructuredPhase p, int turns, TeachingSignal s) {
    return switch (p) {
      StructuredPhase.giris    => StructuredPhase.kavram,
      StructuredPhase.kavram   => turns >= 1 ? StructuredPhase.ozet : p,
      StructuredPhase.ozet     => turns >= 1 ? StructuredPhase.miniOdev : p,
      StructuredPhase.miniOdev => p,
      _                        => StructuredPhase.ozet,
    };
  }

  /// sadaceIpucu: ornek → miniSoru → kontrol → özet
  StructuredPhase _hintPath(StructuredPhase p, int turns, TeachingSignal s) {
    return switch (p) {
      StructuredPhase.giris    => StructuredPhase.ornek,
      StructuredPhase.kavram   => StructuredPhase.ornek,
      StructuredPhase.ornek    => turns >= 1 ? StructuredPhase.miniSoru : p,
      StructuredPhase.miniSoru => StructuredPhase.kontrol,
      StructuredPhase.kontrol  => s.successEstimate >= 0.55
          ? StructuredPhase.ozet
          : StructuredPhase.ornek,
      StructuredPhase.ozet     => StructuredPhase.miniOdev,
      StructuredPhase.miniOdev => p,
    };
  }

  /// soruSorarak: kavram(1) → miniSoru → kontrol → (loop back or özet)
  StructuredPhase _questionPath(
      StructuredPhase p, int turns, TeachingSignal s, CognitiveProfile cog) {
    return switch (p) {
      StructuredPhase.giris    => StructuredPhase.kavram,
      StructuredPhase.kavram   => turns >= 1 ? StructuredPhase.miniSoru : p,
      StructuredPhase.ornek    => StructuredPhase.miniSoru,
      StructuredPhase.miniSoru => StructuredPhase.kontrol,
      StructuredPhase.kontrol  => s.successEstimate >= 0.6
          ? StructuredPhase.ozet
          : (s.isStruggling ? StructuredPhase.kavram : StructuredPhase.miniSoru),
      StructuredPhase.ozet     => StructuredPhase.miniOdev,
      StructuredPhase.miniOdev => p,
    };
  }

  /// sinavKocu: kavram(1) → örnek(1) → miniSoru → kontrol → miniOdev (practice)
  StructuredPhase _examPath(
      StructuredPhase p, int turns, TeachingSignal s, int attempts) {
    return switch (p) {
      StructuredPhase.giris    => StructuredPhase.kavram,
      StructuredPhase.kavram   => turns >= 1 ? StructuredPhase.ornek : p,
      StructuredPhase.ornek    => turns >= 1 ? StructuredPhase.miniSoru : p,
      StructuredPhase.miniSoru => StructuredPhase.kontrol,
      StructuredPhase.kontrol  => s.successEstimate >= 0.55
          ? StructuredPhase.miniOdev
          : (attempts < 3 ? StructuredPhase.miniSoru : StructuredPhase.miniOdev),
      StructuredPhase.ozet     => StructuredPhase.miniOdev,
      StructuredPhase.miniOdev => p,
    };
  }

  /// Default full flow (ogretmenGibi, tahtadaCoz, sesliDers)
  StructuredPhase _defaultPath(
    StructuredPhase p,
    int turns,
    TeachingSignal s,
    CognitiveProfile cog,
    StudentLevel level,
    List<String> weakTopics,
    int attempts,
  ) {
    // How many turns to spend in kavram/ornek depends on level + cognitive profile
    final isBeginnerLevel = level == StudentLevel.lgs || level == StudentLevel.sinif9;
    final isExamLevel = level == StudentLevel.tyt || level == StudentLevel.ayt;
    final wantsSteps = cog.learningStyle == LearningStyle.stepByStep;
    final isFrustrated = cog.motivationState == MotivationState.frustrated;

    final kavramTurns = (isBeginnerLevel || wantsSteps || isFrustrated) ? 2 : 1;
    final ornekTurns = (isBeginnerLevel || wantsSteps) ? 2 : 1;
    final fastTransition = isExamLevel && !isFrustrated;

    return switch (p) {
      StructuredPhase.giris => StructuredPhase.kavram,

      StructuredPhase.kavram => s.isStruggling
          ? p  // stay — still struggling
          : turns >= (fastTransition ? 1 : kavramTurns)
              ? StructuredPhase.ornek
              : p,

      StructuredPhase.ornek => s.hasConfusion
          ? StructuredPhase.kavram  // regression — needs re-explanation
          : turns >= (fastTransition ? 1 : ornekTurns)
              ? StructuredPhase.miniSoru
              : p,

      StructuredPhase.miniSoru => StructuredPhase.kontrol,

      StructuredPhase.kontrol => _evaluateAnswer(s, attempts, weakTopics),

      StructuredPhase.ozet => StructuredPhase.miniOdev,

      StructuredPhase.miniOdev => p, // stay until topic changes
    };
  }

  StructuredPhase _evaluateAnswer(
    TeachingSignal s,
    int attempts,
    List<String> weakTopics,
  ) {
    final correct = s.successEstimate >= 0.65;
    final partial = s.successEstimate >= 0.45 && s.successEstimate < 0.65;
    final maxAttempts = (weakTopics.contains(_state.topic)) ? 3 : 2;

    if (correct) return StructuredPhase.ozet;
    if (partial && attempts < maxAttempts) return StructuredPhase.miniSoru; // retry
    if (!correct && attempts < maxAttempts) return StructuredPhase.ornek;   // re-teach
    return StructuredPhase.ozet; // move on regardless
  }

  // ── Prompt builder ─────────────────────────────────────────────────────────

  /// Returns Turkish instruction block for Claude system prompt.
  String buildFlowPrompt() {
    if (!_state.isActive) return '';

    final buf = StringBuffer();
    final p = _state.phase;

    buf.writeln('\n--- YAPILANDIRILMIŞ DERS AKIŞI ---');

    if (_state.topic != null) {
      buf.writeln('Aktif konu: ${_state.topic}');
    }
    buf.writeln('Aşama ${p.index + 1}/7 — ${p.label}');
    buf.writeln(p.promptInstruction);

    // Add context hints based on check attempt count
    if (p == StructuredPhase.kontrol && _state.checkAttempts > 1) {
      buf.writeln(
        'Not: Öğrenci bu soruyu ${_state.checkAttempts}. kez deniyor. '
        'Eğer yanlışsa daha basit bir ipucu ver, hayal kırıklığı yaratma.',
      );
    }

    if (p == StructuredPhase.miniOdev) {
      buf.writeln(
        'Ödev verildi. Öğrenci çözümünü paylaşırsa değerlendir ve '
        'bir sonraki konuya geçmeyi öner.',
      );
    }

    // Phase progress hint
    final remaining = StructuredPhase.values.length - p.index - 1;
    if (remaining == 1) {
      buf.writeln('Son aşamaya yaklaşıldı. Bu konu oturumu bitmek üzere.');
    }

    buf.writeln('--- DERS AKIŞI SONU ---');
    return buf.toString();
  }

  // ── Phase completion list (for UI) ────────────────────────────────────────

  /// Returns index of last completed phase (for progress dots).
  int get completedUpToIndex => _state.isActive ? _state.phase.index : -1;
}
