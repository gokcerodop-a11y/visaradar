import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'anthropic_service.dart';
import 'episodic_memory.dart';
import 'long_term_memory.dart';
import 'short_term_memory.dart';

// ── SessionSummary ────────────────────────────────────────────────────────────

class SessionSummary {
  final String keyInsights;
  final List<String> resolvedConcepts;
  final List<String> unresolvedConcepts;
  final double estimatedProgress; // 0-1
  final String teacherNote;
  final DateTime createdAt;

  const SessionSummary({
    required this.keyInsights,
    required this.resolvedConcepts,
    required this.unresolvedConcepts,
    required this.estimatedProgress,
    required this.teacherNote,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'keyInsights': keyInsights,
        'resolvedConcepts': resolvedConcepts,
        'unresolvedConcepts': unresolvedConcepts,
        'estimatedProgress': estimatedProgress,
        'teacherNote': teacherNote,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        keyInsights: j['keyInsights'] as String,
        resolvedConcepts:
            List<String>.from(j['resolvedConcepts'] as List? ?? []),
        unresolvedConcepts:
            List<String>.from(j['unresolvedConcepts'] as List? ?? []),
        estimatedProgress:
            (j['estimatedProgress'] as num?)?.toDouble() ?? 0.5,
        teacherNote: j['teacherNote'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  factory SessionSummary.fallback(List<ShortTermTurn> turns) {
    final userCount = turns.where((t) => t.role == 'user').length;
    return SessionSummary(
      keyInsights: '$userCount etkileşimli oturum tamamlandı.',
      resolvedConcepts: [],
      unresolvedConcepts: [],
      estimatedProgress: 0.5,
      teacherNote: 'Oturum özeti mevcut değil.',
      createdAt: DateTime.now(),
    );
  }
}

// ── MemorySummarizer ──────────────────────────────────────────────────────────
//
// Uses Claude to compress sessions and episodes into compact reusable summaries.
// Called at session end or when memory is nearing capacity.
//
// Future hooks:
// - Batch summarization for >7 day old episodes
// - Topic-specific mastery reports
// - Cross-session pattern detection

class MemorySummarizer {
  final AnthropicService _anthropic;

  static const _systemPrompt = '''
Sen bir Türk lise öğrencisiyle çalışan yapay zeka öğretmeninin bellek özetleme asistanısın.
Oturum verilerini kısa, yapılandırılmış JSON formatına dönüştür.
Sadece JSON döndür — açıklama ekleme.
''';

  MemorySummarizer(this._anthropic);

  // ── Session summarization ─────────────────────────────────────────────────

  /// Summarize a completed session into reusable insights.
  /// Returns a SessionSummary with key points Claude extracted.
  Future<SessionSummary> summarizeSession(
    List<ShortTermTurn> turns,
    LongTermMemory longTerm, {
    String? topic,
  }) async {
    if (turns.isEmpty) return SessionSummary.fallback(turns);

    try {
      final transcript = turns
          .map((t) =>
              '${t.role == "user" ? "Öğrenci" : "Öğretmen"}: ${t.text}')
          .join('\n');

      final prompt = '''
Bu oturum transkriptini analiz et ve JSON döndür:

Transkript:
$transcript

${topic != null ? 'Konu: $topic' : ''}

JSON format:
{
  "keyInsights": "2-3 cümle: bu oturumda ne öğrenildi?",
  "resolvedConcepts": ["kavram1", "kavram2"],
  "unresolvedConcepts": ["kavram3"],
  "estimatedProgress": 0.0-1.0,
  "teacherNote": "Öğretmen notu: öğrencinin bu oturumdaki performansı"
}

Sadece JSON.''';

      final history = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt}
          ],
        }
      ];

      final buf = StringBuffer();
      await for (final token in _anthropic.streamMessage(
        history,
        systemPrompt: _systemPrompt,
        maxTokens: 512,
      )) {
        buf.write(token);
      }

      final raw = buf.toString().trim();
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return SessionSummary.fallback(turns);

      final j = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SessionSummary(
        keyInsights: j['keyInsights'] as String? ?? '',
        resolvedConcepts:
            List<String>.from(j['resolvedConcepts'] as List? ?? []),
        unresolvedConcepts:
            List<String>.from(j['unresolvedConcepts'] as List? ?? []),
        estimatedProgress:
            (j['estimatedProgress'] as num?)?.toDouble() ?? 0.5,
        teacherNote: j['teacherNote'] as String? ?? '',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[MemorySummarizer] summarizeSession error: $e');
      return SessionSummary.fallback(turns);
    }
  }

  // ── Episode summarization ─────────────────────────────────────────────────

  /// Compress a list of episodes into a single narrative summary string.
  /// Used when episodic memory exceeds capacity.
  Future<String> summarizeEpisodes(List<Episode> episodes) async {
    if (episodes.isEmpty) return '';

    try {
      final descriptions = episodes
          .map((e) =>
              '- ${e.timeAgoTr}: [${e.type.label}] ${e.title}: ${e.description}')
          .join('\n');

      final prompt = '''
Bu öğrencinin önemli öğrenme anlarını 3-4 cümlede özetle. Türkçe yaz.
Öğretmen sesiyle, birinci şahıs çoğul kullan (biz, seninle, birlikte).

Anlar:
$descriptions

Özet:''';

      final history = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt}
          ],
        }
      ];

      final buf = StringBuffer();
      await for (final token in _anthropic.streamMessage(
        history,
        systemPrompt: _systemPrompt,
        maxTokens: 256,
      )) {
        buf.write(token);
      }

      return buf.toString().trim();
    } catch (e) {
      debugPrint('[MemorySummarizer] summarizeEpisodes error: $e');
      return episodes.map((e) => e.title).join(', ');
    }
  }

  // ── Pattern detection ─────────────────────────────────────────────────────

  /// Detect repeated patterns from long-term mistake data.
  /// Returns a 1-2 sentence insight string for the prompt.
  String detectMistakePattern(LongTermMemory longTerm) {
    final top = longTerm.recurringMistakes.take(3).toList();
    if (top.isEmpty) return '';
    final concepts =
        top.map((m) => '${m.concept}(×${m.frequency})').join(', ');
    return 'Tekrar eden hata kalıpları: $concepts — bu kavramlara özellikle dikkat et.';
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static String? _extractJson(String raw) {
    if (raw.startsWith('{')) return raw;
    final fence = RegExp(r'```(?:json)?\s*([\s\S]+?)\s*```');
    final m = fence.firstMatch(raw);
    if (m != null) return m.group(1);
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end > start) return raw.substring(start, end + 1);
    return null;
  }
}
