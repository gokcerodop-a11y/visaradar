import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/locale.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/providers/notification_coordinator_provider.dart';

class VisaRadarApp extends ConsumerWidget {
  const VisaRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
