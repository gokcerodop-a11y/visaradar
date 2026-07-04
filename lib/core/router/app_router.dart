import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/assistant_screen.dart';
import '../../features/countries/presentation/countries_screen.dart';
import '../../features/diagnostics/presentation/screens/diagnostics_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/location/presentation/screens/saved_places_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/radar/presentation/screens/radar_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/language_settings_screen.dart';
import '../../features/settings/presentation/screens/legal_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/travel/domain/entities/travel_entry.dart';
import '../../features/travel/presentation/providers/trips_provider.dart';
import '../../features/stays/presentation/screens/stays_screen.dart';
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
  static const radar = '/main/radar';
  static const countries = '/main/countries';
  static const assistant = '/main/assistant';
  static const profile = '/main/profile';
  static const subscription = '/subscription';
  static const editProfile = '/settings/profile';
  static const languageSettings = '/settings/language';
  static const notificationSettings = '/settings/notifications';
  static const legalText = '/settings/legal';
  static const diagnostics = '/settings/diagnostics';
  static const savedPlaces = '/profile/saved-places';
  static const stays = '/stays';
  static const staysCountries = '/stays/countries';
  static const staysCities = '/stays/cities';
  static const trips = '/trips';
  static const addTrip = '/trips/add';
  static const editTrip = '/trips/edit/:id';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Stays (auto-tracked countries/cities)
      GoRoute(
        path: AppRoutes.stays,
        builder: (context, state) => const StaysScreen(),
      ),

      // Trips (pushed over the shell)
      GoRoute(
        path: AppRoutes.trips,
        builder: (context, state) => const TripsScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTrip,
        builder: (context, state) => const AddTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.editTrip,
        builder: (context, state) =>
            _EditTripScreen(entryId: state.pathParameters['id']!),
      ),

      // Paywall (pushed over the shell)
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const PaywallScreen(),
      ),

      // Settings sub-screens (pushed over the shell)
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
      GoRoute(
        path: AppRoutes.savedPlaces,
        builder: (context, state) => const SavedPlacesScreen(),
      ),

      // Main shell — 4-tab bottom navigation.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.radar,
                builder: (context, state) => const RadarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.countries,
                builder: (context, state) => const CountriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.assistant,
                builder: (context, state) => const AssistantScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
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
    final TravelEntry? entry = trips.where((t) => t.id == entryId).firstOrNull;
    return AddTripScreen(existingEntry: entry);
  }
}
