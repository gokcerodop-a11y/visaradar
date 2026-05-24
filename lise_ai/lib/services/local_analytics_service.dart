import '../models/student_profile.dart';

// ── SubjectInsight ─────────────────────────────────────────────────────────────

class SubjectInsight {
  final String subject;
  final double avgSuccess;   // 0.0 – 1.0
  final int interactionCount;

  const SubjectInsight({
    required this.subject,
    required this.avgSuccess,
    required this.interactionCount,
  });

  String get strengthLabel {
    if (avgSuccess >= 0.80) return 'Kuvvetli';
    if (avgSuccess >= 0.60) return 'Gelişiyor';
    if (avgSuccess >= 0.40) return 'Çalışılıyor';
    return 'Zayıf';
  }
}

// ── AnalyticsReport ───────────────────────────────────────────────────────────

class AnalyticsReport {
  final List<SubjectInsight> subjectInsights;  // sorted by avgSuccess desc
  final double overallAvgSuccess;
  final double hintDependency;            // ratio of interactions with hints
  final double confidenceTrend;           // positive = improving (−1 to +1)
  final double studyConsistency;          // weekly days active / 7
  final int totalSolvedQuestions;
  final int avgDailyMinutes;

  const AnalyticsReport({
    required this.subjectInsights,
    required this.overallAvgSuccess,
    required this.hintDependency,
    required this.confidenceTrend,
    required this.studyConsistency,
    required this.totalSolvedQuestions,
    required this.avgDailyMinutes,
  });

  List<SubjectInsight> get strongestSubjects =>
      subjectInsights.where((s) => s.avgSuccess >= 0.70).toList();

  List<SubjectInsight> get weakestSubjects =>
      subjectInsights.where((s) => s.avgSuccess < 0.50).toList();
}

// ── LocalAnalyticsService ─────────────────────────────────────────────────────

class LocalAnalyticsService {
  LocalAnalyticsService._();

  /// Derive an AnalyticsReport from the student's interaction history.
  static AnalyticsReport compute(
    StudentProfile profile, {
    double weeklyConsistency = 0.0,
  }) {
    final records = profile.recentHistory;

    // ── Subject insights ──────────────────────────────────────────────────────
    final subjectMap = <String, List<InteractionRecord>>{};
    for (final r in records) {
      subjectMap.putIfAbsent(r.topic, () => []).add(r);
    }

    final insights = subjectMap.entries.map((e) {
      final list = e.value;
      final avg = list.isEmpty
          ? 0.5
          : list.map((r) => r.successEstimate).reduce((a, b) => a + b) /
              list.length;
      return SubjectInsight(
        subject: e.key,
        avgSuccess: avg,
        interactionCount: list.length,
      );
    }).toList()
      ..sort((a, b) => b.avgSuccess.compareTo(a.avgSuccess));

    // ── Overall stats ─────────────────────────────────────────────────────────
    final overallAvg = records.isEmpty
        ? 0.5
        : records.map((r) => r.successEstimate).reduce((a, b) => a + b) /
            records.length;

    final hintCount = records.where((r) => r.usedHints).length;
    final hintDep =
        records.isEmpty ? 0.0 : hintCount / records.length;

    // Confidence trend: compare first half vs second half of interactions
    double confTrend = 0.0;
    if (records.length >= 6) {
      final mid = records.length ~/ 2;
      final firstHalf = records.sublist(0, mid);
      final secondHalf = records.sublist(mid);
      final firstAvg = firstHalf.map((r) => r.successEstimate).reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.map((r) => r.successEstimate).reduce((a, b) => a + b) / secondHalf.length;
      confTrend = (secondAvg - firstAvg).clamp(-1.0, 1.0);
    }

    // Average daily study minutes (last 14 days)
    final today = DateTime.now();
    int totalMinutes = 0;
    int activeDays = 0;
    for (var i = 0; i < 14; i++) {
      final d = today.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final mins = profile.dailyStudyMinutes[key] ?? 0;
      if (mins > 0) {
        totalMinutes += mins;
        activeDays++;
      }
    }
    final avgMins = activeDays > 0 ? totalMinutes ~/ activeDays : 0;

    return AnalyticsReport(
      subjectInsights: insights,
      overallAvgSuccess: overallAvg,
      hintDependency: hintDep,
      confidenceTrend: confTrend,
      studyConsistency: weeklyConsistency,
      totalSolvedQuestions: profile.solvedQuestionCount,
      avgDailyMinutes: avgMins,
    );
  }
}
