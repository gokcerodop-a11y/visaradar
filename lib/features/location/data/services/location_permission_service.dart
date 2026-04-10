import 'package:geolocator/geolocator.dart';

import '../../domain/models/location_state.dart';

/// Wraps `geolocator` permission calls and normalises to our own enum.
class LocationPermissionService {
  /// Check the current permission status without prompting.
  Future<LocationPermissionStatus> checkPermission() async {
    final p = await Geolocator.checkPermission();
    return _toStatus(p);
  }

  /// Ask for permission.  Returns the resulting status.
  /// On iOS: shows the system prompt on first call; subsequent calls return
  /// the cached result without showing UI again.
  Future<LocationPermissionStatus> requestPermission() async {
    final p = await Geolocator.requestPermission();
    return _toStatus(p);
  }

  /// Open the app-level Settings page so the user can change permission.
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // -------------------------------------------------------------------------

  LocationPermissionStatus _toStatus(LocationPermission p) {
    switch (p) {
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationPermissionStatus.granted;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.restricted;
    }
  }
}
