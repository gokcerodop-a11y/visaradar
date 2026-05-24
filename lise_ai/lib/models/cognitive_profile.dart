import 'dart:convert';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LearningStyle {
  visual,        // prefers diagrams/board
  exampleBased,  // "örnek ver"
  conceptual,    // "mantığını anlat"
  fastAnswer,    // "kısaca"
  stepByStep,    // "adım adım"
  unknown,
}

extension LearningStyleExt on LearningStyle {
  String get label => switch (this) {
        LearningStyle.visual       => 'Görsel',
        LearningStyle.exampleBased => 'Örnek Odaklı',
        LearningStyle.conceptual   => 'Kavramsal',
        LearningStyle.fastAnswer   => 'Hızlı Cevap',
        LearningStyle.stepByStep   => 'Adım Adım',
        LearningStyle.unknown      => 'Belirsiz',
      };

  String get promptInstruction => switch (this) {
        LearningStyle.visual =>
            'Öğrenci görsel öğreniyor — diyagram ve şemalarla destekle, tahtayı aktif kullan.',
        LearningStyle.exampleBased =>
            'Öğrenci örneklerle öğreniyor — her açıklamaya somut örnek ekle.',
        LearningStyle.conceptual =>
            'Öğrenci kavramsal düşünüyor — önce "neden" ve "nasıl" sorularını yanıtla.',
        LearningStyle.fastAnswer =>
            'Öğrenci kısa yanıt istiyor — özlü, sade açıklamalar yap.',
        LearningStyle.stepByStep =>
            'Öğrenci adım adım çözüm istiyor — her adımı numaralandır.',
        LearningStyle.unknown => '',
      };
}

enum MotivationState {
  normal,
  frustrated,  // "yapamıyorum", "çok zor"
  confident,   // "anladım", "kolaymış"
  anxious,     // "sınav", "endişe"
  bored,       // "sıkıldım", "çok uzun"
}

extension MotivationStateExt on MotivationState {
  String get label => switch (this) {
        MotivationState.normal     => 'Normal',
        MotivationState.frustrated => 'Zorlanıyor',
        MotivationState.confident  => 'Özgüvenli',
        MotivationState.anxious    => 'Endişeli',
        MotivationState.bored      => 'Sıkılmış',
      };

  String get promptInstruction => switch (this) {
        MotivationState.normal     => '',
        MotivationState.frustrated =>
            'Öğrenci zorlanıyor — sabırlı, cesaretlendirici bir ton kullan. Küçük adımlarla ilerle.',
        MotivationState.confident =>
            'Öğrenci özgüvenli — biraz daha zorlayıcı sorular ve kavramlar ekleyebilirsin.',
        MotivationState.anxious =>
            'Öğrenci sınav stresi altında — sakin, sistematik ve güven verici bir dil kullan.',
        MotivationState.bored =>
            'Öğrenci sıkılmış — daha ilgi çekici örnekler ve sorularla konuyu canlandır.',
      };

  bool get isNegative =>
      this == MotivationState.frustrated || this == MotivationState.anxious;
}

// ── Error types ────────────────────────────────────────────────────────────────

enum ErrorType {
  islem,       // computation errors
  kavram,      // concept misunderstanding
  dikkat,      // careless mistakes
  formul,      // wrong formula
  okuma,       // reading/comprehension errors
}

extension ErrorTypeExt on ErrorType {
  String get label => switch (this) {
        ErrorType.islem  => 'İşlem Hatası',
        ErrorType.kavram => 'Kavram Hatası',
        ErrorType.dikkat => 'Dikkat Hatası',
        ErrorType.formul => 'Formül Hatası',
        ErrorType.okuma  => 'Okuma/Anlama Hatası',
      };
}

// ── CognitiveProfile ──────────────────────────────────────────────────────────

class CognitiveProfile {
  LearningStyle learningStyle;
  int attentionSpanEstimate; // 1-10 scale
  MotivationState motivationState;
  Map<ErrorType, int> errorTypeCounts;
  int preferredExplanationLength; // 1=short, 3=long
  String preferredTeacherTone; // "encouraging", "direct", "socratic"
  List<String> lastDetectedSignals;

  // Internal vote tracking for learning style detection
  Map<String, int> _styleVotes;

  CognitiveProfile({
    this.learningStyle = LearningStyle.unknown,
    this.attentionSpanEstimate = 5,
    this.motivationState = MotivationState.normal,
    Map<ErrorType, int>? errorTypeCounts,
    this.preferredExplanationLength = 2,
    this.preferredTeacherTone = 'encouraging',
    List<String>? lastDetectedSignals,
    Map<String, int>? styleVotes,
  })  : errorTypeCounts = errorTypeCounts ?? {},
        lastDetectedSignals = lastDetectedSignals ?? [],
        _styleVotes = styleVotes ?? {};

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'learningStyle': learningStyle.name,
        'attentionSpanEstimate': attentionSpanEstimate,
        'motivationState': motivationState.name,
        'errorTypeCounts': errorTypeCounts
            .map((k, v) => MapEntry(k.name, v)),
        'preferredExplanationLength': preferredExplanationLength,
        'preferredTeacherTone': preferredTeacherTone,
        'lastDetectedSignals': lastDetectedSignals,
        'styleVotes': _styleVotes,
      };

  factory CognitiveProfile.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errorTypeCounts'] as Map<String, dynamic>? ?? {};
    final errors = <ErrorType, int>{};
    for (final e in ErrorType.values) {
      if (rawErrors.containsKey(e.name)) {
        errors[e] = rawErrors[e.name] as int;
      }
    }

    final rawVotes = json['styleVotes'] as Map<String, dynamic>? ?? {};
    final votes = rawVotes.map((k, v) => MapEntry(k, v as int));

    return CognitiveProfile(
      learningStyle: LearningStyle.values.firstWhere(
        (s) => s.name == json['learningStyle'],
        orElse: () => LearningStyle.unknown,
      ),
      attentionSpanEstimate: json['attentionSpanEstimate'] as int? ?? 5,
      motivationState: MotivationState.values.firstWhere(
        (s) => s.name == json['motivationState'],
        orElse: () => MotivationState.normal,
      ),
      errorTypeCounts: errors,
      preferredExplanationLength: json['preferredExplanationLength'] as int? ?? 2,
      preferredTeacherTone: json['preferredTeacherTone'] as String? ?? 'encouraging',
      lastDetectedSignals: List<String>.from(json['lastDetectedSignals'] ?? []),
      styleVotes: votes,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory CognitiveProfile.fromJsonString(String s) =>
      CognitiveProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ── Accessors ──────────────────────────────────────────────────────────────

  Map<String, int> get styleVotes => _styleVotes;

  List<ErrorType> get topErrors {
    final sorted = errorTypeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).where((e) => e.value > 0).map((e) => e.key).toList();
  }

  String get recommendedTeachingStyle {
    final style = learningStyle.promptInstruction;
    final mood = motivationState.promptInstruction;
    if (style.isEmpty && mood.isEmpty) return 'Standart öğretim stili.';
    return [style, mood].where((s) => s.isNotEmpty).join(' ');
  }

  void addStyleVote(String style) {
    _styleVotes[style] = (_styleVotes[style] ?? 0) + 1;
    // Pick winner with at least 2 votes
    final best = _styleVotes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value >= 2) {
      learningStyle = LearningStyle.values.firstWhere(
        (s) => s.name == best.key,
        orElse: () => LearningStyle.unknown,
      );
    }
  }
}
