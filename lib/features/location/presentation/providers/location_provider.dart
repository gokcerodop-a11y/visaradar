import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/country_detection_service.dart';
import '../../data/services/location_permission_service.dart';
import '../../domain/models/location_state.dart';
import '../../../travel_calendar/data/services/travel_log_service.dart';

// ---------------------------------------------------------------------------
// Service providers — override in tests to inject mocks.
// ---------------------------------------------------------------------------

final locationPermissionServiceProvider = Provider<LocationPermissionService>(
  (_) => LocationPermissionService(),
);

final countryDetectionServiceProvider = Provider<CountryDetectionService>(
  (_) => GeolocatorCountryDetectionService(),
);

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier({
    required LocationPermissionService permissionService,
    required CountryDetectionService detectionService,
  })  : _permissionService = permissionService,
        _detectionService = detectionService,
        super(const LocationState()) {
    _init();
  }

  final LocationPermissionService _permissionService;
  final CountryDetectionService _detectionService;

  /// Called once on construction: check existing permission and auto-detect
  /// if already granted.
  Future<void> _init() async {
    final status = await _permissionService.checkPermission();
    state = state.copyWith(permission: status);
    if (state.hasPermission) {
      await _detectCountry();
    }
  }

  /// Request OS-level permission (shows system prompt on first call).
  /// If granted, immediately starts detection.
  Future<void> requestPermission() async {
    final status = await _permissionService.requestPermission();
    state = state.copyWith(permission: status);
    if (state.hasPermission) {
      await _detectCountry();
    }
  }

  /// Open app Settings so the user can re-enable a permanently-denied permission.
  Future<void> openSettings() => _permissionService.openAppSettings();

  /// Manually re-trigger detection (e.g. "Refresh" button).
  Future<void> refreshDetection() => _detectCountry();

  // -------------------------------------------------------------------------

  Future<void> _detectCountry() async {
    state = state.copyWith(
      phase: LocationDetectionPhase.detecting,
      clearError: true,
    );

    final country = await _detectionService.detectCurrentCountry();

    if (country != null) {
      state = state.copyWith(
        phase: LocationDetectionPhase.detected,
        detectedCountry: country,
      );
      // Record city in the travel calendar (fire-and-forget).
      if (country.city != null && country.city!.isNotEmpty) {
        TravelLogService().addCity(country.city!).ignore();
      }
    } else {
      state = state.copyWith(
        phase: LocationDetectionPhase.failed,
        clearCountry: true,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Public providers
// ---------------------------------------------------------------------------

/// Main location state — permission + detection phase + detected country.
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(
    permissionService: ref.watch(locationPermissionServiceProvider),
    detectionService: ref.watch(countryDetectionServiceProvider),
  );
});

/// Convenience: the detected [DetectedCountry], or null.
final detectedCountryProvider = Provider<DetectedCountry?>((ref) {
  return ref.watch(locationProvider).detectedCountry;
});
