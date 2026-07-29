import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/localization/locale.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/providers/notification_coordinator_provider.dart';
import 'services/subscription_service.dart';

class VisaRadarApp extends ConsumerStatefulWidget {
  const VisaRadarApp({super.key});

  @override
  ConsumerState<VisaRadarApp> createState() => _VisaRadarAppState();
}

class _VisaRadarAppState extends ConsumerState<VisaRadarApp>
    with WidgetsBindingObserver {
  // Shown while the app is inactive/paused so the iOS App Switcher snapshot
  // does not capture passport/SOS data. Must be a widget overlay (not just
  // SystemChrome) for the snapshot to actually be obscured.
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() => _obscured = true);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _obscured = false);
      SubscriptionService.instance.refreshExpiry();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Warm the notification coordinator so it begins listening to state changes.
    ref.watch(notificationCoordinatorProvider);

    final router = ref.watch(appRouterProvider);
    final localeCode = ref.watch(localeProvider);
    // Keep the global ref-free locale accessor in sync for sub-screens.
    L.code = localeCode;
    Intl.defaultLocale = localeCode == 'tr' ? 'tr_TR' : 'en_US';

    return Stack(
      children: [
        MaterialApp.router(
          title: 'VisaRadar Travel',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          // Drive Material/Cupertino localizations and intl date formatting from
          // the resolved app language (device-detected unless user overrode it).
          locale: Locale(localeCode),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr'),
            Locale('en'),
          ],
          routerConfig: router,
        ),
        if (_obscured) const Positioned.fill(child: ColoredBox(color: Colors.black)),
      ],
    );
  }
}
