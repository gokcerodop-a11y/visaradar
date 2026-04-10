import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/presentation/providers/location_provider.dart';
import '../../../travel/presentation/providers/trips_provider.dart';
import '../../domain/data/country_seed_data.dart';
import '../../domain/models/country_profile.dart';

/// Resolves the [CountryProfile] to display on the Country tab.
///
/// Priority:
///   1. Ongoing trip — the country the user deliberately logged as current
///   2. GPS-detected country — live location fallback
///   3. Latest completed trip — historical fallback
///   4. null → screen shows empty state
///
/// Rationale: a confirmed trip record is more reliable context than a transient
/// GPS ping (e.g. brief cross-border drive not yet logged).
final activeCountryProfileProvider = Provider<CountryProfile?>((ref) {
  // 1. Ongoing trip
  final ongoing = ref.watch(ongoingTripProvider);
  if (ongoing != null) {
    final profile = findCountryProfile(ongoing.country);
    if (profile != null) return profile;
  }

  // 2. GPS-detected country
  final detected = ref.watch(detectedCountryProvider);
  if (detected != null) {
    final profile = findCountryProfile(detected.isoCode);
    if (profile != null) return profile;
  }

  // 3. Latest trip
  final latest = ref.watch(latestTripProvider);
  if (latest != null) return findCountryProfile(latest.country);

  return null;
});

/// ISO code of the active country — same priority as [activeCountryProfileProvider].
///
/// Returns a code even when the country is not in seed data, so the screen can
/// render a "coming soon" state with the correct country name.
final activeCountryCodeProvider = Provider<String?>((ref) {
  final ongoing = ref.watch(ongoingTripProvider);
  if (ongoing != null) return ongoing.country;

  final detected = ref.watch(detectedCountryProvider);
  if (detected != null) return detected.isoCode;

  return ref.watch(latestTripProvider)?.country;
});

/// Human-readable name of the active country — same priority chain.
final activeCountryNameProvider = Provider<String?>((ref) {
  final ongoing = ref.watch(ongoingTripProvider);
  if (ongoing != null) return ongoing.countryLabel ?? ongoing.country;

  final detected = ref.watch(detectedCountryProvider);
  if (detected != null) return detected.name ?? detected.isoCode;

  final latest = ref.watch(latestTripProvider);
  return latest?.countryLabel ?? latest?.country;
});
