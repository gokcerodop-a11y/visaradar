import 'dart:convert';

// ── Interaction record ────────────────────────────────────────────────────────

class InteractionRecord {
  final DateTime timestamp;
  final String topic;
  final String mode;       // LessonMode.name
  final bool usedHints;
  final bool usedBoard;
  final double successEstimate; // 0.0–1.0

  const InteractionRecord({
    required this.timestamp,
    required this.topic,
    required this.mode,
    required this.usedHints,
    required this.usedBoard,
    required this.successEstimate,
  });

  Map<String, dynamic> toJson() => {
        'ts': timestamp.millisecondsSinceEpoch,
        'topic': topic,
        'mode': mode,
        'hints': usedHints,
        'board': usedBoard,
        'success': successEstimate,
      };

  factory InteractionRecord.fromJson(Map<String, dynamic> j) =>
      InteractionRecord(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (j['ts'] as int?) ?? 0),
        topic: (j['topic'] as String?) ?? 'Genel',
        mode: (j['mode'] as String?) ?? '',
        usedHints: (j['hints'] as bool?) ?? false,
        usedBoard: (j['board'] as bool?) ?? false,
        successEstimate: ((j['success'] as num?) ?? 0.6).toDouble(),
      );
}

// ── Student profile ───────────────────────────────────────────────────────────

class StudentProfile {
  String? name;
  List<InteractionRecord> recentHistory; // last 40
  int streakDays;
  DateTime? lastActiveDate;

  StudentProfile({
    this.name,
    List<InteractionRecord>? recentHistory,
    this.streakDays = 0,
    this.lastActiveDate,
  }) : recentHistory = recentHistory ?? [];

  // ── Computed analytics ──────────────────────────────────────────────────

  int get totalInteractions => recentHistory.length;

  /// Per-topic stats computed from history.
  Map<String, _TopicStat> get topicStats {
    final map = <String, _TopicStat>{};
    for (final r in recentHistory) {
      final s = map.putIfAbsent(r.topic, () => _TopicStat());
      s.count++;
      if (r.usedHints) s.hintCount++;
      s.successSum += r.successEstimate;
    }
    return map;
  }

  /// Topics where the student struggles (hint rate high OR success low).
  List<String> get weakTopics {
    final stats = topicStats;
    return stats.entries
        .where((e) =>
            e.value.count >= 2 &&
            (e.value.hintRate > 0.40 || e.value.avgSuccess < 0.55))
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => stats[b]!.hintCount - stats[a]!.hintCount);
  }

  /// Topics where the student performs consistently well.
  List<String> get strongTopics {
    final stats = topicStats;
    return stats.entries
        .where((e) =>
            e.value.count >= 2 &&
            e.value.hintRate < 0.20 &&
            e.value.avgSuccess > 0.68)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => stats[b]!.count - stats[a]!.count);
  }

  /// Topic from the most recent session (for daily greeting).
  String? get lastTopic =>
      recentHistory.isNotEmpty ? recentHistory.first.topic : null;

  /// Last interaction time.
  DateTime? get lastInteractionTime =>
      recentHistory.isNotEmpty ? recentHistory.first.timestamp : null;

  // ── Serialisation ───────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name': name,
        'streak': streakDays,
        'lastActive': lastActiveDate?.millisecondsSinceEpoch,
        'history': recentHistory.map((r) => r.toJson()).toList(),
      };

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        name: j['name'] as String?,
        streakDays: (j['streak'] as int?) ?? 0,
        lastActiveDate: j['lastActive'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['lastActive'] as int)
            : null,
        recentHistory: ((j['history'] as List?) ?? [])
            .map((e) => InteractionRecord.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  String toJsonString() => jsonEncode(toJson());
  factory StudentProfile.fromJsonString(String s) =>
      StudentProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

// ── Internal stat helper ──────────────────────────────────────────────────────

class _TopicStat {
  int count = 0;
  int hintCount = 0;
  double successSum = 0;

  double get hintRate => count == 0 ? 0 : hintCount / count;
  double get avgSuccess => count == 0 ? 0 : successSum / count;
}

// ── Topic detector ────────────────────────────────────────────────────────────

class TopicDetector {
  static const _map = <String, List<String>>{
    'Türev': ['türev', "f'(x)", 'diferansiyel', 'derivative'],
    'İntegral': ['integral', 'antiderivative', '∫', 'belirli integral'],
    'Limit': ['limit', 'yakınsama', 'ıraksama', 'sınır değer'],
    'Trigonometri': [
      'trigonometri', 'sinüs', 'kosinüs', 'tanjant',
      'sin(', 'cos(', 'tan(', 'cotanjant', 'radyan', 'derece'
    ],
    'Geometri': [
      'geometri', 'üçgen', 'çember', 'daire', 'kare', 'dikdörtgen',
      'paralelkenar', 'yamuk', 'piramit', 'silindir', 'alan', 'hacim',
      'açı', 'hipotenüs', 'pisagor'
    ],
    'Denklemler': [
      'denklem', 'kök', 'birinci derece', 'ikinci derece',
      'doğrusal', 'quadratic', 'equation', 'çözüm kümesi'
    ],
    'Fonksiyonlar': [
      'fonksiyon', 'f(x)', 'tanım kümesi', 'değer kümesi',
      'bileşke', 'ters fonksiyon', 'domain', 'range'
    ],
    'Logaritma': ['logaritma', 'log ', 'ln ', 'üs', 'exponential'],
    'Diziler': [
      'dizi', 'seri', 'aritmetik dizi', 'geometrik dizi',
      'toplam formülü', 'n. terim'
    ],
    'Olasılık': [
      'olasılık', 'probability', 'kombinasyon', 'permütasyon',
      'istatistik', 'ortalama', 'medyan', 'mod'
    ],
    'Matrisler': ['matris', 'matrix', 'determinant', 'vektör', 'lineer'],
    'Fizik': [
      'fizik', 'kuvvet', 'hız', 'ivme', 'enerji', 'momentum',
      'elektrik', 'manyetik', 'dalga', 'frekans', 'newton',
      'joule', 'basınç', 'yoğunluk', 'optik', 'ısı'
    ],
    'Kimya': [
      'kimya', 'element', 'mol', 'reaksiyon', 'asit', 'baz',
      'periyodik', 'atom', 'molekül', 'elektron', 'proton',
      'titrasyon', 'çözelti', 'organik'
    ],
    'Biyoloji': [
      'biyoloji', 'hücre', 'dna', 'rna', 'gen', 'evrim',
      'protein', 'fotosentez', 'mitoz', 'mayoz', 'ekosistem'
    ],
    'Tarih': [
      'tarih', 'osmanlı', 'cumhuriyet', 'atatürk', 'savaş',
      'imparatorluk', 'devrim', 'anayasa', 'kurtuluş'
    ],
    'Edebiyat': [
      'edebiyat', 'şiir', 'roman', 'hikaye', 'yazı türü',
      'divan', 'tanzimat', 'servet-i fünun', 'milli'
    ],
    'Türkçe': [
      'dilbilgisi', 'cümle', 'sözdizim', 'ek', 'fiil', 'isim',
      'sıfat', 'zarf', 'noktalama', 'yazım kuralı'
    ],
    'Coğrafya': [
      'coğrafya', 'iklim', 'harita', 'nüfus', 'yerleşim',
      'dağ', 'nehir', 'göl', 'kıta', 'ülke'
    ],
  };

  /// Returns the most likely topic label for [text], or null if no match.
  static String? detect(String text) {
    final lower = text.toLowerCase();
    String? best;
    int bestScore = 0;
    for (final entry in _map.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return bestScore > 0 ? best : null;
  }
}
