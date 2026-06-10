import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'border_data.dart';

/// Detect proximity to a land border so the app can switch into "border mode".
/// Threshold: 50 km (per spec). Returns null when location is unavailable or
/// the user is far from any supported gate.
class BorderModeNotifier extends StateNotifier<NearestBorder?> {
  BorderModeNotifier() : super(null);

  static const thresholdKm = 50.0;

  bool _checking = false;

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        state = null;
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final nb = nearestBorder(pos.latitude, pos.longitude);
      state = (nb != null && nb.km <= thresholdKm) ? nb : null;
    } catch (e) {
      debugPrint('[BorderMode] $e');
      state = null;
    } finally {
      _checking = false;
    }
  }
}

final borderModeProvider =
    StateNotifierProvider<BorderModeNotifier, NearestBorder?>((ref) {
  final n = BorderModeNotifier();
  n.check(); // best-effort on first read
  return n;
});
