import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'dart:math';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/locale.dart';
import 'features/notifications/services/local_notification_service.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'screens/consent_gate_screen.dart' show isConsentGiven;

void main() {
  // Catch every uncaught error in the zone so a single plugin failure on
  // cold restart cannot bring down the app before runApp() is reached.
  runZonedGuarded(_bootstrap, (error, stack) {
    debugPrint('[Startup] Uncaught zone error: $error\n$stack');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each native init is independently guarded. A failure in one step must
  // not prevent runApp() from being reached — the user can still use the app
  // even if notifications or orientation locking briefly fail to initialise.

  // Jailbreak / root detection — must run before any premium feature is loaded.
  // On a compromised device, receipt validation and Keychain isolation can be
  // bypassed. We surface a hard warning and halt the normal app launch.
  bool isJailbroken = false;
  try {
    isJailbroken = await FlutterJailbreakDetection.jailbroken;
  } catch (e) {
    debugPrint('[Startup] Jailbreak check failed: $e');
  }
  if (isJailbroken) {
    runApp(const _JailbreakWarningApp());
    return;
  }

  try {
    tz.initializeTimeZones();
  } catch (e, st) {
    debugPrint('[Startup] tz.initializeTimeZones failed: $e\n$st');
  }

  try {
    await LocalNotificationService.initialize();
  } catch (e, st) {
    debugPrint('[Startup] LocalNotificationService.initialize failed: $e\n$st');
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('[Startup] setPreferredOrientations failed: $e');
  }

  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  } catch (e) {
    debugPrint('[Startup] setSystemUIOverlayStyle failed: $e');
  }

  // SharedPreferences is essential — without it we cannot load profile, trips,
  // or settings. Retry once before giving up.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e, st) {
    debugPrint('[Startup] SharedPreferences first attempt failed: $e\n$st');
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e2, st2) {
      debugPrint('[Startup] SharedPreferences retry failed: $e2\n$st2');
    }
  }

  if (prefs == null) {
    runApp(const _StartupErrorApp());
    return;
  }

  // Seed the global locale from the device language before the first frame
  // (VisaRadarApp refines it from the saved profile preference on build).
  L.code = deviceLanguageCode();

  // Record first-run date once — used for telemetry and first-run detection.
  if (prefs.getString('install_date_v1') == null) {
    await prefs.setString('install_date_v1', DateTime.now().toIso8601String());
  }

  // Restore KVKK consent status so proxy classes have the accurate value even
  // before the consent gate widget is mounted.
  AppConstants.kvkkConsentGranted = await isConsentGiven();

  // Ensure a stable device ID exists for Worker free-trial rate limiting.
  // Using a device-scoped ID avoids shared-IP (hotel/airport Wi-Fi) exhausting
  // the trial quota for unrelated users on the same network.
  String deviceId = prefs.getString(AppConstants.keyDeviceId) ?? '';
  if (deviceId.length < 16) {
    final rng = Random.secure();
    deviceId = List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join();
    await prefs.setString(AppConstants.keyDeviceId, deviceId);
  }
  AppConstants.deviceId = deviceId;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const VisaRadarApp(),
    ),
  );
}

/// Shown when jailbreak / root is detected.
/// The app does not proceed past this screen — premium receipt and Keychain
/// isolation cannot be guaranteed on a compromised device.
class _JailbreakWarningApp extends StatelessWidget {
  const _JailbreakWarningApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.gpp_bad_rounded,
                    color: Color(0xFFEF4444),
                    size: 72,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Security Risk\nGüvenlik Riski',
                    style: TextStyle(
                      color: Color(0xFFEDF2FF),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This device appears to be jailbroken.\n'
                    'VisaRadar cannot protect your subscription '
                    'and payment data on a compromised device.\n\n'
                    'Bu cihaz jailbreak\'li görünüyor.\n'
                    'Güvenli olmayan cihazda abonelik ve ödeme '
                    'bilgileriniz korunamaz.',
                    style: TextStyle(
                      color: Color(0xFF8FA3BF),
                      fontSize: 14,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal fallback shown only when SharedPreferences is unavailable —
/// the rest of the app cannot function without local storage.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B), size: 48),
                  SizedBox(height: 16),
                  Text(
                    'VisaRadar could not start',
                    style: TextStyle(
                      color: Color(0xFFEDF2FF),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Local storage is unavailable on this device. Please '
                    'reinstall the app or restart the device.',
                    style: TextStyle(
                      color: Color(0xFF8FA3BF),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
