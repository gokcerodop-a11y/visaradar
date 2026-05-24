import '../models/learning_journal.dart';
import '../models/teacher_identity.dart';
import 'storage_service.dart';

// ── LearningJournalService ────────────────────────────────────────────────────
//
// Persists and queries the LearningJournal.
// Records breakthroughs, struggles, milestones, and homework.
// Provides prompt blocks and readiness assessments.

class LearningJournalService {
  static const _key = 'learning_journal_v1';

  LearningJournal _journal = LearningJournal();
  late StorageService _storage;

  LearningJournal get journal => _journal;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      _journal = LearningJournal.fromJsonString(raw);
    }
  }

  Future<void> _save() =>
      _storage.saveSetting(_key, _journal.toJsonString());

  // ── Recording ─────────────────────────────────────────────────────────────

  /// Auto-classify and record a journal entry from interaction data.
  Future<void> recordInteraction({
    required String topic,
    required double successEstimate,
    required bool usedHints,
    required int frustrationStreak,
  }) async {
    MomentType type;
    String note;

    if (successEstimate >= 0.85 && !usedHints) {
      type = MomentType.breakthrough;
      note = '$topic konusunda harika performans';
    } else if (successEstimate < 0.35 || frustrationStreak >= 3) {
      type = MomentType.struggle;
      note = '$topic konusunda zorluk yaşandı';
    } else if (successEstimate >= 0.70) {
      type = MomentType.milestone;
      note = '$topic konusunda iyi ilerleme';
    } else {
      return; // Average interactions don't need journal entries
    }

    _journal.addEntry(JournalEntry(
      topic: topic,
      type: type,
      note: note,
      date: DateTime.now(),
      confidence: successEstimate,
    ));

    await _save();
  }

  Future<void> addHomework(HomeworkItem item) async {
    _journal.addHomework(item);
    await _save();
  }

  Future<void> markHomeworkDone(String id) async {
    _journal.markHomeworkDone(id);
    _journal.addEntry(JournalEntry(
      topic: _journal.homework
              .firstWhere((h) => h.id == id,
                  orElse: () => HomeworkItem(
                      id: '', topic: 'Ödev', description: '',
                      assignedAt: DateTime.now()))
              .topic,
      type: MomentType.homeworkDone,
      note: 'Ödev tamamlandı',
      date: DateTime.now(),
      confidence: 0.7,
    ));
    await _save();
  }

  Future<void> addExamReadinessSnapshot(double score) async {
    _journal.addEntry(JournalEntry(
      topic: 'Sınav Hazırlığı',
      type: MomentType.examReadiness,
      note: 'Hazırlık skoru: ${(score * 100).round()}%',
      date: DateTime.now(),
      confidence: score,
    ));
    await _save();
  }

  // ── Homework homework check ────────────────────────────────────────────────

  /// Natural language homework check prompt for teacher to use.
  String? buildHomeworkCheckPrompt(TeacherIdentity teacher) {
    final pending = _journal.pendingHomework;
    if (pending.isEmpty) return null;

    final overdue = _journal.overdueHomework;
    final item = overdue.isNotEmpty ? overdue.first : pending.first;

    if (overdue.isNotEmpty) {
      return '[ÖDEV KONTROL]\n'
          '${teacher.teacherName}: "${item.topic}" konusunda verdiğim ödevi yaptın mı? '
          '"${item.description}" — bunu kontrol edelim.';
    }
    return '[ÖDEV KONTROL]\n'
        '${teacher.teacherName}: Geçen seferden ödevi hatırlıyor musun? '
        '"${item.description}" — bir bak bakalım.';
  }

  // ── Prompt block ───────────────────────────────────────────────────────────

  String buildPrompt() => _journal.buildJournalBlock();
}
