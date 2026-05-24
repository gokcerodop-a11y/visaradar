import 'dart:convert';

// ── Journal moment types ──────────────────────────────────────────────────────

enum MomentType {
  breakthrough,    // "finally got it"
  struggle,        // repeated difficulty
  milestone,       // topic mastered
  funMoment,       // student enjoyed a lesson
  examReadiness,   // readiness snapshot
  homeworkDone,    // completed assignment
  homeworkMissed,  // missed assignment
}

// ── Homework item ─────────────────────────────────────────────────────────────

class HomeworkItem {
  final String id;
  final String topic;
  final String description;
  final DateTime assignedAt;
  bool isCompleted;
  DateTime? completedAt;

  HomeworkItem({
    required this.id,
    required this.topic,
    required this.description,
    required this.assignedAt,
    this.isCompleted = false,
    this.completedAt,
  });

  bool get isOverdue =>
      !isCompleted &&
      DateTime.now().difference(assignedAt).inHours > 48;

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'description': description,
        'assignedAt': assignedAt.millisecondsSinceEpoch,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.millisecondsSinceEpoch,
      };

  factory HomeworkItem.fromJson(Map<String, dynamic> j) => HomeworkItem(
        id: j['id'] as String,
        topic: j['topic'] as String? ?? '',
        description: j['description'] as String? ?? '',
        assignedAt: DateTime.fromMillisecondsSinceEpoch(
            j['assignedAt'] as int? ?? 0),
        isCompleted: j['isCompleted'] as bool? ?? false,
        completedAt: j['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['completedAt'] as int)
            : null,
      );
}

// ── Journal entry ─────────────────────────────────────────────────────────────

class JournalEntry {
  final String topic;
  final MomentType type;
  final String note;
  final DateTime date;
  final double confidence; // 0–1 at this moment

  const JournalEntry({
    required this.topic,
    required this.type,
    required this.note,
    required this.date,
    this.confidence = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'type': type.name,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'confidence': confidence,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        topic: j['topic'] as String? ?? '',
        type: MomentType.values.firstWhere(
            (v) => v.name == j['type'],
            orElse: () => MomentType.struggle),
        note: j['note'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(
            j['date'] as int? ?? 0),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.5,
      );
}

// ── Learning journal ──────────────────────────────────────────────────────────

class LearningJournal {
  final List<JournalEntry> entries;
  final Map<String, double> subjectConfidence; // subject → avg confidence
  final List<HomeworkItem> homework;
  double examReadinessScore; // 0–1 rolling average

  LearningJournal({
    List<JournalEntry>? entries,
    Map<String, double>? subjectConfidence,
    List<HomeworkItem>? homework,
    this.examReadinessScore = 0.5,
  })  : entries = entries ?? [],
        subjectConfidence = subjectConfidence ?? {},
        homework = homework ?? [];

  // ── Mutations ──────────────────────────────────────────────────────────────

  void addEntry(JournalEntry entry) {
    entries.add(entry);
    // Keep last 200 entries
    if (entries.length > 200) entries.removeAt(0);

    // Update subject confidence rolling average
    if (entry.confidence > 0) {
      final prev = subjectConfidence[entry.topic] ?? 0.5;
      subjectConfidence[entry.topic] = prev * 0.7 + entry.confidence * 0.3;
    }

    // Update exam readiness
    if (entry.type == MomentType.examReadiness) {
      examReadinessScore =
          examReadinessScore * 0.6 + entry.confidence * 0.4;
    }
  }

  void addHomework(HomeworkItem item) {
    homework.add(item);
    if (homework.length > 30) homework.removeAt(0);
  }

  void markHomeworkDone(String id) {
    final idx = homework.indexWhere((h) => h.id == id);
    if (idx != -1) {
      homework[idx].isCompleted = true;
      homework[idx].completedAt = DateTime.now();
    }
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  List<HomeworkItem> get pendingHomework =>
      homework.where((h) => !h.isCompleted).toList();

  List<HomeworkItem> get overdueHomework =>
      homework.where((h) => h.isOverdue).toList();

  List<JournalEntry> recentBreakthroughs({int limit = 3}) => entries
      .where((e) => e.type == MomentType.breakthrough)
      .toList()
      .reversed
      .take(limit)
      .toList();

  List<JournalEntry> recentStruggles({int limit = 3}) => entries
      .where((e) => e.type == MomentType.struggle)
      .toList()
      .reversed
      .take(limit)
      .toList();

  String? get weakestSubject {
    if (subjectConfidence.isEmpty) return null;
    return subjectConfidence.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  String? get strongestSubject {
    if (subjectConfidence.isEmpty) return null;
    return subjectConfidence.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String get readinessLabel {
    if (examReadinessScore >= 0.80) return 'Hazır';
    if (examReadinessScore >= 0.60) return 'İyi Gidiyor';
    if (examReadinessScore >= 0.40) return 'Gelişiyor';
    return 'Başlangıç';
  }

  // ── Prompt block ───────────────────────────────────────────────────────────

  String buildJournalBlock() {
    if (entries.isEmpty && homework.isEmpty) return '';

    final sb = StringBuffer();
    sb.writeln('\n[ÖĞRENME GÜNLÜĞÜ]');

    final breakthroughs = recentBreakthroughs();
    if (breakthroughs.isNotEmpty) {
      sb.writeln('Son atılımlar: ${breakthroughs.map((e) => e.topic).join(", ")}');
    }

    final struggles = recentStruggles();
    if (struggles.isNotEmpty) {
      sb.writeln('Zorlanan konular: ${struggles.map((e) => e.topic).join(", ")}');
    }

    if (weakestSubject != null) {
      sb.writeln('En zayıf konu: $weakestSubject');
    }
    if (strongestSubject != null) {
      sb.writeln('En güçlü konu: $strongestSubject');
    }

    sb.writeln('Sınav hazırlık: $readinessLabel (${(examReadinessScore * 100).round()}%)');

    final pending = pendingHomework;
    if (pending.isNotEmpty) {
      sb.writeln('Bekleyen ödevler:');
      for (final h in pending.take(3)) {
        final overdue = h.isOverdue ? ' (gecikmiş!)' : '';
        sb.writeln('  • ${h.topic}: ${h.description}$overdue');
      }
    }

    return sb.toString();
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  String toJsonString() => jsonEncode({
        'entries': entries.map((e) => e.toJson()).toList(),
        'subjectConfidence': subjectConfidence,
        'homework': homework.map((h) => h.toJson()).toList(),
        'examReadinessScore': examReadinessScore,
      });

  factory LearningJournal.fromJsonString(String s) {
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return LearningJournal(
        entries: ((j['entries'] as List?) ?? [])
            .map((e) => JournalEntry.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        subjectConfidence: Map<String, double>.from(
            (j['subjectConfidence'] as Map? ?? {}).map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()))),
        homework: ((j['homework'] as List?) ?? [])
            .map((h) => HomeworkItem.fromJson(
                Map<String, dynamic>.from(h as Map)))
            .toList(),
        examReadinessScore:
            (j['examReadinessScore'] as num?)?.toDouble() ?? 0.5,
      );
    } catch (_) {
      return LearningJournal();
    }
  }
}
