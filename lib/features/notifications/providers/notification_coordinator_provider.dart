import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/border_crossing/presentation/providers/border_crossing_provider.dart';
import '../../../features/location/presentation/providers/location_provider.dart';
import '../../../features/settings/presentation/providers/notification_settings_provider.dart';
import '../../../features/travel/presentation/providers/trips_provider.dart';
import '../services/local_notification_service.dart';
import '../services/reminder_scheduler.dart';
import '../services/schengen_alert_scheduler.dart';

// ---------------------------------------------------------------------------
// Coordinator
// ---------------------------------------------------------------------------

class NotificationCoordinator {
  NotificationCoordinator(this._ref);

  final Ref _ref;

  final SchengenAlertScheduler _schengen = const SchengenAlertScheduler();
  final ReminderScheduler      _reminder = const ReminderScheduler();

  /// Crash-safe: every failure mode is logged and swallowed. Notifications
  /// are a non-essential side effect — they must never bring down the app.
  Future<void> reschedule() async {
    try {
      final prefs         = _ref.read(notificationSettingsProvider);
      final trips         = _ref.read(tripsProvider);
      final schengen      = _ref.read(schengenResultProvider);
      final locationState = _ref.read(locationProvider);

      // Check if a suggestion was dismissed within the last 24 hours.
      final service = _ref.read(borderCrossingPersistenceServiceProvider);
      final dismissedAt = service.loadDismissedAt();
      final hasDismissedRecently = dismissedAt != null &&
          DateTime.now().millisecondsSinceEpoch - dismissedAt <
              const Duration(hours: 24).inMilliseconds;

      await _schengen.schedule(
        result: schengen,
        prefs:  prefs,
        trips:  trips,
      );

      await _reminder.schedule(
        prefs:                          prefs,
        trips:                          trips,
        locationStatus:                 locationState.permission,
        hasDismissedSuggestionRecently: hasDismissedRecently,
      );

      debugPrint('[NotificationCoordinator] Notifications rescheduled.');
    } catch (e, st) {
      debugPrint('[NotificationCoordinator] reschedule failed: $e\n$st');
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Initialise once at app start (read in [VisaRadarApp.build]).
///
/// Listens to all relevant state slices and reschedules notifications whenever
/// trips, settings, location permission, or crossing suggestion state changes.
final notificationCoordinatorProvider =
    Provider<NotificationCoordinator>((ref) {
  final coordinator = NotificationCoordinator(ref);

  // React to trips changes (add / edit / delete).
  ref.listen(tripsProvider, (prev, next) => coordinator.reschedule());

  // React to notification preference changes (toggle on/off).
  ref.listen(
    notificationSettingsProvider,
    (prev, next) => coordinator.reschedule(),
  );

  // React to location permission grant/deny.
  ref.listen(
    locationProvider.select((s) => s.permission),
    (prev, next) => coordinator.reschedule(),
  );

  // React to crossing suggestion appearing or being confirmed/dismissed.
  ref.listen(
    borderCrossingProvider,
    (prev, next) => coordinator.reschedule(),
  );

  // Initial schedule on first creation.
  coordinator.reschedule();

  return coordinator;
});

// ---------------------------------------------------------------------------
// Permission status provider (used by settings screen)
// ---------------------------------------------------------------------------

/// Async check of whether notification permission is currently granted.
/// Use [ref.invalidate] after requesting permission to refresh the value.
final notificationPermissionProvider = FutureProvider.autoDispose<bool>(
  (_) => LocalNotificationService.checkPermission(),
);
