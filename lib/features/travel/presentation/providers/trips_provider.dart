import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../data/services/trip_service.dart';
import '../../domain/entities/travel_entry.dart';
import '../../domain/usecases/schengen_calculator.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final tripServiceProvider = Provider<TripService>((ref) {
  return TripService(ref.read(sharedPreferencesProvider));
});

// ---------------------------------------------------------------------------
// Trips notifier
// ---------------------------------------------------------------------------

class TripsNotifier extends StateNotifier<List<TravelEntry>> {
  TripsNotifier(this._service) : super(_service.load());

  final TripService _service;

  Future<void> add(TravelEntry entry) async {
    state = [...state, entry];
    await _service.save(state);
  }

  Future<void> delete(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _service.save(state);
  }

  Future<void> update(TravelEntry entry) async {
    state = state.map((e) => e.id == entry.id ? entry : e).toList();
    await _service.save(state);
  }
}

final tripsProvider =
    StateNotifierProvider<TripsNotifier, List<TravelEntry>>((ref) {
  return TripsNotifier(ref.read(tripServiceProvider));
});

// ---------------------------------------------------------------------------
// Derived providers
// ---------------------------------------------------------------------------

/// Live Schengen 90/180 result based on stored trips.
final schengenResultProvider = Provider<SchengenResult>((ref) {
  final trips = ref.watch(tripsProvider);
  return const SchengenCalculator().calculate(trips);
});

/// The most recent trip by entry date, or null.
final latestTripProvider = Provider<TravelEntry?>((ref) {
  final trips = ref.watch(tripsProvider);
  if (trips.isEmpty) return null;
  final sorted = [...trips]..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  return sorted.first;
});

/// The currently ongoing trip (no exit date), or null.
final ongoingTripProvider = Provider<TravelEntry?>((ref) {
  final trips = ref.watch(tripsProvider);
  final ongoing = trips.where((t) => t.isOngoing).toList();
  if (ongoing.isEmpty) return null;
  ongoing.sort((a, b) => b.entryDate.compareTo(a.entryDate));
  return ongoing.first;
});

/// Number of distinct Schengen countries visited in the last 180 days.
final schengenCountriesVisitedProvider = Provider<int>((ref) {
  final trips = ref.watch(tripsProvider);
  final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 180));
  final codes = trips
      .where((t) => t.isSchengen && t.entryDate.isAfter(cutoff))
      .map((t) => t.country)
      .toSet();
  return codes.length;
});
