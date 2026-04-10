import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/travel_entry.dart';

/// Reads and writes [TravelEntry] list to [SharedPreferences].
class TripService {
  TripService(this._prefs);

  final SharedPreferences _prefs;

  /// Synchronously loads all trips from the in-memory SharedPreferences cache.
  List<TravelEntry> load() {
    final raw = _prefs.getString(AppConstants.keyTrips);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TravelEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persists [trips] to SharedPreferences.
  Future<void> save(List<TravelEntry> trips) async {
    final encoded = jsonEncode(trips.map((t) => t.toJson()).toList());
    await _prefs.setString(AppConstants.keyTrips, encoded);
  }
}
