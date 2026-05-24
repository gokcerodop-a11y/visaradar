import 'package:flutter/foundation.dart';
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
  /// Crash-safe: any plugin failure is logged and swallowed so app startup
  /// is never blocked by notifications being unavailable.
  static Future<void> initialize() async {
    try {
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
    } catch (e, st) {
      debugPrint('[LocalNotificationService] initialize failed: $e\n$st');
    }
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Request notification permission (iOS + Android 13+).
  /// Returns true if permission was granted. Returns false on any failure.
  static Future<bool> requestPermission() async {
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true);
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
    } catch (e, st) {
      debugPrint('[LocalNotificationService] requestPermission failed: $e\n$st');
      return false;
    }
  }

  /// Returns true if notification permission is currently granted.
  /// Returns false on any failure rather than throwing.
  static Future<bool> checkPermission() async {
    try {
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
    } catch (e, st) {
      debugPrint('[LocalNotificationService] checkPermission failed: $e\n$st');
      return false;
    }
  }

  // ── Fire ─────────────────────────────────────────────────────────────────

  /// Show a notification immediately. Crash-safe.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channelId   = _schengenChannelId,
    String channelName = _schengenChannelName,
  }) async {
    try {
      await _plugin.show(
        id,
        title,
        body,
        _details(channelId, channelName, high: id < 2000),
      );
    } catch (e, st) {
      debugPrint('[LocalNotificationService] showNow($id) failed: $e\n$st');
    }
  }

  /// Schedule a notification for [scheduledAt] (local time). Crash-safe.
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

    try {
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
    } catch (e, st) {
      debugPrint('[LocalNotificationService] scheduleAt($id) failed: $e\n$st');
    }
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  /// Cancel a single notification by ID. Crash-safe.
  static Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e, st) {
      debugPrint('[LocalNotificationService] cancel($id) failed: $e\n$st');
    }
  }

  /// Cancel every notification VisaRadar has scheduled. Crash-safe.
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e, st) {
      debugPrint('[LocalNotificationService] cancelAll failed: $e\n$st');
    }
  }

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
