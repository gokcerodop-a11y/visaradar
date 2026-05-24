import 'dart:convert';

// ── Phases ────────────────────────────────────────────────────────────────────

/// The 7 structured phases of a lesson session.
enum StructuredPhase {
  giris,    // 1. Introduction — motivation hook, real-life connection
  kavram,   // 2. Concept      — core idea, intuition first
  ornek,    // 3. Example      — worked example / demonstration
  miniSoru, // 4. Check Q      — AI asks a short verification question
  kontrol,  // 5. Control      — AI evaluates student's answer
  ozet,     // 6. Summary      — key points, formula, memory tip
  miniOdev, // 7. Mini HW      — one independent challenge problem
}

extension StructuredPhaseExt on StructuredPhase {
  String get label => switch (this) {
        StructuredPhase.giris    => 'Giriş',
        StructuredPhase.kavram   => 'Kavram',
        StructuredPhase.ornek    => 'Örnek',
        StructuredPhase.miniSoru => 'Mini Soru',
        StructuredPhase.kontrol  => 'Kontrol',
        StructuredPhase.ozet     => 'Özet',
        StructuredPhase.miniOdev => 'Mini Ödev',
      };

  /// Short Claude instruction for this phase.
  String get promptInstruction => switch (this) {
        StructuredPhase.giris =>
            'DERS AŞAMASI — Giriş: Motivasyonla başla, konunun günlük hayattaki bağlantısını kur. '
            '"Bu konuyu öğrenmek sana şunu sağlar:" ile aç.',
        StructuredPhase.kavram =>
            'DERS AŞAMASI — Kavram: Temel fikri sezgi önce gelecek şekilde açıkla. '
            'Formüle geçmeden önce mantığı oturtalım.',
        StructuredPhase.ornek =>
            'DERS AŞAMASI — Örnek: Somut, adım adım çözülmüş bir örnek göster. '
            'Her adımı açıkla, nihai cevabı vurgula.',
        StructuredPhase.miniSoru =>
            'DERS AŞAMASI — Mini Soru: Açıkladıktan sonra anlamayı ölçmek için '
            'KISA bir kontrol sorusu sor (1-2 cümle). '
            '"Şimdi sana küçük bir soru:" ile başla. Cevabı kendin verme.',
        StructuredPhase.kontrol =>
            'DERS AŞAMASI — Kontrol: Öğrencinin cevabını değerlendir. '
            'Doğruysa: "Tam isabet! ..." ile tebrik et. '
            'Yanlışsa: nazikçe düzelt, neyi kaçırdığını göster.',
        StructuredPhase.ozet =>
            'DERS AŞAMASI — Özet: Konunun ana noktalarını özetle. '
            'Şu yapıyı kullan: 1) Formül/Kural 2) Kritik nokta 3) Hafıza ipucu.',
        StructuredPhase.miniOdev =>
            'DERS AŞAMASI — Mini Ödev: Öğrenciye bağımsız çözmesi için '
            'BİR kısa alıştırma ver. Zorluğu az önce işlenenle aynı seviyede tut. '
            '"Şimdi sıra sende:" ile başla. Cevabı henüz verme.',
      };

  int get index => StructuredPhase.values.indexOf(this);
  bool get isLast => this == StructuredPhase.miniOdev;
}

// ── Flow state ────────────────────────────────────────────────────────────────

class LessonFlowState {
  StructuredPhase phase;
  String? topic;
  int turnsInPhase;
  int checkAttempts;   // how many times mini soru was attempted
  int totalTurns;
  bool isActive;       // true once flow has started

  LessonFlowState({
    this.phase = StructuredPhase.giris,
    this.topic,
    this.turnsInPhase = 0,
    this.checkAttempts = 0,
    this.totalTurns = 0,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'topic': topic,
        'turnsInPhase': turnsInPhase,
        'checkAttempts': checkAttempts,
        'totalTurns': totalTurns,
        'isActive': isActive,
      };

  factory LessonFlowState.fromJson(Map<String, dynamic> j) => LessonFlowState(
        phase: StructuredPhase.values.firstWhere(
          (p) => p.name == j['phase'],
          orElse: () => StructuredPhase.giris,
        ),
        topic: j['topic'] as String?,
        turnsInPhase: j['turnsInPhase'] as int? ?? 0,
        checkAttempts: j['checkAttempts'] as int? ?? 0,
        totalTurns: j['totalTurns'] as int? ?? 0,
        isActive: j['isActive'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
  factory LessonFlowState.fromJsonString(String s) =>
      LessonFlowState.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
