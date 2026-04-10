import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/profile_service.dart';
import '../../domain/models/user_profile.dart';

// ---------------------------------------------------------------------------
// Low-level providers
// ---------------------------------------------------------------------------

/// Must be overridden in main() after [SharedPreferences.getInstance()].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(sharedPreferencesProvider));
});

// ---------------------------------------------------------------------------
// Profile notifier
// ---------------------------------------------------------------------------

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._service) : super(_service.load());

  final ProfileService _service;

  /// Updates the profile in memory and persists it.
  Future<void> update(UserProfile profile) async {
    state = profile;
    await _service.save(profile);
  }

  /// Called at the end of onboarding — saves profile + sets the done flag.
  Future<void> completeOnboarding(UserProfile profile) async {
    state = profile;
    await _service.save(profile);
    await _service.setOnboardingDone();
  }

  /// Resets onboarding (used from settings debug option).
  Future<void> resetOnboarding() async {
    await _service.resetOnboarding();
    state = UserProfile.empty;
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  return ProfileNotifier(ref.read(profileServiceProvider));
});

// ---------------------------------------------------------------------------
// Derived providers
// ---------------------------------------------------------------------------

/// Whether the user has completed onboarding. Read-once at app start.
final onboardingDoneProvider = Provider<bool>((ref) {
  return ref.read(profileServiceProvider).isOnboardingDone;
});
