// ── SpeechTag ─────────────────────────────────────────────────────────────────
//
// Hidden emotional cues injected into Claude output.
// Used to modulate TTS pacing, emphasis, and future ElevenLabs voice control.
//
// Claude is instructed to embed these in its output as [tag] markers.
// The parser strips them from display text but uses them to shape delivery.

enum SpeechTag {
  normal,       // default flow
  pause,        // explicit mid-sentence pause
  slow,         // reduce speech rate
  important,    // emphasize this segment
  excited,      // higher energy, faster
  gentle,       // soft, reassuring tone
  examWarning,  // ÖSYM/YKS critical point
  question,     // rhetorical / check-in
  boardSync,    // signal to start board animation
}

extension SpeechTagExt on SpeechTag {
  // Rate multiplier applied to TTS (1.0 = normal)
  double get rateMultiplier => switch (this) {
        SpeechTag.slow        => 0.75,
        SpeechTag.gentle      => 0.82,
        SpeechTag.normal      => 1.00,
        SpeechTag.excited     => 1.15,
        SpeechTag.important   => 0.88,
        SpeechTag.examWarning => 0.80,
        SpeechTag.question    => 0.90,
        SpeechTag.pause       => 1.00,
        SpeechTag.boardSync   => 1.00,
      };

  // Extra pause injected BEFORE this sentence (ms)
  int get prePauseMs => switch (this) {
        SpeechTag.pause       => 600,
        SpeechTag.important   => 350,
        SpeechTag.examWarning => 500,
        SpeechTag.boardSync   => 200,
        SpeechTag.question    => 150,
        _                     => 0,
      };

  // Extra pause injected AFTER this sentence (ms)
  int get postPauseMs => switch (this) {
        SpeechTag.pause       => 800,
        SpeechTag.important   => 600,
        SpeechTag.examWarning => 700,
        SpeechTag.question    => 1200,
        SpeechTag.gentle      => 300,
        _                     => 0,
      };

  // Subtitle emphasis intensity 0–1
  double get emphasisLevel => switch (this) {
        SpeechTag.important   => 1.0,
        SpeechTag.examWarning => 0.9,
        SpeechTag.excited     => 0.7,
        SpeechTag.gentle      => 0.3,
        _                     => 0.0,
      };

  String get displayHint => switch (this) {
        SpeechTag.examWarning => '⚠️ Sınav Notu',
        SpeechTag.important   => '★ Kritik',
        SpeechTag.question    => '?',
        _                     => '',
      };
}

// ── Tagged sentence ───────────────────────────────────────────────────────────

class TaggedSentence {
  final String displayText;   // cleaned (no tags)
  final String rawText;       // with tags (for ElevenLabs SSML future use)
  final SpeechTag primaryTag;
  final List<SpeechTag> allTags;

  const TaggedSentence({
    required this.displayText,
    required this.rawText,
    required this.primaryTag,
    required this.allTags,
  });

  bool get hasEmphasis => primaryTag.emphasisLevel > 0;
  bool get triggersBoardSync => allTags.contains(SpeechTag.boardSync);
}

// ── SpeechTagParser ───────────────────────────────────────────────────────────

class SpeechTagParser {
  static final _tagPattern = RegExp(
      r'\[(pause|slow|important|excited|gentle|exam_warning|question|board_sync)\]',
      caseSensitive: false);

  static const _tagMap = <String, SpeechTag>{
    'pause'       : SpeechTag.pause,
    'slow'        : SpeechTag.slow,
    'important'   : SpeechTag.important,
    'excited'     : SpeechTag.excited,
    'gentle'      : SpeechTag.gentle,
    'exam_warning': SpeechTag.examWarning,
    'question'    : SpeechTag.question,
    'board_sync'  : SpeechTag.boardSync,
  };

  /// Parse a raw sentence from Claude into a [TaggedSentence].
  static TaggedSentence parse(String raw) {
    final found = <SpeechTag>[];

    for (final m in _tagPattern.allMatches(raw)) {
      final key = m.group(1)?.toLowerCase() ?? '';
      final tag = _tagMap[key];
      if (tag != null) found.add(tag);
    }

    final clean = raw.replaceAll(_tagPattern, '').replaceAll('  ', ' ').trim();
    final primary = found.isEmpty ? SpeechTag.normal : found.first;

    return TaggedSentence(
      displayText: clean,
      rawText: raw,
      primaryTag: primary,
      allTags: found.isEmpty ? [SpeechTag.normal] : found,
    );
  }

  /// Strip all speech tags from a string (for display-only use).
  static String strip(String raw) =>
      raw.replaceAll(_tagPattern, '').replaceAll('  ', ' ').trim();

  /// System prompt block explaining speech tags to Claude.
  static const systemPromptBlock = '''

[KONUŞMA ETİKETLERİ]
Yanıt verirken aşağıdaki etiketleri uygun yerlere yerleştir:
[pause]       → açık duraklama (zorlu kısımlar arası)
[slow]        → yavaşlaması gereken kısım
[important]   → kritik bilgi (öğrenci dikkat etmeli)
[excited]     → heyecanlı an (başarı, aha! moment)
[gentle]      → nazik, destekleyici ton
[exam_warning] → ÖSYM/YKS kritik uyarısı
[question]    → soru sormadan önce (öğrencinin düşünmesi için)
[board_sync]  → tahtanın çizime başlaması gereken yer

Kurallar:
- Her cümlede en fazla 1 etiket kullan
- Etiketler köşeli parantez içinde, cümle başında veya içinde olabilir
- Doğal yerlere ekle — her cümleye zorla ekleme
''';
}
