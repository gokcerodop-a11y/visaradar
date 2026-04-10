import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/location/domain/models/location_state.dart';
import '../../../../features/location/presentation/providers/location_provider.dart';
import '../../../../features/profile/domain/data/countries.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/travel/domain/data/schengen_countries.dart';
import '../../../../features/travel/domain/entities/travel_entry.dart';
import '../../../../features/travel/presentation/providers/trips_provider.dart';
import '../../data/services/border_crossing_persistence_service.dart';
import '../../domain/models/crossing_suggestion.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final borderCrossingPersistenceServiceProvider =
    Provider<BorderCrossingPersistenceService>((ref) {
  return BorderCrossingPersistenceService(ref.read(sharedPreferencesProvider));
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class BorderCrossingNotifier extends StateNotifier<CrossingSuggestion?> {
  BorderCrossingNotifier(this._service) : super(null) {
    // Restore any pending suggestion from last session.
    final restored = _service.loadPendingSuggestion();
    if (restored != null) {
      debugPrint('[BorderCrossing] ✅ Restored persisted suggestion: '
          '${restored.fromCountryCode} → ${restored.toCountryCode}');
    } else {
      debugPrint('[BorderCrossing] ℹ️ No persisted suggestion found on init.');
    }
    state = restored;
  }

  final BorderCrossingPersistenceService _service;

  /// Called whenever the detected country changes or trips update.
  /// Compares against the relevant previous-country context and creates a
  /// suggestion on change.
  ///
  /// **Comparison priority:**
  /// 1. Most recent ongoing trip in a DIFFERENT country from detected — this
  ///    is the trip the user is "leaving".
  /// 2. [lastKnownCountry] from persistence — used when there is no open trip
  ///    in a different country.
  void handleCountryDetected(
    DetectedCountry? country,
    List<TravelEntry> trips,
  ) {
    if (country == null) {
      debugPrint('[BorderCrossing] ⚠️ handleCountryDetected called with null country — skipping.');
      return;
    }

    final newCode = country.isoCode.toUpperCase();
    final newName = country.name ?? newCode;

    // All ongoing trips sorted newest-first.
    final ongoing = trips.where((t) => t.isOngoing).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

    debugPrint('[BorderCrossing] 🔍 Evaluating: detected=$newCode ($newName), '
        'ongoing trips=${ongoing.map((t) => "${t.country}(${t.countryLabel})").join(", ")}');

    // The "leaving trip" is the most recent ongoing trip whose country differs
    // from the newly detected country.
    final leavingTrip = ongoing
        .where((t) => t.country.toUpperCase() != newCode)
        .firstOrNull;

    // Determine "previous country" context.
    final lastKnown = _service.loadLastKnownCountryCode();
    final previousCode =
        leavingTrip?.country.toUpperCase() ?? lastKnown?.toUpperCase();

    debugPrint('[BorderCrossing] 🔍 leavingTrip=${leavingTrip?.country ?? "none"}, '
        'lastKnown=$lastKnown, previousCode=$previousCode');

    if (previousCode == null) {
      // First ever detection with no relevant ongoing trip — just record it,
      // no suggestion.
      debugPrint('[BorderCrossing] ⚠️ previousCode is null — saving $newCode as lastKnown, no suggestion.');
      _service.saveLastKnownCountryCode(newCode);
      return;
    }

    if (previousCode == newCode) {
      // No change relative to previous context — nothing to do.
      debugPrint('[BorderCrossing] ✅ previousCode=$previousCode == newCode=$newCode — no change, skipping.');
      return;
    }

    // Country changed. Skip if we already have a pending suggestion for this
    // exact destination (avoid duplicate alerts on repeated detections).
    if (state != null && state!.toCountryCode.toUpperCase() == newCode) {
      debugPrint('[BorderCrossing] ✅ Suggestion already exists for $newCode — preserving.');
      return;
    }

    // Determine suggestion type.
    final type = leavingTrip != null
        ? CrossingSuggestionType.closeAndStartNew
        : CrossingSuggestionType.startNew;

    // Resolve human-readable name for the previous country.
    final fromCode = leavingTrip?.country ?? (lastKnown ?? previousCode);
    final fromName = _lookupCountryName(fromCode);

    final suggestion = CrossingSuggestion(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fromCountryCode: fromCode,
      fromCountryName: fromName,
      toCountryCode: newCode,
      toCountryName: country.name,
      detectedAt: DateTime.now().toUtc(),
      type: type,
    );

    debugPrint('[BorderCrossing] 🚀 SUGGESTION CREATED: ${suggestion.fromCountryCode} → ${suggestion.toCountryCode} (type=${type.name})');

    state = suggestion;
    _service.savePendingSuggestion(suggestion);
  }

  /// Confirms the suggestion: closes the ongoing trip in [fromCountryCode] if
  /// needed, creates a new trip in the destination country, and clears the
  /// suggestion.
  Future<void> confirmSuggestion({
    required CrossingSuggestion suggestion,
    required TripsNotifier tripsNotifier,
    required List<TravelEntry> currentTrips,
  }) async {
    final now = DateTime.now().toUtc();

    // Close the most recent ongoing trip in the FROM country specifically.
    if (suggestion.type == CrossingSuggestionType.closeAndStartNew) {
      final ongoing = currentTrips.where((t) => t.isOngoing).toList()
        ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
      final tripToClose = ongoing
          .where((t) =>
              t.country.toUpperCase() ==
              suggestion.fromCountryCode.toUpperCase())
          .firstOrNull;
      if (tripToClose != null) {
        await tripsNotifier.update(tripToClose.copyWith(exitDate: now));
      }
    }

    // Only create a new trip if there isn't already an ongoing trip in the
    // destination (prevents duplicates when confirming a suggestion while a
    // previous session's destination trip is still open).
    final alreadyThere = currentTrips.any(
      (t) =>
          t.isOngoing &&
          t.country.toUpperCase() == suggestion.toCountryCode.toUpperCase(),
    );
    if (!alreadyThere) {
      final newTrip = TravelEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        country: suggestion.toCountryCode,
        countryLabel:
            suggestion.toCountryName ?? _lookupCountryName(suggestion.toCountryCode),
        entryDate: now,
        isSchengen: isSchengenCountry(suggestion.toCountryCode),
        confirmedByUser: true,
      );
      await tripsNotifier.add(newTrip);
    }

    // Advance last known country and clear suggestion.
    await _service.saveLastKnownCountryCode(suggestion.toCountryCode);
    await _service.clearPendingSuggestion();
    debugPrint('[BorderCrossing] ✅ Suggestion confirmed and cleared.');
    state = null;
  }

  /// Dismisses the suggestion for now. Records the new country as last known
  /// so the same change isn't re-triggered on the next detection.
  Future<void> dismissSuggestion() async {
    if (state == null) return;
    await _service.saveLastKnownCountryCode(state!.toCountryCode);
    await _service.clearPendingSuggestion();
    await _service.saveDismissedAt(DateTime.now().millisecondsSinceEpoch);
    debugPrint('[BorderCrossing] ✅ Suggestion dismissed and cleared.');
    state = null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String? _lookupCountryName(String code) {
    try {
      return kCountries
          .firstWhere(
            (c) => c.code.toUpperCase() == code.toUpperCase(),
          )
          .name;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Public provider
// ---------------------------------------------------------------------------

/// Holds the current pending [CrossingSuggestion], or null if none.
///
/// Automatically reacts to [locationProvider] (filtering on detection
/// completions) and to [tripsProvider] (to catch cases where trips were not
/// yet loaded when detection first fired).
final borderCrossingProvider =
    StateNotifierProvider<BorderCrossingNotifier, CrossingSuggestion?>((ref) {
  final service = ref.read(borderCrossingPersistenceServiceProvider);
  final notifier = BorderCrossingNotifier(service);

  // ── Primary trigger: listen to locationProvider, react on every completed
  // detection (phase == detected). Listening to locationProvider directly
  // (rather than the derived detectedCountryProvider) is more robust:
  // locationProvider changes on every phase transition, so we never miss
  // a detection completion due to equality short-circuiting in the derived
  // provider.
  ref.listen<LocationState>(locationProvider, (prev, next) {
    if (next.phase == LocationDetectionPhase.detected &&
        next.detectedCountry != null) {
      debugPrint('[BorderCrossing] 📡 locationProvider → detected '
          '${next.detectedCountry!.isoCode}, triggering evaluation.');
      notifier.handleCountryDetected(
          next.detectedCountry, ref.read(tripsProvider));
    }
  });

  // ── Secondary trigger: re-evaluate when trips change. This handles the
  // edge case where `handleCountryDetected` previously ran with an empty trip
  // list (previousCode == null → saved lastKnown → returned) and now trips
  // have been loaded or modified. Re-running with the current detected country
  // + new trips may now produce a suggestion.
  ref.listen<List<TravelEntry>>(tripsProvider, (prev, next) {
    final locState = ref.read(locationProvider);
    if (locState.phase == LocationDetectionPhase.detected &&
        locState.detectedCountry != null) {
      debugPrint('[BorderCrossing] 📋 tripsProvider changed (${next.length} trips), '
          're-evaluating with current detection.');
      notifier.handleCountryDetected(locState.detectedCountry, next);
    }
  });

  // ── Bootstrap: evaluate the current already-detected country immediately
  // so suggestions are not missed if detection fired before this provider
  // was first created (e.g. location resolved before the Radar screen opened).
  final locState = ref.read(locationProvider);
  if (locState.phase == LocationDetectionPhase.detected &&
      locState.detectedCountry != null) {
    debugPrint('[BorderCrossing] 🔄 Bootstrap: detection already complete '
        '(${locState.detectedCountry!.isoCode}), evaluating now.');
    notifier.handleCountryDetected(locState.detectedCountry, ref.read(tripsProvider));
  } else {
    debugPrint('[BorderCrossing] ℹ️ Bootstrap: detection not yet complete '
        '(phase=${locState.phase.name}), waiting for listener.');
  }

  return notifier;
});
