// ── AttentionEngine ───────────────────────────────────────────────────────────
//
// Estimates student attention level from behavioral signals:
//   - Response delay patterns
//   - Message length trends
//   - Interruption frequency
//   - Hesitation / confusion phrases
//   - Session duration
//
// Outputs pacing recommendations the teacher session can act on.
//
// Future hooks:
//   - Camera emotion detection (face landmarks → stress/fatigue)
//   - Eye tracking (gaze duration → reading speed estimate)
//   - Wearable HRV (heart rate variability → stress peaks)
//   - Apple Vision Pro spatial attention zones

import 'package:omnicore_foundation/omnicore_foundation.dart'
    show AssistantPacingHint;

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AttentionLevel {
  high,        // fast, accurate, engaged
  medium,      // normal flow
  low,         // slowing down, shorter messages
  fatigued,    // very slow, 45+ min continuous
  distracted,  // erratic timing, very short messages
}

extension AttentionLevelExt on AttentionLevel {
  String get label => switch (this) {
        AttentionLevel.high       => 'Yüksek Odak',
        AttentionLevel.medium     => 'Normal',
        AttentionLevel.low        => 'Düşük Odak',
        AttentionLevel.fatigued   => 'Yorgunluk',
        AttentionLevel.distracted => 'Dağılmış',
      };
}

enum PacingAdjustment {
  none,
  suggestBreak,
  shortenChunks,
  addExample,
  increaseEncouragement,
  simplify,
  speedUp,
  miniQuiz,
}

extension PacingAdjustmentExt on PacingAdjustment {
  /// Phrase the teacher inserts naturally into the conversation.
  String? get teacherPhrase => switch (this) {
        PacingAdjustment.suggestBreak =>
          'Biraz mola verelim mi? Birkaç dakika dinlenmek odağını artırır.',
        PacingAdjustment.shortenChunks =>
          'Daha küçük adımlarla gidelim — adım adım.',
        PacingAdjustment.addExample =>
          'Somut bir örnekle göstereyim.',
        PacingAdjustment.increaseEncouragement =>
          'İyi gidiyorsun. Devam et, bu konuyu kesinlikle anlayabilirsin.',
        PacingAdjustment.simplify =>
          'Biraz daha basit anlatayım.',
        PacingAdjustment.speedUp =>
          'Hızlanabiliriz — konuya hâkimsin.',
        PacingAdjustment.miniQuiz =>
          'Küçük bir test soralım — ne kadar yerleşti görelim.',
        PacingAdjustment.none => null,
      };
}

// ── OmniCore pacing-hint adapter ──────────────────────────────────────────────
//
// Phase 4B: exposes LiseAI's PacingAdjustment as an AssistantPacingHint so
// ShortTermMemory (in OmniCore) can hold pacing state without depending on
// LiseAI domain types.

extension PacingHintAdapter on PacingAdjustment {
  /// AssistantPacingHint view of this LiseAI pacing adjustment.
  AssistantPacingHint get hint => _PacingHintAdapter(this);
}

class _PacingHintAdapter implements AssistantPacingHint {
  final PacingAdjustment _p;
  const _PacingHintAdapter(this._p);

  @override
  String get kind => _p.name;

  @override
  bool get isNoOp => _p == PacingAdjustment.none;
}

// ── AttentionSignal ───────────────────────────────────────────────────────────

class AttentionSignal {
  final AttentionLevel level;
  final PacingAdjustment adjustment;
  final bool shouldSuggestBreak;
  final bool focusModeRecommended; // dim UI, reduce motion

  const AttentionSignal({
    required this.level,
    required this.adjustment,
    this.shouldSuggestBreak = false,
    this.focusModeRecommended = false,
  });

  static const neutral = AttentionSignal(
    level: AttentionLevel.medium,
    adjustment: PacingAdjustment.none,
  );
}

// ── AttentionEngine ───────────────────────────────────────────────────────────

class AttentionEngine {
  // Circular buffer of last 10 response delays (seconds)
  final _responseDelays = <double>[];
  static const _maxDelayHistory = 10;

  // Interaction counters
  int _confusionCount = 0;
  int _interruptionCount = 0;
  int _consecutiveShortMessages = 0;
  int _consecutiveLongMessages = 0;
  int _rapidInputCount = 0; // messages < 2s apart (guessing)
  int _totalInputs = 0;

  // Timing
  DateTime? _lastInputTime;
  DateTime? _sessionStart;
  Duration _continuousStudy = Duration.zero;

  // Focus mode: triggered after 20+ uninterrupted minutes
  bool _focusModeTriggered = false;

  // Turkish hesitation / confusion phrases
  static const _hesitationPhrases = [
    'bilmiyorum', 'emin değilim', 'anlamadım', 'anlaşılmadı',
    'karıştı', 'ne demek', 'tekrar', 'bir daha', 'nasıl',
    'neden', 'niye', 'yani', '?', 'hm', 'hmm', 'aa', 'ohh',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call every time the student sends a message.
  void recordUserInput(String text, {required DateTime timestamp}) {
    _totalInputs++;
    final clean = text.trim().toLowerCase();
    final words = clean.split(RegExp(r'\s+')).length;

    // Response delay
    if (_lastInputTime != null) {
      final delay = timestamp.difference(_lastInputTime!).inMilliseconds / 1000.0;

      if (delay < 2.0) {
        _rapidInputCount++;
      } else {
        _rapidInputCount = (_rapidInputCount - 1).clamp(0, 99);
      }

      _responseDelays.add(delay.clamp(0.0, 300.0));
      if (_responseDelays.length > _maxDelayHistory) _responseDelays.removeAt(0);
    } else {
      _sessionStart = timestamp;
    }
    _lastInputTime = timestamp;

    // Continuous study time
    if (_sessionStart != null) {
      _continuousStudy = timestamp.difference(_sessionStart!);
    }

    // Focus mode: 25+ min with steady engagement
    if (_continuousStudy.inMinutes >= 25 && _interruptionCount < 3) {
      _focusModeTriggered = true;
    }

    // Message length tracking
    if (words <= 3) {
      _consecutiveShortMessages++;
      _consecutiveLongMessages = 0;
    } else if (words >= 15) {
      _consecutiveLongMessages++;
      _consecutiveShortMessages = 0;
    } else {
      _consecutiveShortMessages = 0;
      _consecutiveLongMessages = 0;
    }

    // Hesitation detection
    final hasHesitation = _hesitationPhrases.any((p) => clean.contains(p));
    if (hasHesitation) _confusionCount++;
  }

  void recordInterruption() {
    _interruptionCount++;
    _focusModeTriggered = false; // break kills focus mode
    _continuousStudy = Duration.zero;
    _sessionStart = _lastInputTime;
  }

  void recordConfusion() {
    _confusionCount++;
  }

  void recordSuccess() {
    _confusionCount = (_confusionCount - 1).clamp(0, 99);
    _consecutiveShortMessages = 0;
  }

  void reset() {
    _responseDelays.clear();
    _confusionCount = 0;
    _interruptionCount = 0;
    _consecutiveShortMessages = 0;
    _consecutiveLongMessages = 0;
    _rapidInputCount = 0;
    _totalInputs = 0;
    _lastInputTime = null;
    _sessionStart = null;
    _continuousStudy = Duration.zero;
    _focusModeTriggered = false;
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  AttentionLevel get level {
    if (_totalInputs < 3) return AttentionLevel.medium;

    // Fatigue: 40+ minutes continuous
    if (_continuousStudy.inMinutes >= 40) return AttentionLevel.fatigued;

    // Distracted: many rapid/short responses
    if (_rapidInputCount >= 4 && _consecutiveShortMessages >= 3) {
      return AttentionLevel.distracted;
    }

    // Low: slowing down, confused
    if (_confusionCount >= 3 || _consecutiveShortMessages >= 5) {
      return AttentionLevel.low;
    }

    // High: long responses, steady timing, minimal confusion
    if (_consecutiveLongMessages >= 3 && _confusionCount == 0) {
      return AttentionLevel.high;
    }

    return AttentionLevel.medium;
  }

  bool get focusModeRecommended => _focusModeTriggered;

  bool get shouldSuggestBreak {
    return _continuousStudy.inMinutes >= 45 ||
        (level == AttentionLevel.fatigued && _totalInputs >= 10);
  }

  Duration get concentrationDuration => _continuousStudy;

  double get _avgDelay {
    if (_responseDelays.isEmpty) return 10.0;
    return _responseDelays.reduce((a, b) => a + b) / _responseDelays.length;
  }

  AttentionSignal get currentSignal {
    final lvl = level;
    final break_ = shouldSuggestBreak;
    final focus = focusModeRecommended;

    if (break_) {
      return AttentionSignal(
        level: lvl,
        adjustment: PacingAdjustment.suggestBreak,
        shouldSuggestBreak: true,
        focusModeRecommended: focus,
      );
    }

    final adj = switch (lvl) {
      AttentionLevel.fatigued   => PacingAdjustment.suggestBreak,
      AttentionLevel.distracted => PacingAdjustment.miniQuiz,
      AttentionLevel.low        => _confusionCount >= 3
          ? PacingAdjustment.simplify
          : PacingAdjustment.addExample,
      AttentionLevel.high when _avgDelay < 3.0 => PacingAdjustment.speedUp,
      AttentionLevel.high       => PacingAdjustment.miniQuiz,
      _                         => PacingAdjustment.none,
    };

    return AttentionSignal(
      level: lvl,
      adjustment: adj,
      shouldSuggestBreak: break_,
      focusModeRecommended: focus,
    );
  }

  /// Build a prompt block injected into Claude to adapt its teaching style.
  String buildAttentionPromptBlock() {
    final sig = currentSignal;
    if (sig.adjustment == PacingAdjustment.none) return '';
    final studyMin = _continuousStudy.inMinutes;

    return '''

[ÖĞRENCİ DURUMU]
Dikkat seviyesi: ${sig.level.label}
Toplam çalışma süresi: $studyMin dakika
Karışıklık sayısı: $_confusionCount
${sig.adjustment == PacingAdjustment.suggestBreak ? 'Öğrenci mola için hazır — nazikçe öner.' : ''}
${sig.adjustment == PacingAdjustment.simplify ? 'Açıklamaları sadeleştir, daha küçük adımlarla git.' : ''}
${sig.adjustment == PacingAdjustment.addExample ? 'Somut örnek ekle, soyut kalma.' : ''}
${sig.adjustment == PacingAdjustment.speedUp ? 'Öğrenci hızlı kavradı — daha zorlu içeriğe geç.' : ''}
${sig.adjustment == PacingAdjustment.miniQuiz ? 'Mini soru sor — yerleşip yerleşmediğini kontrol et.' : ''}
''';
  }
}
