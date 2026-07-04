/// Permission status mapped from platform responses.
enum LocationPermissionStatus {
  /// First launch — not yet asked.
  notDetermined,

  /// User denied once; we can still ask again.
  denied,

  /// User denied permanently (iOS "Don't Allow" twice, or Android blocked).
  /// Must send user to app settings.
  deniedForever,

  /// At least whileInUse is granted.
  granted,

  /// Device-level restriction (parental controls, MDM).
  restricted,
}

/// Which phase the country detection is in.
enum LocationDetectionPhase {
  /// Permission missing or detection not yet started.
  idle,

  /// Actively acquiring GPS + reverse-geocoding.
  detecting,

  /// Country resolved successfully.
  detected,

  /// Location or geocoding failed.
  failed,
}

/// A country resolved from the device's current position.
class DetectedCountry {
  const DetectedCountry({required this.isoCode, this.name, this.city});

  /// ISO-3166-1 alpha-2 code, upper-case (e.g. "DE", "TR").
  final String isoCode;

  /// Human-readable country name from geocoding (may be null).
  final String? name;

  /// City / locality name from geocoding (may be null).
  final String? city;

  @override
  String toString() => name ?? isoCode;
}

/// Aggregated location state for the whole app.
class LocationState {
  const LocationState({
    this.permission = LocationPermissionStatus.notDetermined,
    this.phase = LocationDetectionPhase.idle,
    this.detectedCountry,
    this.errorMessage,
  });

  final LocationPermissionStatus permission;
  final LocationDetectionPhase phase;
  final DetectedCountry? detectedCountry;
  final String? errorMessage;

  // ---------- Convenience getters ----------

  bool get hasPermission => permission == LocationPermissionStatus.granted;
  bool get permissionDeniedForever =>
      permission == LocationPermissionStatus.deniedForever;
  bool get isDetecting => phase == LocationDetectionPhase.detecting;
  bool get hasCountry => detectedCountry != null;

  LocationState copyWith({
    LocationPermissionStatus? permission,
    LocationDetectionPhase? phase,
    DetectedCountry? detectedCountry,
    bool clearCountry = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocationState(
      permission: permission ?? this.permission,
      phase: phase ?? this.phase,
      detectedCountry:
          clearCountry ? null : (detectedCountry ?? this.detectedCountry),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
