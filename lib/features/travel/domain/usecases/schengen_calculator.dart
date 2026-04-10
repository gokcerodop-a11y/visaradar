import '../../../../core/constants/app_constants.dart';
import '../entities/travel_entry.dart';

/// Result of the Schengen 90/180 calculation.
class SchengenResult {
  const SchengenResult({
    required this.daysUsed,
    required this.daysRemaining,
    required this.windowStart,
    required this.windowEnd,
    required this.riskLevel,
    required this.nextResetDate,
  });

  final int daysUsed;
  final int daysRemaining;
  final DateTime windowStart;
  final DateTime windowEnd;
  final SchengenRisk riskLevel;

  /// Earliest date at which at least 1 Schengen day becomes available again.
  final DateTime? nextResetDate;

  bool get isOver => daysUsed > AppConstants.schengenMaxDays;
}

enum SchengenRisk { safe, warning, critical, over }

/// Pure-function Schengen 90/180 calculator.
///
/// Rule: in any rolling 180-day window the traveller may spend at most 90 days
/// in the Schengen area.
class SchengenCalculator {
  const SchengenCalculator();

  /// Calculate Schengen usage as seen on [referenceDate] (defaults to today).
  SchengenResult calculate(
    List<TravelEntry> entries, {
    DateTime? referenceDate,
  }) {
    final today = (referenceDate ?? DateTime.now()).toUtc();
    final windowEnd = today;
    final windowStart = today.subtract(
      const Duration(days: AppConstants.schengenWindowDays - 1),
    );

    // Only confirmed Schengen entries within the 180-day window
    final relevant = entries
        .where((e) => e.isSchengen && e.confirmedByUser)
        .where((e) => _overlapsWindow(e, windowStart, windowEnd))
        .toList();

    final daysUsed = relevant.fold<int>(
      0,
      (sum, e) => sum + _daysInWindow(e, windowStart, windowEnd),
    );

    final daysRemaining =
        (AppConstants.schengenMaxDays - daysUsed).clamp(0, AppConstants.schengenMaxDays);

    final risk = _risk(daysRemaining, daysUsed);

    final nextResetDate = daysUsed >= AppConstants.schengenMaxDays
        ? _computeNextResetDate(relevant, today)
        : null;

    return SchengenResult(
      daysUsed: daysUsed,
      daysRemaining: daysRemaining,
      windowStart: windowStart,
      windowEnd: windowEnd,
      riskLevel: risk,
      nextResetDate: nextResetDate,
    );
  }

  // ---------------------------------------------------------------------------

  bool _overlapsWindow(TravelEntry e, DateTime start, DateTime end) {
    final entryEnd = e.exitDate ?? end;
    return e.entryDate.isBefore(end.add(const Duration(days: 1))) &&
        entryEnd.isAfter(start.subtract(const Duration(days: 1)));
  }

  int _daysInWindow(TravelEntry e, DateTime start, DateTime end) {
    final clampedStart =
        e.entryDate.isBefore(start) ? start : e.entryDate;
    final entryEnd = e.exitDate ?? end;
    final clampedEnd = entryEnd.isAfter(end) ? end : entryEnd;

    final days = clampedEnd.difference(clampedStart).inDays + 1;
    return days.clamp(0, AppConstants.schengenWindowDays);
  }

  SchengenRisk _risk(int remaining, int used) {
    if (used > AppConstants.schengenMaxDays) return SchengenRisk.over;
    if (remaining <= AppConstants.schengenRiskCriticalDays) return SchengenRisk.critical;
    if (remaining <= AppConstants.schengenRiskWarningDays) return SchengenRisk.warning;
    return SchengenRisk.safe;
  }

  /// The earliest date when a full day drops out of the 180-day window,
  /// freeing capacity. Returns null if no entries exist.
  DateTime? _computeNextResetDate(
    List<TravelEntry> schengenEntries,
    DateTime today,
  ) {
    if (schengenEntries.isEmpty) return null;

    // The oldest entry day that is still inside the window will fall out first.
    final dates = schengenEntries.map((e) => e.entryDate).toList()..sort();
    final oldest = dates.first;
    // That day exits the window 180 days after it entered.
    return oldest.add(const Duration(days: AppConstants.schengenWindowDays));
  }
}
