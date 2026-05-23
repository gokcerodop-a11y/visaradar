import '../models/lesson_mode.dart';
import '../models/student_profile.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TeachingPace { slow, normal, fast }

enum LessonPhase { intro, concept, guidedSolving, recap, challenge }

// ── Signal snapshot ───────────────────────────────────────────────────────────

class TeachingSignal {
  final bool hasConfusion;
  final bool hasUncertainty;
  final bool isStruggling;
  final bool isAdvanced;
  final bool hasRepeatedMistake;
  final bool needsEncouragement;
  final bool shouldTriggerBoard;
  final bool shouldSummarize;
  final bool shouldAskQuestion;
  final bool wantsRepetition;
  final TeachingPace pace;
  final LessonPhase phase;
  final double successEstimate;

  const TeachingSignal({
    this.hasConfusion = false,
    this.hasUncertainty = false,
    this.isStruggling = false,
    this.isAdvanced = false,
    this.hasRepeatedMistake = false,
    this.needsEncouragement = false,
    this.shouldTriggerBoard = false,
    this.shouldSummarize = false,
    this.shouldAskQuestion = false,
    this.wantsRepetition = false,
    this.pace = TeachingPace.normal,
    this.phase = LessonPhase.concept,
    this.successEstimate = 0.65,
  });
}

// ── Teacher engine ────────────────────────────────────────────────────────────

class TeacherEngine {
  // ── Confusion keyword sets ─────────────────────────────────────────────────

  static const _confusionWords = <String>[
    'anlamadım', 'anlamıyorum', 'anlayamadım', 'ne demek', 'nasıl yani',
    'kafam karıştı', 'tekrar açıkla', 'bir daha', 'anlat yeniden',
    'hâlâ anlamadım', 'hala anlamadım', 'daha basit', 'daha kolay',
    'çok karmaşık', 'çok zor', 'hiç anlamıyorum', 'neden böyle', 'neden öyle',
  ];

  static const _uncertaintyWords = <String>[
    'emin değilim', 'galiba', 'sanırım', 'doğru mu', 'yanlış mı',
    'mi acaba', 'acaba', 'tam değil', 'bilmiyorum', 'bilmiyorum ki',
    'mı yani', 'öyle mi', 'doğru mu yaptım', 'bu mu',
  ];

  static const _comprehensionWords = <String>[
    'anladım', 'tamam', 'teşekkür', 'harika', 'mantıklı', 'çok güzel',
    'mükemmel', 'evet anladım', 'şimdi anladım', 'anladım artık',
    'çok açık', 'net oldu', 'peki', 'süper',
  ];

  static const _repetitionWords = <String>[
    'tekrar', 'bir daha', 'yeniden', 'tekrar açıkla', 'olmadı', 'hâlâ',
    'hala', 'yine', 'baştan', 'gene',
  ];

  static const _visualTopics = <String>[
    'Geometri', 'Trigonometri', 'Fonksiyonlar', 'Diziler',
    'Matrisler', 'İntegral', 'Türev', 'Fizik',
  ];

  static const _examPhrases = <String>[
    'sınavda', 'ykste', 'ytde', 'ayta', 'tytde', 'lgste',
    'sınav', 'puan', 'süre', 'hızlı', 'pratik yol', 'kısa yol',
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  TeachingSignal _lastSignal = const TeachingSignal();
  int _topicInteractionCount = 0;
  String? _currentTopic;
  int _confusionStreak = 0;  // consecutive turns with confusion
  int _comprehensionStreak = 0;
  int _totalTurns = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  TeachingSignal get lastSignal => _lastSignal;

  /// Reset engine state for a new conversation.
  void reset() {
    _lastSignal = const TeachingSignal();
    _topicInteractionCount = 0;
    _currentTopic = null;
    _confusionStreak = 0;
    _comprehensionStreak = 0;
    _totalTurns = 0;
  }

  /// Call with the user's latest message before sending to Claude.
  /// [history] is the full message history, [profile] is the student profile,
  /// [mode] is current lesson mode, [currentTopic] is the detected topic.
  void analyze({
    required List<Map<String, dynamic>> history,
    required StudentProfile profile,
    required LessonMode mode,
    String? currentTopic,
  }) {
    _totalTurns++;

    // Track topic continuity
    if (currentTopic != null && currentTopic != _currentTopic) {
      _currentTopic = currentTopic;
      _topicInteractionCount = 1;
    } else {
      _topicInteractionCount++;
    }

    final lastUserMsg = _lastUserMessage(history);
    final recentUserMsgs = _recentUserMessages(history, 6);

    // ── Per-message signals ──────────────────────────────────────────────────
    final hasConfusion = _containsAny(lastUserMsg, _confusionWords);
    final hasUncertainty = _containsAny(lastUserMsg, _uncertaintyWords);
    final hasComprehension = _containsAny(lastUserMsg, _comprehensionWords);
    final wantsRepetition = _containsAny(lastUserMsg, _repetitionWords);
    final isShortMsg = lastUserMsg.length < 22 && lastUserMsg.contains('?');
    final multiQuestion = '?'.allMatches(lastUserMsg).length >= 2;
    final hasExamFocus = _containsAny(lastUserMsg, _examPhrases) ||
        mode == LessonMode.sinavKocu;

    // ── Streak tracking ──────────────────────────────────────────────────────
    if (hasConfusion || hasUncertainty || isShortMsg || wantsRepetition) {
      _confusionStreak++;
      _comprehensionStreak = 0;
    } else if (hasComprehension) {
      _comprehensionStreak++;
      _confusionStreak = (_confusionStreak - 1).clamp(0, 99);
    } else {
      // neutral — decay slowly
      if (_confusionStreak > 0) _confusionStreak--;
    }

    // ── Aggregate signals ────────────────────────────────────────────────────
    final confusionInRecent = recentUserMsgs
        .where((m) => _containsAny(m, _confusionWords) ||
            _containsAny(m, _uncertaintyWords))
        .length;

    final isStruggling = _confusionStreak >= 2 || confusionInRecent >= 3 ||
        (currentTopic != null && profile.weakTopics.contains(currentTopic));
    final isAdvanced = _comprehensionStreak >= 3 &&
        (currentTopic == null || profile.strongTopics.contains(currentTopic));

    // Check if same weak topic has appeared multiple times in history
    final hasRepeatedMistake = currentTopic != null &&
        profile.weakTopics.contains(currentTopic) &&
        _topicInteractionCount >= 3;

    // Board mode: visual topic + struggling OR repeated mistake OR explicit draw request
    final visualTopic = _visualTopics.contains(currentTopic);
    final asksToShow = _containsAny(lastUserMsg, ['göster', 'çiz', 'şekil', 'görsel']);
    final shouldTriggerBoard = (isStruggling && visualTopic) ||
        hasRepeatedMistake ||
        asksToShow ||
        (multiQuestion && visualTopic);

    // Summarize after several turns on same topic OR after comprehension signal
    final shouldSummarize = (_topicInteractionCount >= 5 && hasComprehension) ||
        (_topicInteractionCount >= 7);

    // Ask question: after delivering concept if student is passive
    final isPassive = lastUserMsg.length < 30 && !lastUserMsg.contains('?') &&
        !hasComprehension && _topicInteractionCount >= 2;
    final shouldAskQuestion = isPassive && !isStruggling && !hasExamFocus;

    // Encouragement: student tried but is struggling OR first sign of understanding
    final showedEffort = _containsAny(lastUserMsg,
        ['denedim', 'çözdüm', 'yaptım', 'buldum', 'sanırım', 'galiba', 'belki']);
    final needsEncouragement = (isStruggling && showedEffort) ||
        (hasComprehension && _confusionStreak > 0);

    // Teaching pace
    TeachingPace pace;
    if (isStruggling || mode == LessonMode.ogretmenGibi) {
      pace = TeachingPace.slow;
    } else if (isAdvanced || hasExamFocus || mode == LessonMode.hizliCevap) {
      pace = TeachingPace.fast;
    } else {
      pace = TeachingPace.normal;
    }

    // Lesson phase
    LessonPhase phase;
    if (_topicInteractionCount <= 1) {
      phase = LessonPhase.intro;
    } else if (isStruggling || _topicInteractionCount <= 3) {
      phase = LessonPhase.concept;
    } else if (shouldSummarize) {
      phase = _comprehensionStreak >= 2 ? LessonPhase.challenge : LessonPhase.recap;
    } else if (_topicInteractionCount <= 6) {
      phase = LessonPhase.guidedSolving;
    } else {
      phase = isAdvanced ? LessonPhase.challenge : LessonPhase.recap;
    }

    // Success estimate for profile recording
    double successEstimate;
    if (hasComprehension && !hasConfusion) {
      successEstimate = 0.85;
    } else if (hasConfusion || wantsRepetition) {
      successEstimate = 0.30;
    } else if (hasUncertainty || isStruggling) {
      successEstimate = 0.45;
    } else if (isAdvanced) {
      successEstimate = 0.90;
    } else {
      successEstimate = 0.65;
    }

    _lastSignal = TeachingSignal(
      hasConfusion: hasConfusion || multiQuestion,
      hasUncertainty: hasUncertainty,
      isStruggling: isStruggling,
      isAdvanced: isAdvanced,
      hasRepeatedMistake: hasRepeatedMistake,
      needsEncouragement: needsEncouragement,
      shouldTriggerBoard: shouldTriggerBoard,
      shouldSummarize: shouldSummarize,
      shouldAskQuestion: shouldAskQuestion,
      wantsRepetition: wantsRepetition,
      pace: pace,
      phase: phase,
      successEstimate: successEstimate,
    );
  }

  /// Called after the assistant response lands. Updates comprehension tracking.
  void onAssistantResponse(String response) {
    // If assistant response is very long and detailed → we slowed down,
    // which might help. If student next says "anladım", streak will reset.
    // No action needed here currently; reserved for future telemetry.
  }

  // ── Prompt builder ─────────────────────────────────────────────────────────

  /// Returns Turkish orchestration instructions to inject into the system prompt.
  String buildOrchestrationPrompt() {
    if (_totalTurns == 0) return '';
    final s = _lastSignal;
    final buf = StringBuffer();

    buf.writeln('\n--- ÖĞRETMEN ORKESTRASYONu (bu talimatları uygula) ---');

    // Phase instruction
    buf.writeln(_phaseInstruction(s.phase));

    // Pace instruction
    buf.writeln(_paceInstruction(s.pace));

    // Confusion handling
    if (s.hasConfusion) {
      buf.writeln(
        'UYARI: Öğrenci kafa karışıklığı yaşıyor. '
        'Daha basit dille yeniden anlat. '
        'Bir analoji veya günlük hayat örneği kullan. '
        '"Burada kritik noktayı kaçırdın — şöyle düşün:" ile başla.',
      );
    }

    // Uncertainty
    if (s.hasUncertainty && !s.hasConfusion) {
      buf.writeln(
        'Öğrenci emin değil. Onaylayıcı bir giriş yap: '
        '"Doğru yoldasın, sadece şunu dikkate al…" veya '
        '"Neredeyse doğru! Küçük bir düzeltme:"',
      );
    }

    // Struggling
    if (s.isStruggling) {
      buf.writeln(
        'Öğrenci zorlanıyor. Adımları normalden daha küçük tut. '
        'Her adımı açıklarken "Şimdi birlikte düşünelim." ile ara ver. '
        'Önce mantığı oturtalım — formüle geçme.',
      );
    }

    // Advanced
    if (s.isAdvanced) {
      buf.writeln(
        'Öğrenci konuya hâkim. Gereksiz temel açıklamaları atla. '
        'Doğrudan çözüme odaklan veya daha ileri bir soru sor.',
      );
    }

    // Repeated mistake
    if (s.hasRepeatedMistake) {
      buf.writeln(
        'Bu konuda tekrarlayan hata var. '
        '"Burada en sık yapılan hata bu:" ile başla. '
        'Yanlış anlaşılan kısmı özellikle vurgula. '
        'Tahta modunu önermek için: yanıtın sonuna '
        '"Bu konuyu tahtada adım adım çizmek ister misin?" ekle.',
      );
    }

    // Repetition request
    if (s.wantsRepetition) {
      buf.writeln(
        'Öğrenci tekrar istiyor. Farklı bir yaklaşım veya yeni bir örnek kullan — '
        'aynı açıklamayı tekrar etme.',
      );
    }

    // Board trigger
    if (s.shouldTriggerBoard) {
      buf.writeln(
        'Bu konu görsel anlatımdan yararlanır. '
        'Yanıtın sonuna şunu ekle: '
        '"Bunu tahtada adım adım görmek ister misin?" — '
        'böylece öğrenci tahta modunu açabilir.',
      );
    }

    // Encourage
    if (s.needsEncouragement) {
      buf.writeln(
        'Öğrenciyi cesaretlendir. '
        '"Çok iyi yaklaşıyorsun!" veya "Bu adımı doğru düşündün, devam et!" gibi. '
        'Robotik değil, sıcak bir ses tonu kullan.',
      );
    }

    // Summarize
    if (s.shouldSummarize) {
      buf.writeln(
        'Bu konuyu kısaca özetle: ana formül, kritik nokta, '
        've bir hatırlatıcı ipucu. Ardından mini bir soru sor.',
      );
    }

    // Ask question
    if (s.shouldAskQuestion) {
      buf.writeln(
        'Öğrencinin aktif düşünmesini sağlamak için yanıtın sonuna '
        'bir soru ekle: "Peki bunu bilince şunu söyler misin: …?"',
      );
    }

    // Exam focus (pace==fast + mode signals exam context)
    if (_lastSignal.pace == TeachingPace.fast &&
        _lastSignal.phase != LessonPhase.intro) {
      buf.writeln(
        'Sınav odaklı çöz. "Bu soru ÖSYM tarzı." ile başla. '
        'En hızlı çözüm yolunu göster. Sona "Sınav notu:" ekle.',
      );
    }

    // Phase-specific phrases
    buf.writeln(_phraseSuggestion(s.phase, s.isStruggling));

    // Micro-pause guidance
    buf.writeln(_pauseGuidance(s.pace, s.phase));

    buf.writeln('--- ORKESTRASYOn SONU ---');

    return buf.toString();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _phaseInstruction(LessonPhase phase) => switch (phase) {
        LessonPhase.intro =>
          'DERS AŞAMASI: Giriş — konuya motivasyonla gir, günlük hayat bağlantısı kur.',
        LessonPhase.concept =>
          'DERS AŞAMASI: Kavram — temel fikri sağlamlaştır, sezgi önce gelmeli.',
        LessonPhase.guidedSolving =>
          'DERS AŞAMASI: Rehberli Çözüm — öğrenciye adım adım eşlik et, her adımı açıkla.',
        LessonPhase.recap =>
          'DERS AŞAMASI: Özet — ana noktaları ve formülleri topla, sade ve net tut.',
        LessonPhase.challenge =>
          'DERS AŞAMASI: Mini Meydan Okuma — öğrenciyi zorlayacak bir soru sor veya ileri konuya geç.',
      };

  String _paceInstruction(TeachingPace pace) => switch (pace) {
        TeachingPace.slow =>
          'TEMPO: Yavaş — her kavramı ayrı paragrafta işle, kısa cümle kullan, ara ara "Şimdiye kadar nasıl?" diye sor.',
        TeachingPace.normal =>
          'TEMPO: Normal — dengeli açıklama yap.',
        TeachingPace.fast =>
          'TEMPO: Hızlı — gereksiz girişleri atla, doğrudan hedefe git.',
      };

  String _phraseSuggestion(LessonPhase phase, bool isStruggling) {
    if (isStruggling) {
      return 'Kullanılabilir ifadeler: "Önce mantığı oturtalım." / '
          '"Şimdi birlikte adım adım gidelim." / '
          '"Bu noktada çoğu öğrenci takılıyor, normal."';
    }
    return switch (phase) {
      LessonPhase.intro =>
        'Açılış için: "Bunu bir düşün:" / "Hayatta bunu şöyle görürsün:"',
      LessonPhase.concept =>
        'Kavram için: "İşte kilit nokta burada:" / "Formülü ezberlemeden önce mantığı anla:"',
      LessonPhase.guidedSolving =>
        'Çözüm için: "Şimdi seninle birlikte çözelim:" / "Bu adımda ne yapmalıyız?"',
      LessonPhase.recap =>
        'Özet için: "Bugün şunu öğrendik:" / "Aklında kalsın:"',
      LessonPhase.challenge =>
        'Meydan okuma için: "Şimdi bunu kendin yapabilir misin?" / "Biraz daha zor bir versiyon:"',
    };
  }

  String _pauseGuidance(TeachingPace pace, LessonPhase phase) {
    if (pace == TeachingPace.fast) return '';
    final pauses = <String>[];
    if (phase == LessonPhase.concept) {
      pauses.add('Önemli bir kavramı tanıttıktan sonra "—" ile kısa bir duraklatma yap');
    }
    if (phase == LessonPhase.guidedSolving) {
      pauses.add('Her adım arasında "Buraya kadar tamam mı?" ekle');
    }
    if (pace == TeachingPace.slow) {
      pauses.add('Soru sorduktan sonra öğrenciye düşünme zamanı bırak — hemen cevabı verme');
    }
    return pauses.isEmpty ? '' : 'MİKRO-DURAKSAMA: ${pauses.join('. ')}.';
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  static bool _containsAny(String text, Iterable<String> keywords) {
    final lower = text.toLowerCase();
    for (final kw in keywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  String _lastUserMessage(List<Map<String, dynamic>> history) {
    for (final msg in history.reversed) {
      if (msg['role'] == 'user') {
        final c = msg['content'];
        if (c is String) return c;
        if (c is List) {
          // multi-part content (image+text) — extract text block
          for (final block in c) {
            if (block is Map && block['type'] == 'text') {
              return block['text'] as String? ?? '';
            }
          }
        }
      }
    }
    return '';
  }

  List<String> _recentUserMessages(
      List<Map<String, dynamic>> history, int count) {
    final result = <String>[];
    for (final msg in history.reversed) {
      if (msg['role'] == 'user') {
        final c = msg['content'];
        if (c is String) {
          result.add(c);
        } else if (c is List) {
          for (final block in c) {
            if (block is Map && block['type'] == 'text') {
              result.add(block['text'] as String? ?? '');
              break;
            }
          }
        }
        if (result.length >= count) break;
      }
    }
    return result;
  }
}
