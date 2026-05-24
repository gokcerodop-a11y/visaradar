import '../models/student_profile.dart';
import 'app_logger.dart';
import 'profile_service.dart';

/// Tracks session-level study metrics and aggregates weekly data.
///
/// Usage:
///   - Call [startSession] when the screen initializes.
///   - Call [endSession] in dispose() — it fires-and-forgets safely.
///   - Query [weeklyMinutes] / [weeklyTotal] to power the progress dashboard.
class StudyAnalyticsService {
  DateTime? _sessionStart;

  // ── Session lifecycle ──────────────────────────────────────────────────────

  void startSession() {
    _sessionStart = DateTime.now();
    AppLogger.info('Analytics', 'Study session started');
  }

  /// Persist elapsed minutes. Call from dispose() without await.
  Future<void> endSession(ProfileService profileSvc) async {
    final start = _sessionStart;
    _sessionStart = null;
    if (start == null) return;
    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes > 0) {
      await profileSvc.recordStudyMinutes(minutes);
      AppLogger.info('Analytics', 'Session ended: $minutes min');
    }
  }

  // ── Aggregation helpers ────────────────────────────────────────────────────

  /// Study minutes for the last [days] days, oldest first.
  static List<int> weeklyMinutes(StudentProfile profile, {int days = 7}) {
    final result = <int>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = _dateKey(d);
      result.add(profile.dailyStudyMinutes[key] ?? 0);
    }
    return result;
  }

  /// Total study minutes over the last 7 days.
  static int weeklyTotal(StudentProfile profile) =>
      weeklyMinutes(profile).fold(0, (a, b) => a + b);

  /// Display labels for the last 7 days (e.g. "Pzt", "Sal" …).
  static List<String> weekDayLabels() {
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return labels[(d.weekday - 1) % 7];
    });
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
