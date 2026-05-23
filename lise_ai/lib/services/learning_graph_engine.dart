import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/lesson_mode.dart';
import '../services/storage_service.dart';

// ── Difficulty level ──────────────────────────────────────────────────────────

enum DifficultyLevel { baslangic, temel, orta, ileri, uzman }

extension DifficultyLevelExt on DifficultyLevel {
  String get label => switch (this) {
        DifficultyLevel.baslangic => 'Başlangıç',
        DifficultyLevel.temel     => 'Temel',
        DifficultyLevel.orta      => 'Orta',
        DifficultyLevel.ileri     => 'İleri',
        DifficultyLevel.uzman     => 'Uzman',
      };

  String get promptInstruction => switch (this) {
        DifficultyLevel.baslangic =>
          'Çok temel seviye — basit örnekler, hiç terim varsayma.',
        DifficultyLevel.temel =>
          'Temel seviye — adım adım ilerle, her adımı açıkla.',
        DifficultyLevel.orta =>
          'Orta seviye — standart sorular kullan.',
        DifficultyLevel.ileri =>
          'İleri seviye — zorlayıcı sorular, kısa açıklamalar yeterli.',
        DifficultyLevel.uzman =>
          'Uzman seviye — sınav düzeyinde zor sorular, bağımsız düşünsün.',
      };
}

// ── Topic mastery ─────────────────────────────────────────────────────────────

class TopicMastery {
  int interactionCount;
  double successSum;
  int hintCount;
  int? lastStudiedMs;

  TopicMastery({
    this.interactionCount = 0,
    this.successSum = 0.0,
    this.hintCount = 0,
    this.lastStudiedMs,
  });

  bool get hasData => interactionCount > 0;

  double get successRate =>
      interactionCount == 0 ? 0.0 : successSum / interactionCount;

  double get hintRate =>
      interactionCount == 0 ? 0.0 : hintCount / interactionCount;

  bool get studiedRecently {
    if (lastStudiedMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch - lastStudiedMs! <
        const Duration(days: 7).inMilliseconds;
  }

  /// Mastery 0–100.
  /// Weighted by volume (needs ≥5 sessions for full weight) + recency bonus.
  int get masteryScore {
    if (!hasData) return 0;
    final raw = successRate * 100;
    final penalty = hintRate * 30;
    final volumeWeight = min(interactionCount / 5.0, 1.0);
    final recency = studiedRecently ? 5.0 : 0.0;
    return ((raw - penalty) * volumeWeight + recency).clamp(0, 100).round();
  }

  /// Confidence 0–100: mastery adjusted for consistency and sample size.
  int get confidenceScore {
    if (interactionCount < 2) return 0;
    final volumeWeight = min(interactionCount / 5.0, 1.0);
    final base = masteryScore * (1.0 - hintRate * 0.4);
    return (base * volumeWeight).clamp(0, 100).round();
  }

  Map<String, dynamic> toJson() => {
        'n': interactionCount,
        's': successSum,
        'h': hintCount,
        't': lastStudiedMs,
      };

  factory TopicMastery.fromJson(Map<String, dynamic> j) => TopicMastery(
        interactionCount: (j['n'] as int?) ?? 0,
        successSum: ((j['s'] as num?) ?? 0).toDouble(),
        hintCount: (j['h'] as int?) ?? 0,
        lastStudiedMs: j['t'] as int?,
      );
}

// ── Learning path entry ───────────────────────────────────────────────────────

class LearningPathEntry {
  final String topic;
  final double priority;
  final String reason;

  const LearningPathEntry({
    required this.topic,
    required this.priority,
    required this.reason,
  });
}

// ── Learning graph engine ─────────────────────────────────────────────────────

class LearningGraphEngine {
  static const _storageKey = 'learning_graph_v1';

  StorageService? _storage;
  final _mastery = <String, TopicMastery>{};

  // ── Static dependency graph ────────────────────────────────────────────────

  /// Prerequisite map: topic → required prior topics.
  static const Map<String, List<String>> prerequisites = {
    'Denklemler':   [],
    'Fonksiyonlar': ['Denklemler'],
    'Geometri':     ['Denklemler'],
    'Olasılık':     ['Denklemler'],
    'Matrisler':    ['Denklemler'],
    'Logaritma':    ['Fonksiyonlar', 'Denklemler'],
    'Diziler':      ['Fonksiyonlar', 'Denklemler'],
    'Trigonometri': ['Geometri', 'Denklemler'],
    'Limit':        ['Fonksiyonlar'],
    'Türev':        ['Limit', 'Fonksiyonlar'],
    'İntegral':     ['Türev'],
    'Kimya':        ['Denklemler'],
    'Fizik':        ['Denklemler', 'Trigonometri'],
    'Biyoloji':     [],
    'Tarih':        [],
    'Edebiyat':     [],
    'Türkçe':       [],
    'Coğrafya':     [],
  };

  /// All topics in graph order (fundamentals first).
  static final List<String> allTopics = prerequisites.keys.toList();

  /// Exam relevance weights by StudentLevel.name.
  static const Map<String, Map<String, double>> _levelWeights = {
    'lgs': {
      'Denklemler': 1.0, 'Geometri': 1.0, 'Olasılık': 0.9,
      'Fonksiyonlar': 0.7, 'Türkçe': 1.0, 'Tarih': 0.6,
      'Biyoloji': 0.5, 'Kimya': 0.4, 'Coğrafya': 0.5,
    },
    'sinif9': {
      'Denklemler': 0.9, 'Fonksiyonlar': 0.8, 'Geometri': 0.9,
      'Trigonometri': 0.6, 'Olasılık': 0.6, 'Türkçe': 0.7,
      'Fizik': 0.6, 'Kimya': 0.6, 'Biyoloji': 0.6, 'Tarih': 0.5,
    },
    'sinif10': {
      'Fonksiyonlar': 0.9, 'Trigonometri': 0.8, 'Logaritma': 0.7,
      'Geometri': 0.9, 'Olasılık': 0.8, 'Diziler': 0.6,
      'Fizik': 0.7, 'Kimya': 0.7, 'Biyoloji': 0.6,
    },
    'sinif11': {
      'Limit': 0.9, 'Türev': 0.9, 'Logaritma': 0.8, 'Diziler': 0.8,
      'Trigonometri': 0.8, 'Geometri': 0.8, 'Matrisler': 0.6,
      'Fizik': 0.9, 'Kimya': 0.8, 'Biyoloji': 0.7,
    },
    'sinif12': {
      'Türev': 1.0, 'İntegral': 1.0, 'Limit': 1.0, 'Trigonometri': 0.9,
      'Diziler': 0.9, 'Olasılık': 0.9, 'Matrisler': 0.7,
      'Fizik': 1.0, 'Kimya': 0.9, 'Biyoloji': 0.8,
    },
    'tyt': {
      'Denklemler': 1.0, 'Geometri': 1.0, 'Fonksiyonlar': 0.9,
      'Olasılık': 0.9, 'Trigonometri': 0.7, 'Diziler': 0.6,
      'Logaritma': 0.6, 'Türkçe': 1.0, 'Tarih': 0.8, 'Coğrafya': 0.6,
    },
    'ayt': {
      'Türev': 1.0, 'İntegral': 1.0, 'Limit': 0.9, 'Trigonometri': 0.9,
      'Diziler': 0.9, 'Logaritma': 0.8, 'Matrisler': 0.7,
      'Fonksiyonlar': 0.8, 'Geometri': 0.9, 'Olasılık': 0.8,
      'Fizik': 0.9, 'Kimya': 0.8, 'Biyoloji': 0.8,
    },
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in json.entries) {
          _mastery[e.key] =
              TopicMastery.fromJson(Map<String, dynamic>.from(e.value as Map));
        }
        debugPrint('[Graph] Loaded ${_mastery.length} mastery records');
      } catch (e) {
        debugPrint('[Graph] Load error: $e');
      }
    }
  }

  Future<void> _save() async {
    final json = {
      for (final e in _mastery.entries) e.key: e.value.toJson()
    };
    await _storage?.saveSetting(_storageKey, jsonEncode(json));
  }

  // ── Core record API ────────────────────────────────────────────────────────

  Future<void> recordStudy({
    required String topic,
    required double successEstimate,
    required bool usedHints,
  }) async {
    final m = _mastery.putIfAbsent(topic, TopicMastery.new);
    m.interactionCount++;
    m.successSum += successEstimate;
    if (usedHints) m.hintCount++;
    m.lastStudiedMs = DateTime.now().millisecondsSinceEpoch;
    await _save();
    debugPrint('[Graph] $topic → mastery=${m.masteryScore} '
        'confidence=${m.confidenceScore} n=${m.interactionCount}');
  }

  // ── Query API ──────────────────────────────────────────────────────────────

  TopicMastery masteryFor(String topic) =>
      _mastery[topic] ?? TopicMastery();

  int masteryScore(String topic) => masteryFor(topic).masteryScore;
  int confidenceScore(String topic) => masteryFor(topic).confidenceScore;

  Map<String, TopicMastery> get allMastery => Map.unmodifiable(_mastery);

  DifficultyLevel difficultyFor(String topic) {
    final s = masteryScore(topic);
    if (s < 20) return DifficultyLevel.baslangic;
    if (s < 40) return DifficultyLevel.temel;
    if (s < 60) return DifficultyLevel.orta;
    if (s < 80) return DifficultyLevel.ileri;
    return DifficultyLevel.uzman;
  }

  // ── Prerequisite intelligence ──────────────────────────────────────────────

  /// Returns prerequisite topics of [topic] with mastery below [threshold].
  List<String> weakPrerequisites(String topic, {int threshold = 40}) {
    final prereqs = prerequisites[topic] ?? [];
    return prereqs.where((p) => masteryScore(p) < threshold).toList();
  }

  /// Returns all topics that are unlocked (all prerequisites ≥ threshold).
  List<String> unlockedTopics({int threshold = 35}) => allTopics
      .where((t) =>
          (prerequisites[t] ?? []).every((p) => masteryScore(p) >= threshold))
      .toList();

  /// Returns prerequisite chain for a weak topic (what to study first).
  List<String> prerequisiteChain(String topic) {
    final chain = <String>[];
    void collect(String t) {
      for (final p in prerequisites[t] ?? []) {
        if (masteryScore(p) < 40 && !chain.contains(p)) {
          collect(p);
          chain.add(p);
        }
      }
    }
    collect(topic);
    return chain;
  }

  // ── Mastery scoring ────────────────────────────────────────────────────────

  /// Overall curriculum progress 0–100 for the given level.
  int curriculumProgress(StudentLevel level) {
    final weights = _levelWeights[level.name] ?? {};
    if (weights.isEmpty) return 0;

    double weightedSum = 0;
    double totalWeight = 0;
    for (final entry in weights.entries) {
      weightedSum += masteryScore(entry.key) * entry.value;
      totalWeight += 100 * entry.value;
    }
    return totalWeight == 0 ? 0 : (weightedSum / totalWeight * 100).round();
  }

  // ── Learning path ──────────────────────────────────────────────────────────

  /// Returns ordered learning path entries for the given level.
  List<LearningPathEntry> learningPath(StudentLevel level, {int count = 6}) {
    final weights = _levelWeights[level.name] ?? {};
    final scored = <LearningPathEntry>[];

    for (final topic in allTopics) {
      final w = weights[topic] ?? 0.15;
      final m = masteryScore(topic);
      final unlocked = (prerequisites[topic] ?? [])
          .every((p) => masteryScore(p) >= 35);

      String reason;
      double priority;

      if (!unlocked) {
        // Boost the blocking prerequisites instead
        for (final prereq in prerequisites[topic] ?? []) {
          if (masteryScore(prereq) < 35 && w >= 0.6) {
            final existing = scored.indexWhere((e) => e.topic == prereq);
            if (existing == -1) {
              scored.add(LearningPathEntry(
                topic: prereq,
                priority: w * 0.9,
                reason: '$topic için önkoşul',
              ));
            }
          }
        }
        continue;
      }

      if (m == 0) {
        priority = w * 1.8;
        reason = 'Henüz başlanmadı';
      } else if (m < 40) {
        priority = w * 2.0;
        reason = 'Güçlendirilmeli ($m/100)';
      } else if (m < 65) {
        priority = w * 1.3;
        reason = 'Geliştirilmeli ($m/100)';
      } else if (m < 80) {
        priority = w * 0.7;
        reason = 'İyi seviye ($m/100)';
      } else {
        priority = w * 0.1;
        reason = 'Tamamlandı ($m/100)';
      }

      scored.add(
          LearningPathEntry(topic: topic, priority: priority, reason: reason));
    }

    // Deduplicate (prereq boosts may duplicate)
    final seen = <String>{};
    final unique = scored
        .where((e) => seen.add(e.topic))
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return unique.take(count).toList();
  }

  /// Top topic names from learning path.
  List<String> recommendedTopics(StudentLevel level, {int count = 5}) =>
      learningPath(level, count: count).map((e) => e.topic).toList();

  // ── Confidence estimation ──────────────────────────────────────────────────

  /// Student's overall confidence score across all studied topics.
  int overallConfidence() {
    final studied = _mastery.values.where((m) => m.hasData).toList();
    if (studied.isEmpty) return 0;
    final avg = studied.map((m) => m.confidenceScore).reduce((a, b) => a + b) /
        studied.length;
    return avg.round();
  }

  // ── Exam mode optimization ─────────────────────────────────────────────────

  /// Returns exam-critical topics sorted by gap (low mastery + high weight).
  List<String> examGapTopics(StudentLevel level, {int count = 4}) {
    final weights = _levelWeights[level.name] ?? {};
    final gaps = <MapEntry<String, double>>[];

    for (final entry in weights.entries) {
      if (entry.value < 0.6) continue; // only high-weight topics
      final m = masteryScore(entry.key);
      final gap = entry.value * (100 - m); // higher weight * lower mastery = bigger gap
      gaps.add(MapEntry(entry.key, gap));
    }

    gaps.sort((a, b) => b.value.compareTo(a.value));
    return gaps.take(count).map((e) => e.key).toList();
  }

  // ── System prompt injection ────────────────────────────────────────────────

  String buildContextPrompt({
    required String? currentTopic,
    required LessonMode mode,
    required StudentLevel level,
  }) {
    // Only inject when there's something useful to say
    if (currentTopic == null && _mastery.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('\n--- ÖĞRENİM GRAFİĞİ BAĞLAMI ---');

    // Current topic diagnostics
    if (currentTopic != null && allTopics.contains(currentTopic)) {
      final m = masteryFor(currentTopic);
      final diff = difficultyFor(currentTopic);

      if (m.hasData) {
        buf.writeln(
            'Konu: $currentTopic | Ustalık: ${m.masteryScore}/100 | '
            'Güven: ${m.confidenceScore}/100 | Oturum: ${m.interactionCount}');
      } else {
        buf.writeln('Konu: $currentTopic — İlk kez çalışılıyor.');
      }

      buf.writeln('Zorluk: ${diff.label} — ${diff.promptInstruction}');

      final weak = weakPrerequisites(currentTopic);
      if (weak.isNotEmpty) {
        buf.writeln('⚠ Zayıf önkoşullar: ${weak.join(', ')}');
        if (weak.length == 1) {
          buf.writeln(
              '→ ${weak.first} temelini kısaca sorgula, sonra $currentTopic\'e geç.');
        } else {
          buf.writeln(
              '→ ${weak.first} üzerinden giriş yap, ${currentTopic}\'e köprü kur.');
        }
      }
    }

    // Exam gap analysis
    if (mode == LessonMode.sinavKocu ||
        level == StudentLevel.tyt ||
        level == StudentLevel.ayt) {
      final gaps = examGapTopics(level, count: 3);
      if (gaps.isNotEmpty) {
        buf.writeln('Sınav kritik açıkları: ${gaps.join(' > ')}');
        buf.writeln('Pratik çözüm yollarını öncelikle göster.');
      }
    }

    // Curriculum progress (only if meaningful)
    final progress = curriculumProgress(level);
    if (progress > 0) {
      buf.writeln('Müfredat ilerlemesi: %$progress');
    }

    buf.writeln('--- ÖĞRENİM GRAFİĞİ SONU ---');
    return buf.toString();
  }
}
