import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:omnicore_foundation/omnicore_foundation.dart' show KeyValueStorage;

// ── EpisodeType ───────────────────────────────────────────────────────────────

enum EpisodeType {
  breakthrough,       // "Anladım!" moment
  struggle,           // prolonged difficulty
  confusionResolved,  // confusion cleared up
  examSession,        // exam preparation session
  confidenceBoost,    // student gained confidence
  topicMastered,      // topic fully understood
  firstAttempt,       // first time touching a topic
}

extension EpisodeTypeExt on EpisodeType {
  String get label => switch (this) {
        EpisodeType.breakthrough      => 'Kırılma Anı',
        EpisodeType.struggle          => 'Zorlu An',
        EpisodeType.confusionResolved => 'Aydınlanma',
        EpisodeType.examSession       => 'Sınav Oturumu',
        EpisodeType.confidenceBoost   => 'Güven Artışı',
        EpisodeType.topicMastered     => 'Konu Tamamlandı',
        EpisodeType.firstAttempt      => 'İlk Deneme',
      };

  String get teacherReference => switch (this) {
        EpisodeType.breakthrough      => 'kırılma anını yaşamıştın',
        EpisodeType.struggle          => 'zorlanmıştın',
        EpisodeType.confusionResolved => 'sonunda kavramıştın',
        EpisodeType.examSession       => 'sınava çalışmıştık',
        EpisodeType.confidenceBoost   => 'çok iyi iş çıkarmıştın',
        EpisodeType.topicMastered     => 'bu konuyu bitirmiştin',
        EpisodeType.firstAttempt      => 'ilk kez denemiştin',
      };
}

// ── Episode ───────────────────────────────────────────────────────────────────

class Episode {
  final String id;
  final EpisodeType type;
  final String title;
  final String description;
  final String? topic;
  final DateTime timestamp;
  final double emotionalValence; // -1.0 (negative) to 1.0 (positive)

  const Episode({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.topic,
    required this.timestamp,
    this.emotionalValence = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'description': description,
        'topic': topic,
        'timestamp': timestamp.toIso8601String(),
        'emotionalValence': emotionalValence,
      };

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        id: j['id'] as String,
        type: EpisodeType.values.firstWhere(
            (e) => e.name == j['type'],
            orElse: () => EpisodeType.firstAttempt),
        title: j['title'] as String,
        description: j['description'] as String,
        topic: j['topic'] as String?,
        timestamp: DateTime.parse(j['timestamp'] as String),
        emotionalValence: (j['emotionalValence'] as num?)?.toDouble() ?? 0.0,
      );

  /// Human-readable "time ago" string in Turkish.
  String get timeAgoTr {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays == 0) return 'bugün';
    if (diff.inDays == 1) return 'dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta önce';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ay önce';
    return '${(diff.inDays / 365).floor()} yıl önce';
  }
}

// ── EpisodicMemory ────────────────────────────────────────────────────────────
//
// Teacher's memory of meaningful moments.
// Used to reference past struggles, victories, and key events in conversation.
//
// Example teacher phrases generated from this:
// "Geçen hafta trigonometride zorlanmıştın ama bugün çok daha iyisin."
// "İki hafta önce karekökleri de böyle tamamlamıştın — o kırılma anını hatırlıyor musun?"

class EpisodicMemory {
  static const _key = 'cognitive_episodic_v1';
  static const _maxEpisodes = 50;

  KeyValueStorage? _storage;
  final List<Episode> _episodes = [];

  List<Episode> get episodes => List.unmodifiable(_episodes);

  Future<void> init(KeyValueStorage storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _episodes.addAll(list.map((e) => Episode.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('[EpisodicMemory] parse error: $e');
      }
    }
  }

  Future<void> recordEpisode(Episode episode) async {
    _episodes.add(episode);
    // Keep most recent episodes, trim oldest if over limit
    if (_episodes.length > _maxEpisodes) {
      _episodes.removeAt(0);
    }
    await _save();
  }

  Future<void> _save() async {
    if (_storage == null) return;
    await _storage!.saveSetting(
        _key, jsonEncode(_episodes.map((e) => e.toJson()).toList()));
  }

  /// Return episodes relevant to the given topic (fuzzy string match on topic/title/description).
  List<Episode> relevantTo(String topic, {int maxResults = 3}) {
    if (topic.isEmpty) return recentEpisodes(days: 14).take(maxResults).toList();
    final lower = topic.toLowerCase();
    final scored = _episodes
        .map((e) {
          int score = 0;
          if (e.topic?.toLowerCase().contains(lower) == true) score += 3;
          if (e.title.toLowerCase().contains(lower)) score += 2;
          if (e.description.toLowerCase().contains(lower)) score += 1;
          return (e, score);
        })
        .where((pair) => pair.$2 > 0)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(maxResults).map((p) => p.$1).toList();
  }

  List<Episode> recentEpisodes({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _episodes.reversed.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  List<Episode> byType(EpisodeType type) =>
      _episodes.reversed.where((e) => e.type == type).take(5).toList();

  /// Build a teacher-voice episodic reference block for Claude.
  String buildEpisodicBlock(String currentTopic) {
    final relevant = relevantTo(currentTopic, maxResults: 3);
    final recent = recentEpisodes(days: 7);

    if (relevant.isEmpty && recent.isEmpty) return '';

    final sb = StringBuffer('\n## Öğretmenin Hatırladıkları\n');
    sb.writeln('(Bu bilgileri doğal konuşmaya ekle, robot gibi listeleme)');

    for (final ep in relevant) {
      final timeStr = ep.timeAgoTr;
      sb.writeln('- $timeStr "${ep.topic ?? ep.title}" konusunda ${ep.type.teacherReference}: ${ep.description}');
    }

    // Add recent positive episodes not already in relevant
    final recentPositive = recent
        .where((e) => e.emotionalValence > 0.3 && !relevant.contains(e))
        .take(2);
    for (final ep in recentPositive) {
      sb.writeln('- ${ep.timeAgoTr} ${ep.type.teacherReference} (${ep.title})');
    }

    return sb.toString();
  }
}
