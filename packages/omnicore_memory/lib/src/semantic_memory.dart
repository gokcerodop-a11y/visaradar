import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:omnicore_foundation/omnicore_foundation.dart' show KeyValueStorage;

// ── TopicRelationship ─────────────────────────────────────────────────────────

enum RelationshipType { prerequisite, related, application, extension }

class TopicRelationship {
  final String from;
  final String to;
  final RelationshipType type;
  double strength; // 0-1

  TopicRelationship({
    required this.from,
    required this.to,
    required this.type,
    this.strength = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'type': type.name,
        'strength': strength,
      };

  factory TopicRelationship.fromJson(Map<String, dynamic> j) =>
      TopicRelationship(
        from: j['from'] as String,
        to: j['to'] as String,
        type: RelationshipType.values.firstWhere(
            (e) => e.name == j['type'],
            orElse: () => RelationshipType.related),
        strength: (j['strength'] as num?)?.toDouble() ?? 0.5,
      );
}

// ── MisconceptionRecord ───────────────────────────────────────────────────────

class MisconceptionRecord {
  final String concept;
  final String misconception;
  final String correctionApproach;
  bool resolved;
  int occurrences;

  MisconceptionRecord({
    required this.concept,
    required this.misconception,
    required this.correctionApproach,
    this.resolved = false,
    this.occurrences = 1,
  });

  Map<String, dynamic> toJson() => {
        'concept': concept,
        'misconception': misconception,
        'correctionApproach': correctionApproach,
        'resolved': resolved,
        'occurrences': occurrences,
      };

  factory MisconceptionRecord.fromJson(Map<String, dynamic> j) =>
      MisconceptionRecord(
        concept: j['concept'] as String,
        misconception: j['misconception'] as String,
        correctionApproach: j['correctionApproach'] as String,
        resolved: (j['resolved'] as bool?) ?? false,
        occurrences: (j['occurrences'] as num?)?.toInt() ?? 1,
      );
}

// ── AnalogyRecord ─────────────────────────────────────────────────────────────

class AnalogyRecord {
  final String concept;
  final String analogyText;
  final String domain; // e.g. "futbol", "müzik", "yemek"
  double successRate; // 0-1, updated based on student response
  int useCount;

  AnalogyRecord({
    required this.concept,
    required this.analogyText,
    required this.domain,
    this.successRate = 0.5,
    this.useCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'concept': concept,
        'analogyText': analogyText,
        'domain': domain,
        'successRate': successRate,
        'useCount': useCount,
      };

  factory AnalogyRecord.fromJson(Map<String, dynamic> j) => AnalogyRecord(
        concept: j['concept'] as String,
        analogyText: j['analogyText'] as String,
        domain: j['domain'] as String,
        successRate: (j['successRate'] as num?)?.toDouble() ?? 0.5,
        useCount: (j['useCount'] as num?)?.toInt() ?? 0,
      );
}

// ── SemanticMemory ────────────────────────────────────────────────────────────
//
// Topic knowledge graph + analogy/explanation success tracking.
// Future: replace list-based matching with vector embeddings.

class SemanticMemory {
  static const _key = 'cognitive_semantic_v1';

  KeyValueStorage? _storage;

  final List<TopicRelationship> _relationships = [];
  final List<MisconceptionRecord> _misconceptions = [];
  final List<AnalogyRecord> _analogies = [];
  final Map<String, String> _bestExplanationStyle = {}; // concept → style

  List<MisconceptionRecord> get misconceptions => List.unmodifiable(_misconceptions);
  List<AnalogyRecord> get analogies => List.unmodifiable(_analogies);

  Future<void> init(KeyValueStorage storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      try {
        _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[SemanticMemory] parse error: $e');
      }
    }
    // Seed default topic graph if empty
    if (_relationships.isEmpty) _seedDefaultGraph();
  }

  void _seedDefaultGraph() {
    final defaults = [
      ('Temel Cebir', 'İkinci Derece Denklemler', RelationshipType.prerequisite),
      ('İkinci Derece Denklemler', 'Fonksiyonlar', RelationshipType.prerequisite),
      ('Trigonometri', 'Vektörler', RelationshipType.related),
      ('Türev', 'İntegral', RelationshipType.prerequisite),
      ('Olasılık', 'İstatistik', RelationshipType.related),
    ];
    for (final (from, to, type) in defaults) {
      _relationships.add(TopicRelationship(from: from, to: to, type: type, strength: 0.9));
    }
  }

  Future<void> _save() async {
    if (_storage == null) return;
    await _storage!.saveSetting(_key, jsonEncode({
      'relationships': _relationships.map((r) => r.toJson()).toList(),
      'misconceptions': _misconceptions.map((m) => m.toJson()).toList(),
      'analogies': _analogies.map((a) => a.toJson()).toList(),
      'bestExplanationStyle': _bestExplanationStyle,
    }));
  }

  void _loadFromJson(Map<String, dynamic> j) {
    final rels = j['relationships'] as List<dynamic>? ?? [];
    _relationships.addAll(rels.map((r) => TopicRelationship.fromJson(r as Map<String, dynamic>)));
    final misc = j['misconceptions'] as List<dynamic>? ?? [];
    _misconceptions.addAll(misc.map((m) => MisconceptionRecord.fromJson(m as Map<String, dynamic>)));
    final anals = j['analogies'] as List<dynamic>? ?? [];
    _analogies.addAll(anals.map((a) => AnalogyRecord.fromJson(a as Map<String, dynamic>)));
    final styles = j['bestExplanationStyle'] as Map<String, dynamic>? ?? {};
    styles.forEach((k, v) => _bestExplanationStyle[k] = v as String);
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<String> getPrerequisites(String topic) {
    final lower = topic.toLowerCase();
    return _relationships
        .where((r) =>
            r.to.toLowerCase().contains(lower) &&
            r.type == RelationshipType.prerequisite)
        .map((r) => r.from)
        .toList();
  }

  List<String> getRelatedTopics(String topic) {
    final lower = topic.toLowerCase();
    return _relationships
        .where((r) =>
            (r.from.toLowerCase().contains(lower) ||
                r.to.toLowerCase().contains(lower)) &&
            r.type == RelationshipType.related)
        .map((r) => r.from.toLowerCase().contains(lower) ? r.to : r.from)
        .take(3)
        .toList();
  }

  List<AnalogyRecord> getBestAnalogies(String concept, {int max = 2}) {
    final lower = concept.toLowerCase();
    final matching = _analogies
        .where((a) => a.concept.toLowerCase().contains(lower))
        .toList()
      ..sort((a, b) => b.successRate.compareTo(a.successRate));
    return matching.take(max).toList();
  }

  List<MisconceptionRecord> getActiveMisconceptions(String concept) {
    final lower = concept.toLowerCase();
    return _misconceptions
        .where((m) =>
            !m.resolved && m.concept.toLowerCase().contains(lower))
        .toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> recordAnalogyOutcome(
      String concept, String analogyText, String domain, bool success) async {
    final existing = _analogies
        .where((a) => a.concept == concept && a.analogyText == analogyText)
        .firstOrNull;
    if (existing != null) {
      existing.useCount++;
      existing.successRate = success
          ? existing.successRate * 0.7 + 0.3
          : existing.successRate * 0.85;
    } else {
      _analogies.add(AnalogyRecord(
        concept: concept,
        analogyText: analogyText,
        domain: domain,
        successRate: success ? 0.75 : 0.35,
        useCount: 1,
      ));
    }
    await _save();
  }

  Future<void> recordMisconception(
      String concept, String misconception, String correctionApproach) async {
    final existing = _misconceptions
        .where((m) => m.concept == concept && m.misconception == misconception)
        .firstOrNull;
    if (existing != null) {
      existing.occurrences++;
    } else {
      _misconceptions.add(MisconceptionRecord(
        concept: concept,
        misconception: misconception,
        correctionApproach: correctionApproach,
      ));
    }
    await _save();
  }

  Future<void> markMisconceptionResolved(String concept, String misconception) async {
    final existing = _misconceptions
        .where((m) => m.concept == concept && m.misconception == misconception)
        .firstOrNull;
    if (existing != null) {
      existing.resolved = true;
      await _save();
    }
  }

  Future<void> recordBestExplanationStyle(String concept, String style) async {
    _bestExplanationStyle[concept] = style;
    await _save();
  }

  // ── Prompt block ──────────────────────────────────────────────────────────

  String buildSemanticBlock(String currentTopic) {
    if (currentTopic.isEmpty) return '';

    final sb = StringBuffer('\n## Anlamsal Bellek ($currentTopic)\n');
    bool hasContent = false;

    final prereqs = getPrerequisites(currentTopic);
    if (prereqs.isNotEmpty) {
      sb.writeln('Ön koşul konular: ${prereqs.join(', ')}');
      hasContent = true;
    }

    final related = getRelatedTopics(currentTopic);
    if (related.isNotEmpty) {
      sb.writeln('İlgili konular: ${related.join(', ')}');
      hasContent = true;
    }

    final bestAnalogies = getBestAnalogies(currentTopic);
    if (bestAnalogies.isNotEmpty) {
      sb.writeln('İşe yarayan benzetmeler:');
      for (final a in bestAnalogies) {
        sb.writeln('  - [${a.domain}] ${a.analogyText} (başarı: ${(a.successRate * 100).round()}%)');
      }
      hasContent = true;
    }

    final activeMisconceptions = getActiveMisconceptions(currentTopic);
    if (activeMisconceptions.isNotEmpty) {
      sb.writeln('Bilinen yanlış kavramalar:');
      for (final m in activeMisconceptions.take(3)) {
        sb.writeln('  - "${m.misconception}" → Düzeltme: ${m.correctionApproach}');
      }
      hasContent = true;
    }

    final style = _bestExplanationStyle[currentTopic];
    if (style != null) {
      sb.writeln('En başarılı açıklama stili: $style');
      hasContent = true;
    }

    if (!hasContent) return '';
    return sb.toString();
  }
}
