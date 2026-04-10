import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/location/domain/models/location_state.dart';
import '../../../features/settings/domain/models/notification_preferences.dart';
import '../../../features/travel/domain/entities/travel_entry.dart';
import 'local_notification_service.dart';

/// Schedules non-Schengen reminder notifications:
/// - ongoing stay reminder
/// - dismissed crossing review reminder
/// - location inactive reminder
class ReminderScheduler {
  const ReminderScheduler();

  Future<void> schedule({
    required NotificationPreferences prefs,
    required List<TravelEntry> trips,
    required LocationPermissionStatus locationStatus,
    required bool hasDismissedSuggestionRecently,
  }) async {
    // Cancel all reminder IDs first — reschedule fresh.
    await LocalNotificationService.cancel(AppConstants.notifIdOngoingStay);
    await LocalNotificationService.cancel(AppConstants.notifIdDismissedCrossing);
    await LocalNotificationService.cancel(AppConstants.notifIdLocationInactive);

    final ongoingTrip =
        trips.where((t) => t.isOngoing).toList()
          ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    final ongoing = ongoingTrip.firstOrNull;

    // ── Ongoing stay reminder ─────────────────────────────────────────────
    if (prefs.ongoingStayReminder && ongoing != null) {
      // Fire 3 days from now at 10 am — refreshes on every state change.
      final in3days = DateTime.now().add(const Duration(days: 3));
      final at10am  = DateTime(in3days.year, in3days.month, in3days.day, 10, 0);

      await LocalNotificationService.scheduleAt(
        id: AppConstants.notifIdOngoingStay,
        title: 'Still traveling?',
        body: 'You have an open trip in ${ongoing.countryLabel}. '
            "Don't forget to log your exit date.",
        scheduledAt: at10am,
        channelId:   'visaradar_reminders',
        channelName: 'Travel Reminders',
      );
      debugPrint('[ReminderScheduler] Ongoing stay reminder set for $at10am');
    }

    // ── Dismissed crossing review reminder ────────────────────────────────
    if (prefs.dismissedCrossingReminder && hasDismissedSuggestionRecently) {
      final in4h = DateTime.now().add(const Duration(hours: 4));

      await LocalNotificationService.scheduleAt(
        id: AppConstants.notifIdDismissedCrossing,
        title: 'Review your trip log',
        body: 'A border crossing was detected recently but not confirmed. '
            'Make sure your trips are up to date.',
        scheduledAt: in4h,
        channelId:   'visaradar_reminders',
        channelName: 'Travel Reminders',
      );
      debugPrint('[ReminderScheduler] Dismissed crossing reminder set for $in4h');
    }

    // ── Location inactive reminder ────────────────────────────────────────
    final locationOff = locationStatus != LocationPermissionStatus.granted;
    if (prefs.locationInactiveReminder && locationOff && trips.isNotEmpty) {
      final tomorrow = DateTime.now().add(const Duration(hours: 24));

      await LocalNotificationService.scheduleAt(
        id: AppConstants.notifIdLocationInactive,
        title: 'Location detection is off',
        body: 'Enable location access so VisaRadar can detect border '
            'crossings automatically.',
        scheduledAt: tomorrow,
        channelId:   'visaradar_reminders',
        channelName: 'Travel Reminders',
      );
      debugPrint('[ReminderScheduler] Location inactive reminder set for $tomorrow');
    }
  }
}
