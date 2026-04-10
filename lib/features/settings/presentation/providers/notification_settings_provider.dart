import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../data/services/notification_preferences_service.dart';
import '../../domain/models/notification_preferences.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
  return NotificationPreferencesService(ref.read(sharedPreferencesProvider));
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationSettingsNotifier
    extends StateNotifier<NotificationPreferences> {
  NotificationSettingsNotifier(this._service) : super(_service.load());

  final NotificationPreferencesService _service;

  Future<void> update(NotificationPreferences prefs) async {
    state = prefs;
    await _service.save(prefs);
  }

  Future<void> setSchengenAlert30(bool v) =>
      update(state.copyWith(schengenAlert30: v));
  Future<void> setSchengenAlert15(bool v) =>
      update(state.copyWith(schengenAlert15: v));
  Future<void> setSchengenAlert7(bool v) =>
      update(state.copyWith(schengenAlert7: v));
  Future<void> setSchengenAlert3(bool v) =>
      update(state.copyWith(schengenAlert3: v));
  Future<void> setSchengenAlert1(bool v) =>
      update(state.copyWith(schengenAlert1: v));
  Future<void> setOngoingStayReminder(bool v) =>
      update(state.copyWith(ongoingStayReminder: v));
  Future<void> setDismissedCrossingReminder(bool v) =>
      update(state.copyWith(dismissedCrossingReminder: v));
  Future<void> setLocationInactiveReminder(bool v) =>
      update(state.copyWith(locationInactiveReminder: v));
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationPreferences>(
  (ref) => NotificationSettingsNotifier(
    ref.read(notificationPreferencesServiceProvider),
  ),
);
