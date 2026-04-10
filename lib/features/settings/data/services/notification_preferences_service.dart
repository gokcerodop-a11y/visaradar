import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/notification_preferences.dart';

/// Reads and writes [NotificationPreferences] to [SharedPreferences].
class NotificationPreferencesService {
  NotificationPreferencesService(this._prefs);

  final SharedPreferences _prefs;

  NotificationPreferences load() {
    final raw = _prefs.getString(AppConstants.keyNotificationPreferences);
    if (raw == null) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromJsonString(raw);
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> save(NotificationPreferences prefs) async {
    await _prefs.setString(
      AppConstants.keyNotificationPreferences,
      prefs.toJsonString(),
    );
  }
}
