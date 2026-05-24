import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/country_info/presentation/screens/country_info_screen.dart';
import '../../features/diagnostics/presentation/screens/diagnostics_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/radar/presentation/screens/radar_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/language_settings_screen.dart';
import '../../features/settings/presentation/screens/legal_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/travel/domain/entities/travel_entry.dart';
import '../../features/travel/presentation/providers/trips_provider.dart';
import '../../features/travel/presentation/screens/add_trip_screen.dart';
import '../../features/travel/presentation/screens/trips_screen.dart';
import '../../shared/widgets/main_shell.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const main = '/main';
  static const radar = 'radar';
  static const trips = 'trips';
  static const countryInfo = 'country-info';
  static const settings = 'settings';
  static const subscription = '/subscription';
  static const editProfile = '/settings/profile';
  static const languageSettings = '/settings/language';
  static const notificationSettings = '/settings/notifications';
  static const legalText = '/settings/legal';
  static const diagnostics = '/settings/diagnostics';
  static const addTrip = '/trips/add';
  static const editTrip = '/trips/edit/:id';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  final profileService = ref.read(profileServiceProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      // Splash — redirect based on onboarding state
      GoRoute(
        path: AppRoutes.splash,
        redirect: (context, state) {
          return profileService.isOnboardingDone
              ? '/main/radar'
              : AppRoutes.onboarding;
        },
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Add trip (top-level, pushed over shell)
      GoRoute(
        path: AppRoutes.addTrip,
        builder: (context, state) => const AddTripScreen(),
      ),

      // Edit trip (top-level, pushed over shell)
      GoRoute(
        path: AppRoutes.editTrip,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // Find the entry from the provider — we use a builder widget to access ref
          return _EditTripScreen(entryId: id);
        },
      ),

      // Subscription / paywall screen (pushed over the main shell)
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),

      // Settings sub-screens (pushed over the main shell)
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.languageSettings,
        builder: (context, state) => const LanguageSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.legalText,
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Legal';
          final type = state.uri.queryParameters['type'] ?? 'generic';
          return LegalScreen(title: title, type: type);
        },
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (context, state) => const DiagnosticsScreen(),
      ),

      // Main shell — bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/radar',
                builder: (context, state) => const RadarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/trips',
                builder: (context, state) => const TripsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/country-info',
                builder: (context, state) => const CountryInfoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

// ---------------------------------------------------------------------------
// Helper: edit trip screen (reads entry from provider)
// ---------------------------------------------------------------------------

class _EditTripScreen extends ConsumerWidget {
  const _EditTripScreen({required this.entryId});
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.read(tripsProvider);
    final TravelEntry? entry =
        trips.where((t) => t.id == entryId).firstOrNull;
    return AddTripScreen(existingEntry: entry);
  }
}
