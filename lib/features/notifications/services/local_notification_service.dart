import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/app_constants.dart';

/// Thin wrapper around [FlutterLocalNotificationsPlugin].
///
/// All scheduling goes through this class so notification IDs, channels, and
/// platform configuration are managed in one place.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Android channels ────────────────────────────────────────────────────

  static const _schengenChannelId   = 'visaradar_schengen';
  static const _schengenChannelName = 'Schengen Alerts';
  static const _remindersChannelId   = 'visaradar_reminders';
  static const _remindersChannelName = 'Travel Reminders';

  // ── Init ─────────────────────────────────────────────────────────────────

  /// Call once in [main] before [runApp].
  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Do NOT auto-request on iOS — we ask explicitly via [requestPermission].
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create Android notification channels.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _schengenChannelId,
      _schengenChannelName,
      description: 'Reminders about your Schengen day allowance.',
      importance: Importance.high,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _remindersChannelId,
      _remindersChannelName,
      description: 'General travel reminders and trip log nudges.',
      importance: Importance.defaultImportance,
    ));
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Request notification permission (iOS + Android 13+).
  /// Returns true if permission was granted.
  static Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// Returns true if notification permission is currently granted.
  static Future<bool> checkPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final perms = await ios.checkPermissions();
      return perms?.isEnabled ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? true;
    }

    return true;
  }

  // ── Fire ─────────────────────────────────────────────────────────────────

  /// Show a notification immediately.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channelId   = _schengenChannelId,
    String channelName = _schengenChannelName,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _details(channelId, channelName, high: id < 2000),
    );
  }

  /// Schedule a notification for [scheduledAt] (local time).
  ///
  /// If [scheduledAt] is in the past the notification is silently dropped
  /// (the caller is responsible for always passing a future time).
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String channelId   = _schengenChannelId,
    String channelName = _schengenChannelName,
  }) async {
    if (!scheduledAt.isAfter(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      _details(channelId, channelName, high: id < 2000),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  /// Cancel a single notification by ID.
  static Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel every notification VisaRadar has scheduled.
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Helpers ──────────────────────────────────────────────────────────────

  static NotificationDetails _details(
    String channelId,
    String channelName, {
    required bool high,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: high ? Importance.high : Importance.defaultImportance,
        priority:   high ? Priority.high   : Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  /// Next occurrence of 9 am local time (today if 9 am has not passed yet,
  /// tomorrow otherwise). Used to avoid bombarding the user on every app open.
  static DateTime nextMorning9am() {
    final now    = DateTime.now();
    final today9 = DateTime(now.year, now.month, now.day, 9, 0);
    // Add a small buffer so we never accidentally land in the past
    if (today9.isAfter(now.add(const Duration(minutes: 5)))) return today9;
    return today9.add(const Duration(days: 1));
  }

  /// Convenience IDs from [AppConstants].
  static List<int> get allManagedIds => const [
        AppConstants.notifIdSchengen30,
        AppConstants.notifIdSchengen15,
        AppConstants.notifIdSchengen7,
        AppConstants.notifIdSchengen3,
        AppConstants.notifIdSchengen1,
        AppConstants.notifIdOngoingStay,
        AppConstants.notifIdDismissedCrossing,
        AppConstants.notifIdLocationInactive,
      ];
}
