import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/countries/domain/country_data.dart';
import '../../../features/location/domain/models/location_state.dart';
import '../../../features/location/presentation/providers/location_provider.dart';
import '../../../features/profile/presentation/providers/profile_provider.dart';
import '../data/stays_service.dart';
import '../domain/stay_record.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final staysServiceProvider = Provider<StaysService>((ref) {
  return StaysService(ref.read(sharedPreferencesProvider));
});

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class StaysNotifier extends StateNotifier<List<StayRecord>> {
  StaysNotifier(this._service) : super(_service.load());

  final StaysService _service;

  /// Called when location detection yields a (possibly new) country.
  /// - Opens a stay record if none is open yet.
  /// - If already open for a different country, closes the old one and opens a new one.
  /// - If already open for the same country, updates the city if it changed.
  void recordDetection(DetectedCountry detected) {
    final now = DateTime.now();
    final code = detected.isoCode.toUpperCase();
    final currentList = List<StayRecord>.from(state);

    // Look up TR name from country data (falls back to GPS name, then code)
    final vc = visaCountryByCode(code);
    final nameEn = vc?.nameEn ?? detected.name ?? code;
    final nameTr = vc?.nameTr ?? detected.name ?? code;
    final city = detected.city;

    final openIndex = currentList.indexWhere((r) => r.isOngoing);

    if (openIndex >= 0) {
      final open = currentList[openIndex];
      if (open.countryCode == code) {
        // Same country — update city if it changed and re-save
        if (city != null && city.isNotEmpty && open.city != city) {
          currentList[openIndex] = StayRecord(
            id: open.id,
            countryCode: open.countryCode,
            countryNameEn: open.countryNameEn,
            countryNameTr: open.countryNameTr,
            city: city,
            entryDate: open.entryDate,
            exitDate: open.exitDate,
          );
          state = currentList;
          _service.save(state);
        }
        return;
      }
      // Different country — close the existing open stay.
      currentList[openIndex] = open.copyWith(exitDate: now);
    }

    // Open a new stay for the detected country.
    final newStay = StayRecord(
      id: '${code}_${now.millisecondsSinceEpoch}',
      countryCode: code,
      countryNameEn: nameEn,
      countryNameTr: nameTr,
      city: city,
      entryDate: now,
    );

    currentList.add(newStay);
    state = currentList;
    _service.save(state);
  }

  /// Delete a single stay record by id.
  Future<void> delete(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _service.save(state);
  }

  /// Delete all stay records.
  Future<void> deleteAll() async {
    state = [];
    await _service.save(state);
  }
}

// ---------------------------------------------------------------------------
// Public providers
// ---------------------------------------------------------------------------

final staysProvider =
    StateNotifierProvider<StaysNotifier, List<StayRecord>>((ref) {
  return StaysNotifier(ref.read(staysServiceProvider));
});

/// Coordinator: feeds GPS detections into [StaysNotifier].
/// Watch this once from the root shell to keep it alive throughout the session.
final staysCoordinatorProvider = Provider<void>((ref) {
  // Handle the CURRENT value immediately in case GPS already resolved before
  // this coordinator was created (avoids missing the first detection).
  final current = ref.read(detectedCountryProvider);
  if (current != null) {
    ref.read(staysProvider.notifier).recordDetection(current);
  }

  // Listen for future GPS changes.
  ref.listen<DetectedCountry?>(detectedCountryProvider, (prev, next) {
    if (next != null) {
      ref.read(staysProvider.notifier).recordDetection(next);
    }
  });
});
