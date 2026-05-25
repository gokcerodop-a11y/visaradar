import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:omnicore_foundation/omnicore_foundation.dart' show KeyValueStorage;

// ── SubjectMastery ────────────────────────────────────────────────────────────

class SubjectMastery {
  final String subject;
  double score; // 0.0–1.0
  int sessionCount;
  DateTime lastUpdated;

  SubjectMastery({
    required this.subject,
    required this.score,
    required this.sessionCount,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'score': score,
        'sessionCount': sessionCount,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory SubjectMastery.fromJson(Map<String, dynamic> j) => SubjectMastery(
        subject: j['subject'] as String,
        score: (j['score'] as num).toDouble(),
        sessionCount: (j['sessionCount'] as num).toInt(),
        lastUpdated: DateTime.parse(j['lastUpdated'] as String),
      );

  String get strengthLabel {
    if (score >= 0.8) return 'çok güçlü';
    if (score >= 0.6) return 'iyi';
    if (score >= 0.4) return 'gelişiyor';
    if (score >= 0.2) return 'zayıf';
    return 'çok zayıf';
  }
}

// ── MistakePattern ────────────────────────────────────────────────────────────

class MistakePattern {
  final String concept;
  int frequency;
  DateTime lastSeen;
  final List<String> examples;

  MistakePattern({
    required this.concept,
    required this.frequency,
    required this.lastSeen,
    required this.examples,
  });

  Map<String, dynamic> toJson() => {
        'concept': concept,
        'frequency': frequency,
        'lastSeen': lastSeen.toIso8601String(),
        'examples': examples,
      };

  factory MistakePattern.fromJson(Map<String, dynamic> j) => MistakePattern(
        concept: j['concept'] as String,
        frequency: (j['frequency'] as num).toInt(),
        lastSeen: DateTime.parse(j['lastSeen'] as String),
        examples: List<String>.from(j['examples'] as List? ?? []),
      );
}

// ── LongTermMemory ────────────────────────────────────────────────────────────
//
// Persisted cross-session student knowledge profile.
// Updated incrementally after each session.

class LongTermMemory {
  static const _key = 'cognitive_long_term_v2';

  KeyValueStorage? _storage;

  final Map<String, SubjectMastery> _masteryMap = {};
  final List<MistakePattern> _mistakes = [];
  final Map<String, double> _learningStyles = {}; // style → success rate
  final List<double> _motivationTrend = []; // last 20 sessions
  final List<String> _successfulStrategies = [];
  final List<String> _failedStrategies = [];

  double examReadiness = 0.5;
  String? favoriteAnalogyDomain; // e.g. "futbol", "müzik"

  // ── Accessors ──────────────────────────────────────────────────────────────

  List<SubjectMastery> get masteryList =>
      _masteryMap.values.toList()..sort((a, b) => b.score.compareTo(a.score));
  List<MistakePattern> get recurringMistakes =>
      (_mistakes.toList()..sort((a, b) => b.frequency.compareTo(a.frequency)))
          .take(10)
          .toList();
  List<double> get motivationTrend => List.unmodifiable(_motivationTrend);
  List<String> get successfulStrategies => List.unmodifiable(_successfulStrategies);
  List<String> get failedStrategies => List.unmodifiable(_failedStrategies);
  double get avgMotivation => _motivationTrend.isEmpty
      ? 0.5
      : _motivationTrend.reduce((a, b) => a + b) / _motivationTrend.length;

  // ── Init / Persistence ────────────────────────────────────────────────────

  Future<void> init(KeyValueStorage storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      try {
        _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[LongTermMemory] parse error: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_storage == null) return;
    await _storage!.saveSetting(_key, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'mastery': _masteryMap.values.map((m) => m.toJson()).toList(),
        'mistakes': _mistakes.map((m) => m.toJson()).toList(),
        'learningStyles': _learningStyles,
        'motivationTrend': _motivationTrend,
        'successfulStrategies': _successfulStrategies,
        'failedStrategies': _failedStrategies,
        'examReadiness': examReadiness,
        'favoriteAnalogyDomain': favoriteAnalogyDomain,
      };

  void _loadFromJson(Map<String, dynamic> j) {
    final mastery = j['mastery'] as List<dynamic>? ?? [];
    for (final m in mastery) {
      final sm = SubjectMastery.fromJson(m as Map<String, dynamic>);
      _masteryMap[sm.subject] = sm;
    }
    final mistakes = j['mistakes'] as List<dynamic>? ?? [];
    for (final m in mistakes) {
      _mistakes.add(MistakePattern.fromJson(m as Map<String, dynamic>));
    }
    final ls = j['learningStyles'] as Map<String, dynamic>? ?? {};
    ls.forEach((k, v) => _learningStyles[k] = (v as num).toDouble());
    final mt = j['motivationTrend'] as List<dynamic>? ?? [];
    _motivationTrend.addAll(mt.map((e) => (e as num).toDouble()));
    _successfulStrategies.addAll(
        List<String>.from(j['successfulStrategies'] as List? ?? []));
    _failedStrategies.addAll(
        List<String>.from(j['failedStrategies'] as List? ?? []));
    examReadiness = (j['examReadiness'] as num?)?.toDouble() ?? 0.5;
    favoriteAnalogyDomain = j['favoriteAnalogyDomain'] as String?;
  }

  // ── Mutation API ──────────────────────────────────────────────────────────

  /// delta: positive = improvement, negative = regression. Clamped to [0, 1].
  Future<void> updateSubjectMastery(String subject, double delta) async {
    final existing = _masteryMap[subject];
    if (existing != null) {
      existing.score = (existing.score + delta).clamp(0.0, 1.0);
      existing.sessionCount++;
      existing.lastUpdated = DateTime.now();
    } else {
      _masteryMap[subject] = SubjectMastery(
        subject: subject,
        score: (0.5 + delta).clamp(0.0, 1.0),
        sessionCount: 1,
        lastUpdated: DateTime.now(),
      );
    }
    await _save();
  }

  Future<void> recordMistake(String concept, {String? example}) async {
    final existing = _mistakes.where((m) => m.concept == concept).firstOrNull;
    if (existing != null) {
      existing.frequency++;
      existing.lastSeen = DateTime.now();
      if (example != null && !existing.examples.contains(example)) {
        if (existing.examples.length >= 3) existing.examples.removeAt(0);
        existing.examples.add(example);
      }
    } else {
      _mistakes.add(MistakePattern(
        concept: concept,
        frequency: 1,
        lastSeen: DateTime.now(),
        examples: example != null ? [example] : [],
      ));
    }
    await _save();
  }

  Future<void> recordLearningStyle(String style, bool success) async {
    final current = _learningStyles[style] ?? 0.5;
    _learningStyles[style] = success ? current * 0.8 + 0.2 : current * 0.85;
    await _save();
  }

  Future<void> recordMotivation(double score) async {
    _motivationTrend.add(score.clamp(0.0, 1.0));
    if (_motivationTrend.length > 20) _motivationTrend.removeAt(0);
    await _save();
  }

  Future<void> recordStrategy(String strategy, bool success) async {
    if (success) {
      if (!_successfulStrategies.contains(strategy)) {
        _successfulStrategies.add(strategy);
        if (_successfulStrategies.length > 15) _successfulStrategies.removeAt(0);
      }
    } else {
      if (!_failedStrategies.contains(strategy)) {
        _failedStrategies.add(strategy);
        if (_failedStrategies.length > 10) _failedStrategies.removeAt(0);
      }
    }
    await _save();
  }

  Future<void> updateExamReadiness(double score) async {
    examReadiness = score.clamp(0.0, 1.0);
    await _save();
  }

  // ── Prompt block ──────────────────────────────────────────────────────────

  String buildLongTermBlock() {
    if (_masteryMap.isEmpty && _mistakes.isEmpty) return '';

    final sb = StringBuffer('\n## Uzun Süreli Öğrenci Profili\n');

    // Mastery
    final strong = masteryList.where((m) => m.score >= 0.6).take(3).toList();
    final weak = masteryList.reversed
        .where((m) => m.score < 0.5)
        .take(3)
        .toList();
    if (strong.isNotEmpty) {
      sb.writeln(
          'Güçlü konular: ${strong.map((m) => '${m.subject}(${m.strengthLabel})').join(', ')}');
    }
    if (weak.isNotEmpty) {
      sb.writeln(
          'Zayıf konular: ${weak.map((m) => '${m.subject}(${m.strengthLabel})').join(', ')}');
    }

    // Recurring mistakes
    final topMistakes = recurringMistakes.take(4).toList();
    if (topMistakes.isNotEmpty) {
      sb.writeln(
          'Tekrar eden hatalar: ${topMistakes.map((m) => '${m.concept}(×${m.frequency})').join(', ')}');
    }

    // Learning style
    if (_learningStyles.isNotEmpty) {
      final best = _learningStyles.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      sb.writeln('En başarılı öğrenme stili: ${best.key}');
    }

    // Exam readiness
    final readinessLabel = examReadiness >= 0.8
        ? 'sınava hazır'
        : examReadiness >= 0.5
            ? 'gelişiyor'
            : 'henüz hazır değil';
    sb.writeln(
        'Sınav hazırlığı: $readinessLabel (${(examReadiness * 100).round()}%)');

    // Motivation trend
    if (_motivationTrend.length >= 3) {
      final trend = _motivationTrend.reversed.take(5).toList();
      final avg = trend.reduce((a, b) => a + b) / trend.length;
      sb.writeln(
          'Motivasyon trendi: ${avg >= 0.7 ? "yüksek" : avg >= 0.4 ? "orta" : "düşük"} (son ${trend.length} oturum ort. ${(avg * 100).round()}%)');
    }

    // Strategies
    if (_successfulStrategies.isNotEmpty) {
      sb.writeln(
          'İşe yarayan stratejiler: ${_successfulStrategies.reversed.take(3).join(', ')}');
    }
    if (_failedStrategies.isNotEmpty) {
      sb.writeln(
          'İşe yaramayan stratejiler: ${_failedStrategies.reversed.take(2).join(', ')}');
    }

    if (favoriteAnalogyDomain != null) {
      sb.writeln('Favori benzetme alanı: $favoriteAnalogyDomain');
    }

    return sb.toString();
  }
}
