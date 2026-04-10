import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/settings/domain/models/notification_preferences.dart';
import '../../../features/travel/domain/entities/travel_entry.dart';
import '../../../features/travel/domain/usecases/schengen_calculator.dart';
import 'local_notification_service.dart';

/// Schedules (or cancels) Schengen threshold notifications based on the
/// current [SchengenResult] and the user's [NotificationPreferences].
class SchengenAlertScheduler {
  const SchengenAlertScheduler();

  static const _thresholds = [
    _Threshold(days: 30, id: AppConstants.notifIdSchengen30, key: 'schengenAlert30'),
    _Threshold(days: 15, id: AppConstants.notifIdSchengen15, key: 'schengenAlert15'),
    _Threshold(days: 7,  id: AppConstants.notifIdSchengen7,  key: 'schengenAlert7'),
    _Threshold(days: 3,  id: AppConstants.notifIdSchengen3,  key: 'schengenAlert3'),
    _Threshold(days: 1,  id: AppConstants.notifIdSchengen1,  key: 'schengenAlert1'),
  ];

  Future<void> schedule({
    required SchengenResult result,
    required NotificationPreferences prefs,
    required List<TravelEntry> trips,
  }) async {
    // Always cancel existing Schengen notifications first — reschedule fresh.
    for (final t in _thresholds) {
      await LocalNotificationService.cancel(t.id);
    }

    // No confirmed Schengen trips → nothing meaningful to schedule.
    final hasSchengen = trips.any((t) => t.isSchengen && t.confirmedByUser);
    if (!hasSchengen) return;

    final remaining = result.daysRemaining;

    // Is the user currently in Schengen? Only then can days tick down naturally.
    final ongoingSchengen =
        trips.where((t) => t.isOngoing && t.isSchengen).firstOrNull;

    for (final t in _thresholds) {
      if (!_isEnabled(prefs, t.key)) continue;

      if (remaining <= t.days) {
        // Already at or past this threshold.
        // Schedule for next morning so we don't spam on every app open.
        await LocalNotificationService.scheduleAt(
          id: t.id,
          title: _title(remaining),
          body: _bodyCurrently(remaining),
          scheduledAt: LocalNotificationService.nextMorning9am(),
        );
        debugPrint(
            '[SchengenScheduler] ${t.days}d threshold already crossed '
            '($remaining remaining) → next morning 9am');
      } else if (ongoingSchengen != null) {
        // Calculate the future date when days will drop to this threshold.
        final daysUntil = remaining - t.days;
        final targetDate = DateTime.now().add(Duration(days: daysUntil));
        final at9am = DateTime(
          targetDate.year, targetDate.month, targetDate.day, 9, 0,
        );
        await LocalNotificationService.scheduleAt(
          id: t.id,
          title: _title(t.days),
          body: _bodyFuture(t.days),
          scheduledAt: at9am,
        );
        debugPrint(
            '[SchengenScheduler] ${t.days}d alert scheduled for $at9am');
      }
      // No ongoing Schengen trip and above threshold → days won't decrease
      // on their own; no notification needed until user adds/edits trips.
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isEnabled(NotificationPreferences prefs, String key) => switch (key) {
        'schengenAlert30' => prefs.schengenAlert30,
        'schengenAlert15' => prefs.schengenAlert15,
        'schengenAlert7'  => prefs.schengenAlert7,
        'schengenAlert3'  => prefs.schengenAlert3,
        'schengenAlert1'  => prefs.schengenAlert1,
        _ => false,
      };

  String _title(int remaining) {
    if (remaining <= 1) return 'Schengen limit almost reached';
    if (remaining <= 3) return 'Almost out of Schengen days';
    if (remaining <= 7) return 'Schengen days running low';
    if (remaining <= 15) return 'Schengen allowance reminder';
    return 'Schengen allowance heads-up';
  }

  String _bodyCurrently(int remaining) {
    if (remaining <= 1) {
      return 'You have 1 day or less left in your Schengen allowance. '
          'Plan your exit carefully.';
    }
    return 'You have $remaining days left in your 90-day Schengen allowance. '
        'Keep an eye on your travel plans.';
  }

  String _bodyFuture(int threshold) {
    return 'You\'ll have around $threshold days left in your Schengen '
        'allowance. Make sure your upcoming plans account for this.';
  }
}

// ── Private helper ──────────────────────────────────────────────────────────

class _Threshold {
  const _Threshold({
    required this.days,
    required this.id,
    required this.key,
  });

  final int days;
  final int id;
  final String key;
}
