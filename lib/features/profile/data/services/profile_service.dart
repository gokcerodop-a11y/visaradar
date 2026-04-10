import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/user_profile.dart';

/// Reads and writes [UserProfile] to [SharedPreferences].
class ProfileService {
  ProfileService(this._prefs);

  final SharedPreferences _prefs;

  /// Synchronously loads the profile from the in-memory SharedPreferences cache.
  UserProfile load() {
    final raw = _prefs.getString(AppConstants.keyUserProfile);
    if (raw == null) return UserProfile.empty;
    try {
      return UserProfile.fromJsonString(raw);
    } catch (_) {
      return UserProfile.empty;
    }
  }

  /// Persists [profile] to SharedPreferences.
  Future<void> save(UserProfile profile) async {
    await _prefs.setString(AppConstants.keyUserProfile, profile.toJsonString());
  }

  /// Marks onboarding as complete.
  Future<void> setOnboardingDone() async {
    await _prefs.setBool(AppConstants.keyOnboardingDone, true);
  }

  /// Clears the onboarding flag (for testing / reset flow).
  Future<void> resetOnboarding() async {
    await _prefs.remove(AppConstants.keyOnboardingDone);
    await _prefs.remove(AppConstants.keyUserProfile);
  }

  bool get isOnboardingDone =>
      _prefs.getBool(AppConstants.keyOnboardingDone) ?? false;
}
