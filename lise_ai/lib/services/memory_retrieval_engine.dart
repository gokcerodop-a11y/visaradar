import 'episodic_memory.dart';
import 'long_term_memory.dart';
import 'semantic_memory.dart';
import 'short_term_memory.dart';
import 'working_memory.dart';

// ── MemoryQuery ───────────────────────────────────────────────────────────────

class MemoryQuery {
  final String currentTopic;
  final String? currentQuestion;
  final List<String> recentTopics;

  const MemoryQuery({
    required this.currentTopic,
    this.currentQuestion,
    this.recentTopics = const [],
  });
}

// ── RetrievedMemory ───────────────────────────────────────────────────────────

class RetrievedMemory {
  final List<Episode> relevantEpisodes;
  final List<MistakePattern> relevantMistakes;
  final List<AnalogyRecord> suggestedAnalogies;
  final List<String> prerequisiteTopics;
  final List<MisconceptionRecord> knownMisconceptions;
  final String? priorSuccessHint;
  final bool hasRelevantHistory;

  const RetrievedMemory({
    required this.relevantEpisodes,
    required this.relevantMistakes,
    required this.suggestedAnalogies,
    required this.prerequisiteTopics,
    required this.knownMisconceptions,
    this.priorSuccessHint,
    required this.hasRelevantHistory,
  });

  static const empty = RetrievedMemory(
    relevantEpisodes: [],
    relevantMistakes: [],
    suggestedAnalogies: [],
    prerequisiteTopics: [],
    knownMisconceptions: [],
    hasRelevantHistory: false,
  );
}

// ── MemoryRetrievalEngine ─────────────────────────────────────────────────────
//
// Contextually retrieves the most relevant memories given the current topic.
// NOT random dumping — prioritizes:
//   1. Recent episodes about this exact topic
//   2. Recurring mistakes for this concept
//   3. Best analogies that worked
//   4. Known misconceptions to avoid repeating wrong frames
//   5. Prerequisite topics as scaffolding context
//
// Future: replace keyword matching with vector similarity search (RAG).

class MemoryRetrievalEngine {
  RetrievedMemory retrieve(
    MemoryQuery query, {
    required EpisodicMemory episodic,
    required LongTermMemory longTerm,
    required SemanticMemory semantic,
    required ShortTermMemory shortTerm,
    required WorkingMemory working,
  }) {
    final topic = query.currentTopic;

    // Episodes relevant to this topic
    final episodes = episodic.relevantTo(topic, maxResults: 3);

    // Mistakes relevant to this topic
    final mistakes = longTerm.recurringMistakes
        .where((m) {
          final lower = topic.toLowerCase();
          return m.concept.toLowerCase().contains(lower) ||
              lower.contains(m.concept.toLowerCase());
        })
        .take(3)
        .toList();

    // Analogies
    final analogies = semantic.getBestAnalogies(topic, max: 2);

    // Prerequisites
    final prereqs = semantic.getPrerequisites(topic);

    // Misconceptions
    final misconceptions = semantic.getActiveMisconceptions(topic);

    // Prior success hint from mastery map
    final mastery = longTerm.masteryList
        .where((m) => m.score >= 0.7 && m.subject.toLowerCase().contains(topic.toLowerCase()))
        .firstOrNull;
    final successHint = mastery != null
        ? '${mastery.subject} konusunda daha önce başarılı olmuştu (${mastery.strengthLabel})'
        : null;

    final hasHistory = episodes.isNotEmpty ||
        mistakes.isNotEmpty ||
        misconceptions.isNotEmpty;

    return RetrievedMemory(
      relevantEpisodes: episodes,
      relevantMistakes: mistakes,
      suggestedAnalogies: analogies,
      prerequisiteTopics: prereqs,
      knownMisconceptions: misconceptions,
      priorSuccessHint: successHint,
      hasRelevantHistory: hasHistory,
    );
  }

  /// Build a teacher-voice prompt block from retrieved memory.
  /// Keeps it compact — teacher references naturally, not robotically.
  String buildRetrievalBlock(RetrievedMemory memory) {
    if (!memory.hasRelevantHistory &&
        memory.suggestedAnalogies.isEmpty &&
        memory.prerequisiteTopics.isEmpty) {
      return '';
    }

    final sb = StringBuffer('\n## Bellek Geri Çağırma\n');
    sb.writeln('(Bu bilgileri doğal konuşma anlarında kullan — düz liste olarak okuma)');

    if (memory.relevantEpisodes.isNotEmpty) {
      sb.writeln('Hatırlanan anlar:');
      for (final ep in memory.relevantEpisodes) {
        sb.writeln('  - ${ep.timeAgoTr}: ${ep.description} [${ep.type.label}]');
      }
    }

    if (memory.relevantMistakes.isNotEmpty) {
      sb.writeln('Daha önce yapılan hatalar (tekrar etmesini önle):');
      for (final m in memory.relevantMistakes) {
        sb.writeln('  - "${m.concept}": ${m.frequency}× görüldü');
        if (m.examples.isNotEmpty) {
          sb.writeln('    Örnek: ${m.examples.last}');
        }
      }
    }

    if (memory.suggestedAnalogies.isNotEmpty) {
      sb.writeln('Daha önce işe yarayan benzetmeler:');
      for (final a in memory.suggestedAnalogies) {
        sb.writeln('  - [${a.domain}] "${a.analogyText}"');
      }
    }

    if (memory.knownMisconceptions.isNotEmpty) {
      sb.writeln('Bilinen yanlış anlamalar:');
      for (final m in memory.knownMisconceptions) {
        sb.writeln('  - "${m.misconception}" (${m.occurrences}×) → ${m.correctionApproach}');
      }
    }

    if (memory.prerequisiteTopics.isNotEmpty) {
      sb.writeln('Ön koşul konular: ${memory.prerequisiteTopics.join(', ')}');
    }

    if (memory.priorSuccessHint != null) {
      sb.writeln('Önceki başarı: ${memory.priorSuccessHint}');
    }

    return sb.toString();
  }
}
