import 'dart:async';

// ── ExamCampStats ─────────────────────────────────────────────────────────────

class ExamCampStats {
  final int totalQuestions;
  final int correct;
  final int incorrectOrSkipped;
  final Duration elapsed;
  final String topic;

  const ExamCampStats({
    required this.totalQuestions,
    required this.correct,
    required this.incorrectOrSkipped,
    required this.elapsed,
    required this.topic,
  });

  double get accuracy =>
      totalQuestions == 0 ? 0.0 : correct / totalQuestions;

  String get grade {
    final pct = accuracy;
    if (pct >= 0.90) return 'A+';
    if (pct >= 0.80) return 'A';
    if (pct >= 0.70) return 'B';
    if (pct >= 0.60) return 'C';
    return 'D';
  }
}

// ── ExamCampSession ───────────────────────────────────────────────────────────
//
// Powers "Sınav Kampı" mode:
//   - Countdown timer with urgency escalation
//   - Question tally (student marks answers themselves via the UI)
//   - Confidence stabilization hints when accuracy drops
//   - Urgency level 0→1 as time runs out (affects atmosphere)

class ExamCampService {
  bool isActive = false;
  bool isPaused = false;

  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  int _questionsAnswered = 0;
  int _correctAnswers = 0;
  String topic = '';
  DateTime? _startTime;
  DateTime? _pausedAt;
  Duration _pausedTotal = Duration.zero;

  // Countdown stream (broadcasts remaining seconds)
  final _countdownCtrl = StreamController<int>.broadcast();
  Stream<int> get countdownStream => _countdownCtrl.stream;

  Timer? _timer;

  // ── Public API ─────────────────────────────────────────────────────────────

  void startSession({
    required int durationMinutes,
    String topic = 'Genel',
  }) {
    this.topic = topic;
    _totalSeconds = durationMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _questionsAnswered = 0;
    _correctAnswers = 0;
    isActive = true;
    isPaused = false;
    _startTime = DateTime.now();
    _pausedTotal = Duration.zero;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void recordAnswer({required bool correct}) {
    if (!isActive) return;
    _questionsAnswered++;
    if (correct) _correctAnswers++;
  }

  void pauseSession() {
    if (!isActive || isPaused) return;
    isPaused = true;
    _pausedAt = DateTime.now();
    _timer?.cancel();
  }

  void resumeSession() {
    if (!isActive || !isPaused) return;
    if (_pausedAt != null) {
      _pausedTotal += DateTime.now().difference(_pausedAt!);
    }
    isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void endSession() {
    _timer?.cancel();
    isActive = false;
    isPaused = false;
  }

  void dispose() {
    _timer?.cancel();
    _countdownCtrl.close();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;

  /// 0 = calm → 1 = maximum urgency (last 20% of time)
  double get urgencyLevel {
    if (_totalSeconds == 0) return 0.0;
    final progress = 1.0 - (_remainingSeconds / _totalSeconds);
    // Urgency ramps sharply in last 20% of time
    if (progress < 0.8) return 0.0;
    return ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
  }

  ExamCampStats get stats {
    final elapsed = _startTime == null
        ? Duration.zero
        : DateTime.now().difference(_startTime!) - _pausedTotal;
    return ExamCampStats(
      totalQuestions: _questionsAnswered,
      correct: _correctAnswers,
      incorrectOrSkipped: _questionsAnswered - _correctAnswers,
      elapsed: elapsed,
      topic: topic,
    );
  }

  String get formattedRemaining {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get confidenceHint {
    if (_questionsAnswered < 3) return '';
    final acc = stats.accuracy;
    if (acc < 0.40) return 'Streslenme — her soru bir fırsat. Düşün, elim.';
    if (acc < 0.60) return 'İyi gidiyorsun. Sakin kal.';
    if (acc >= 0.80) return 'Harika! Bu tempoda devam et.';
    return '';
  }

  // ── System prompt block ────────────────────────────────────────────────────

  String buildExamCampPromptBlock() {
    if (!isActive) return '';
    return '''

[SINAV KAMPI AKTİF]
Konu: $topic
Kalan süre: $formattedRemaining
Doğru: $_correctAnswers / $_questionsAnswered
${urgencyLevel > 0.5 ? 'ZAMAN BASKISI: Hızlı ve net ol. Gereksiz açıklama yok.' : ''}
Mod: Hızlı soru-cevap, kısa onay/düzeltme, sınav temposu.
Her yanıtta mutlaka bir sonraki soruya hazırla.
''';
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _tick(Timer timer) {
    if (_remainingSeconds <= 0) {
      timer.cancel();
      isActive = false;
      _countdownCtrl.add(0);
      return;
    }
    _remainingSeconds--;
    _countdownCtrl.add(_remainingSeconds);
  }
}
