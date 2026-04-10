import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/models/location_state.dart';

// ---------------------------------------------------------------------------
// Abstract interface — swap implementations freely (real vs mock vs test).
// ---------------------------------------------------------------------------

abstract class CountryDetectionService {
  /// Resolve the device's current country.
  /// Returns [DetectedCountry] on success, or null if unavailable/failed.
  Future<DetectedCountry?> detectCurrentCountry();
}

// ---------------------------------------------------------------------------
// Real implementation — GPS + reverse geocoding.
// REAL: uses geolocator + geocoding packages.
// Requires [LocationPermissionStatus.granted] before calling.
// ---------------------------------------------------------------------------

class GeolocatorCountryDetectionService implements CountryDetectionService {
  @override
  Future<DetectedCountry?> detectCurrentCountry() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final iso = place.isoCountryCode;
      if (iso == null || iso.isEmpty) return null;

      return DetectedCountry(
        isoCode: iso.toUpperCase(),
        name: place.country,
      );
    } catch (_) {
      // Silently fail — caller reads null as "detection failed".
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Mock implementation — for development and testing only.
//
// Returns a fixed country so that the full suggestion flow can be exercised
// without real GPS. Pass [isoCode] + [name] to simulate any country.
//
// NEVER wire this into a production provider path. Use it only by temporarily
// overriding the provider in development, or in test overrides.
//
// Example (temporary, debug only):
//   (_) => const MockCountryDetectionService(isoCode: 'DE', name: 'Germany')
// ---------------------------------------------------------------------------

@visibleForTesting
class MockCountryDetectionService implements CountryDetectionService {
  const MockCountryDetectionService({
    this.isoCode = 'US',
    this.name = 'United States',
  });

  final String isoCode;
  final String? name;

  @override
  Future<DetectedCountry?> detectCurrentCountry() async =>
      DetectedCountry(isoCode: isoCode, name: name);
}
