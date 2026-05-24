import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app.dart';
import 'features/notifications/services/local_notification_service.dart';
import 'features/profile/presentation/providers/profile_provider.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const VisaRadarApp(),
    ),
  );
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
