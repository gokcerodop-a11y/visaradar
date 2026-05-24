/// NotificationEngine — architecture-only notification scheduling.
///
/// No push backend is wired yet. This service:
/// - Defines notification types and plans
/// - Stores scheduled plans in memory (and optionally persists them)
/// - Provides a contract that a future push implementation can fulfil
///
/// To add real push: implement [NotificationBackend] and inject it.
library;

// ── NotificationType ──────────────────────────────────────────────────────────

enum NotificationType {
  studyReminder,          // daily study reminder
  unfinishedLesson,       // resume unfinished session
  encouragementAfterFail, // motivational after failure streak
  examCountdown,          // N days until target exam
  streakAtRisk,           // streak about to break
  weeklyReport,           // weekly summary
}

// ── NotificationPlan ──────────────────────────────────────────────────────────

class NotificationPlan {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime scheduledFor;
  final bool repeating;
  final Duration? repeatInterval;

  const NotificationPlan({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledFor,
    this.repeating = false,
    this.repeatInterval,
  });
}

// ── NotificationBackend (interface) ───────────────────────────────────────────

/// Implement this to wire a real push SDK (e.g. flutter_local_notifications).
abstract class NotificationBackend {
  Future<void> schedule(NotificationPlan plan);
  Future<void> cancel(String id);
  Future<void> cancelAll();
}

// ── NotificationEngine ────────────────────────────────────────────────────────

class NotificationEngine {
  NotificationBackend? _backend; // null = architecture-only mode

  final List<NotificationPlan> _pending = [];

  List<NotificationPlan> get pendingPlans => List.unmodifiable(_pending);

  void attachBackend(NotificationBackend backend) {
    _backend = backend;
  }

  // ── Plan builders ────────────────────────────────────────────────────────

  NotificationPlan studyReminder({required TimeOfDay time}) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return NotificationPlan(
      id: 'study_reminder',
      type: NotificationType.studyReminder,
      title: 'Çalışma zamanı! 📚',
      body: 'Bugünkü dersini başlatmak için dokun.',
      scheduledFor: scheduled,
      repeating: true,
      repeatInterval: const Duration(days: 1),
    );
  }

  NotificationPlan unfinishedLesson({required String topic}) {
    return NotificationPlan(
      id: 'unfinished_lesson',
      type: NotificationType.unfinishedLesson,
      title: 'Kaldığın yerden devam et',
      body: '$topic konusunu yarıda bıraktın. Devam edelim!',
      scheduledFor: DateTime.now().add(const Duration(hours: 2)),
    );
  }

  NotificationPlan encouragementAfterFail({required String teacherName}) {
    return NotificationPlan(
      id: 'encouragement',
      type: NotificationType.encouragementAfterFail,
      title: '$teacherName seni bekliyor',
      body: 'Herkes bazen zorlanır. Birlikte çözeriz — hazır mısın?',
      scheduledFor: DateTime.now().add(const Duration(hours: 4)),
    );
  }

  NotificationPlan examCountdown({
    required String examName,
    required DateTime examDate,
  }) {
    final daysLeft = examDate.difference(DateTime.now()).inDays;
    return NotificationPlan(
      id: 'exam_countdown',
      type: NotificationType.examCountdown,
      title: '$examName — $daysLeft gün kaldı',
      body: 'Hedefe odaklan. Her gün bir adım daha yakınsın.',
      scheduledFor: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  NotificationPlan streakAtRisk({required int streak}) {
    return NotificationPlan(
      id: 'streak_risk',
      type: NotificationType.streakAtRisk,
      title: '$streak günlük serin tehlikede! 🔥',
      body: 'Bugün 1 soru çöz — serini kurtar.',
      scheduledFor: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  // ── Schedule / cancel ─────────────────────────────────────────────────────

  Future<void> schedule(NotificationPlan plan) async {
    _pending.removeWhere((p) => p.id == plan.id);
    _pending.add(plan);
    await _backend?.schedule(plan);
  }

  Future<void> cancel(String id) async {
    _pending.removeWhere((p) => p.id == id);
    await _backend?.cancel(id);
  }

  Future<void> cancelAll() async {
    _pending.clear();
    await _backend?.cancelAll();
  }
}

// ── TimeOfDay (minimal re-export for non-Flutter contexts) ────────────────────

class TimeOfDay {
  final int hour;
  final int minute;
  const TimeOfDay({required this.hour, required this.minute});
}
