import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      // iOS App Switcher snapshot'ında hassas verilerin görünmemesi için
      // arka plana alındığında siyah overlay göster.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    } else if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

    return MaterialApp.router(
      title: 'VisaRadar Travel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Drive Material/Cupertino localizations and intl date formatting from the
      // resolved app language (device-detected unless the user overrode it).
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
    );
  }
}
