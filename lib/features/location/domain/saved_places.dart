import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../profile/presentation/providers/profile_provider.dart';

/// A precise spot the user wants to remember and return to — even years later.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.city,
    this.address,
    required this.savedAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? city;
  final String? address;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'city': city,
        'address': address,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        city: j['city'] as String?,
        address: j['address'] as String?,
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

const _kSavedPlaces = 'saved_places_v1';

class SavedPlacesNotifier extends StateNotifier<List<SavedPlace>> {
  SavedPlacesNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static List<SavedPlace> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kSavedPlaces);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _kSavedPlaces,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(SavedPlace place) async {
    state = [place, ...state];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }

  Future<void> rename(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final p in state)
        if (p.id == id)
          SavedPlace(
            id: p.id,
            name: trimmed,
            lat: p.lat,
            lng: p.lng,
            city: p.city,
            address: p.address,
            savedAt: p.savedAt,
          )
        else
          p,
    ];
    await _persist();
  }
}

final savedPlacesProvider =
    StateNotifierProvider<SavedPlacesNotifier, List<SavedPlace>>((ref) {
  return SavedPlacesNotifier(ref.read(sharedPreferencesProvider));
});
