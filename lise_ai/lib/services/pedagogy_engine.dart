/// NextGen Pedagogical Brain — synthesises all behavioural signals into
/// concrete Claude instructions and adaptive visual/pacing triggers.
///
/// Call [recordSent] when the student sends a message,
/// [recordReceived] when the AI reply arrives.
/// Query [signal] and [buildPedagogyPrompt] for the next turn.

// ── Enums ─────────────────────────────────────────────────────────────────────

enum DifficultyDirection { increase, maintain, decrease }

/// Which high-level pedagogical approach to take this turn.
enum TeachingStrategy {
  /// Guide with questions — student is fast and ready.
  socratic,

  /// Straight explanation — neutral state.
  direct,

  /// Use a concrete analogy — student is confused.
  analogy,

  /// Trigger visual board mode — confusion is persisting.
  visual,

  /// Quick recap of the last concept before moving on.
  microReview,

  /// Warm, gentle — rebuild shaken confidence.
  confidence,

  /// Push with harder variants — student is on a streak.
  challenge,
}

// ── Signal ────────────────────────────────────────────────────────────────────

class PedagogySignal {
  final DifficultyDirection difficulty;
  final TeachingStrategy strategy;
  final bool triggerVisualMode;
  final bool insertMicroReview;
  final bool isChallengeMode;
  final bool isConfidenceRebuild;
  final bool isFastSolving;
  final String? emotionalNote; // injected into Claude system prompt

  const PedagogySignal({
    required this.difficulty,
    required this.strategy,
    this.triggerVisualMode = false,
    this.insertMicroReview = false,
    this.isChallengeMode = false,
    this.isConfidenceRebuild = false,
    this.isFastSolving = false,
    this.emotionalNote,
  });

  static const neutral = PedagogySignal(
    difficulty: DifficultyDirection.maintain,
    strategy: TeachingStrategy.direct,
  );
}

// ── Engine ────────────────────────────────────────────────────────────────────

class PedagogyEngine {
  // ── Streak tracking ──────────────────────────────────────────────────────
  int _successStreak = 0;
  int _failureStreak = 0;
  int _totalInteractions = 0;

  // ── Timing ───────────────────────────────────────────────────────────────
  DateTime? _lastReceiveTime;
  int _fastSolveCount = 0;   // response within 10 s of AI reply
  int _slowSolveCount = 0;   // response after 60 s

  // ── Per-turn state ────────────────────────────────────────────────────────
  final List<double> _recentSuccessRates = [];
  bool _wasConfusedLastTurn = false;
  bool _wasConfidenceSpikeLastTurn = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call when the student submits a message.
  void recordSent() {
    final recv = _lastReceiveTime;
    if (recv != null) {
      final gap = DateTime.now().difference(recv).inSeconds;
      if (gap < 10) {
        _fastSolveCount++;
      } else if (gap > 60) {
        _slowSolveCount++;
      }
    }
  }

  /// Call after the AI response is complete.
  void recordReceived({
    required double successEstimate,
    required bool hadConfusion,
  }) {
    _lastReceiveTime = DateTime.now();
    _totalInteractions++;
    _wasConfusedLastTurn = hadConfusion;

    _recentSuccessRates.add(successEstimate);
    if (_recentSuccessRates.length > 6) _recentSuccessRates.removeAt(0);

    if (successEstimate >= 0.70) {
      _successStreak++;
      _failureStreak = 0;
      _wasConfidenceSpikeLastTurn = _successStreak >= 3;
    } else if (successEstimate < 0.42) {
      _failureStreak++;
      _successStreak = 0;
      _wasConfidenceSpikeLastTurn = false;
    } else {
      // neutral — decay streaks slowly
      _wasConfidenceSpikeLastTurn = false;
    }
  }

  // ── Computed signal ────────────────────────────────────────────────────────

  PedagogySignal get signal {
    final avgSuccess = _avg(_recentSuccessRates);

    // Difficulty
    DifficultyDirection difficulty = DifficultyDirection.maintain;
    if (_successStreak >= 3 && avgSuccess > 0.74) {
      difficulty = DifficultyDirection.increase;
    } else if (_failureStreak >= 2 && avgSuccess < 0.44) {
      difficulty = DifficultyDirection.decrease;
    }

    // Strategy
    TeachingStrategy strategy = TeachingStrategy.direct;
    if (_failureStreak >= 3) {
      strategy = TeachingStrategy.confidence;
    } else if (_failureStreak >= 2 && _wasConfusedLastTurn) {
      strategy = TeachingStrategy.microReview;
    } else if (_wasConfusedLastTurn) {
      strategy = TeachingStrategy.analogy;
    } else if (_successStreak >= 4) {
      strategy = TeachingStrategy.challenge;
    } else if (_fastSolveCount >= 3) {
      strategy = TeachingStrategy.socratic;
    } else if (_failureStreak == 1 && _wasConfusedLastTurn) {
      strategy = TeachingStrategy.visual;
    }

    return PedagogySignal(
      difficulty: difficulty,
      strategy: strategy,
      triggerVisualMode: strategy == TeachingStrategy.visual,
      insertMicroReview: strategy == TeachingStrategy.microReview,
      isChallengeMode: _successStreak >= 4,
      isConfidenceRebuild: _failureStreak >= 3,
      isFastSolving: _fastSolveCount >= 3,
      emotionalNote: _emotionalNote(),
    );
  }

  // ── System prompt block ────────────────────────────────────────────────────

  String buildPedagogyPrompt() {
    final sig = signal;
    final buf = StringBuffer();

    buf.writeln('\n═══ ÖĞRETİM KİŞİLİĞİ VE UYARLAMALI DERS TALİMATLARI ═══');

    // 1. Emotional reaction instruction
    final note = sig.emotionalNote;
    if (note != null) {
      buf.writeln('\n[DUYGUSAL DURUM] $note');
    }

    // 2. Difficulty adaptation
    switch (sig.difficulty) {
      case DifficultyDirection.increase:
        buf.writeln(
          '\n[ZORLUK: ARTIR] Öğrenci arka arkaya başarılı. '
          'Bu konuda daha zor bir varyant sun, daha az ipucu ver, '
          '"şimdi bunu kendin dene" yaklaşımını uygula.',
        );
      case DifficultyDirection.decrease:
        buf.writeln(
          '\n[ZORLUK: AZALT] Öğrenci zorlanıyor. '
          'Konuyu daha küçük adımlara böl, temel kavramdan yeniden başla, '
          'önce kolay bir örnek çöz.',
        );
      case DifficultyDirection.maintain:
        break;
    }

    // 3. Teaching strategy
    switch (sig.strategy) {
      case TeachingStrategy.socratic:
        buf.writeln(
          '\n[STRATEJİ: SOKRATIK] Öğrenci hızlı düşünüyor. '
          'Cevabı doğrudan verme — soru sor, yönlendir, '
          'keşfetmesine izin ver. "Peki bunu nasıl ispatlarsın?" gibi.',
        );
      case TeachingStrategy.analogy:
        buf.writeln(
          '\n[STRATEJİ: ANALOJİ] Kavram kafasında oturmadı. '
          'Günlük hayattan somut bir benzetme kur — ardından tekrar teknik açıklamaya dön. '
          'Analojiyi kısa tut, konudan kopma.',
        );
      case TeachingStrategy.visual:
        buf.writeln(
          '\n[STRATEJİ: GÖRSEL] Metin açıklama yetmedi. '
          'Adım adım, numaralı liste, şema veya formül görselleştirmesi kullan. '
          'Tahta modunu önerebilirsin.',
        );
      case TeachingStrategy.microReview:
        buf.writeln(
          '\n[STRATEJİ: MİKRO TEKRAR] Öğrenci takıldı. '
          'Önce son konuyu 2-3 cümleyle özetle, sonra yeni adıma geç. '
          '"Hatırlayalım:" veya "Geçen seferki..." ile başla.',
        );
      case TeachingStrategy.confidence:
        buf.writeln(
          '\n[STRATEJİ: GÜVEN ONARMA] Öğrenci kendine olan inancını kaybediyor. '
          'Geçmişteki bir başarısını hatırlat, hata olduğu için azarlama, '
          'sabırlı ve sıcak kal. "Herkes bunda takılır" gibi normalleştir.',
        );
      case TeachingStrategy.challenge:
        buf.writeln(
          '\n[STRATEJİ: MEYDAN OKUMA] Öğrenci çok iyi gidiyor! '
          'Klasik soruların üstüne çık — "bunu sınav sorusu olarak formüle et" '
          'veya "şimdi tersini ispat et" gibi üst düzey talepler koy.',
        );
      case TeachingStrategy.direct:
        break;
    }

    // 4. Natural conversation rules (always injected)
    buf.writeln('''
\n[DOĞAL KONUŞMA KURALLARI]
- Cevaptan önce kısa bir onay ver: "Doğru!", "Evet, tam onu soruyorum.", "Hmm, ilginç."
- Monoton açıklama yapma — zaman zaman yarım bırak, "sence ne olur?" diye sor.
- Öğrencinin ismini (varsa) ara sıra kullan.
- Bir önceki açıklamaya atıfta bulun: "Az önce dediğimiz gibi..."
- Gereksiz tekrar etme — öğrencinin doğru söylediği şeyi tekrar etme.
- Kısa tut: uzun paragraflar yerine adım adım yaz.''');

    // 5. Deep teaching behaviors
    buf.writeln('''
\n[DERİN ÖĞRETİM]
- Yanlış cevap gelirse önce doğru olan kısmı tebrik et, sonra hatayı nazikçe düzelt.
- Öğrenci aynı kavramda tekrar takılırsa "bu konuda önce şunu netleştirelim" de.
- Basit analoji denediysen farklı bir analoji üret — aynısını tekrarlama.
- Soru "nasıl?" ile başlıyorsa adım adım çöz; "neden?" ile başlıyorsa önce sezgiden başla.
- Öğrenci hızlı cevap veriyorsa süreci biraz yavaşlatıp derinleştir.''');

    // 6. Memory callbacks
    if (_totalInteractions >= 3) {
      buf.writeln(
        '\n[HAFIZA] Geçmiş konuşmalardan öğrenilen kalıpları kullan. '
        'Başarıyla geçilen konuları referans ver. '
        '"Geçen sefer türev konusunda iyiydin, burada da aynı mantığı uygulayabilirsin." '
        'gibi bağlantılar kur.',
      );
    }

    // 7. Silence / hesitation note
    if (_slowSolveCount >= 2) {
      buf.writeln(
        '\n[TERREDDÜTLü ÖĞRENCİ] Öğrenci uzun düşünüyor. '
        'Performans baskısı oluşturma — "düşünmek için zaman al" normaldir. '
        'Acele ettirici ifadeler kullanma.',
      );
    }

    buf.writeln('═══════════════════════════════════════════════════════════');
    return buf.toString();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    _successStreak = 0;
    _failureStreak = 0;
    _totalInteractions = 0;
    _fastSolveCount = 0;
    _slowSolveCount = 0;
    _recentSuccessRates.clear();
    _wasConfusedLastTurn = false;
    _wasConfidenceSpikeLastTurn = false;
    _lastReceiveTime = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _emotionalNote() {
    if (_failureStreak >= 4) {
      return 'Öğrenci ciddi şekilde zorlanıyor. ÇOK sabırlı ol, '
          'küçük adımlara bölün, sesi/tonu yumuşat, güven ver.';
    }
    if (_failureStreak >= 3) {
      return 'Öğrenci motivasyonunu kaybediyor. '
          'Önceki bir başarısını hatırlat, cesaretlendir.';
    }
    if (_failureStreak == 2) {
      return 'İki arka arkaya hata var. '
          'Anlatım stilini değiştir, farklı açıdan yaklaş.';
    }
    if (_successStreak >= 5) {
      return 'Öğrenci harika gidiyor! Coşkunu belli et — '
          '"Bu tempo sürdürürsen çok iyi olacaksın!" gibi.';
    }
    if (_successStreak >= 3) {
      return 'Öğrenci iyi ilerliyor. Pozitif enerjiyle devam et.';
    }
    if (_wasConfidenceSpikeLastTurn) {
      return 'Öğrenci bir anda çok iyi anladı. Bu anı pekiştir.';
    }
    if (_fastSolveCount >= 4) {
      return 'Öğrenci çok hızlı çözüyor — teşvik et, tempoya uyan.';
    }
    return null;
  }

  static double _avg(List<double> list) {
    if (list.isEmpty) return 0.6;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
