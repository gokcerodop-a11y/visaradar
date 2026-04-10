import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/crossing_suggestion.dart';

/// Persists the last known country code and a pending crossing suggestion.
class BorderCrossingPersistenceService {
  BorderCrossingPersistenceService(this._prefs);

  final SharedPreferences _prefs;

  // ── Last known country ──────────────────────────────────────────────────

  String? loadLastKnownCountryCode() =>
      _prefs.getString(AppConstants.keyLastKnownCountry);

  Future<void> saveLastKnownCountryCode(String code) =>
      _prefs.setString(AppConstants.keyLastKnownCountry, code);

  // ── Pending suggestion ──────────────────────────────────────────────────

  CrossingSuggestion? loadPendingSuggestion() {
    final raw = _prefs.getString(AppConstants.keyPendingCrossingSuggestion);
    if (raw == null) return null;
    try {
      return CrossingSuggestion.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePendingSuggestion(CrossingSuggestion suggestion) =>
      _prefs.setString(
        AppConstants.keyPendingCrossingSuggestion,
        jsonEncode(suggestion.toJson()),
      );

  Future<void> clearPendingSuggestion() =>
      _prefs.remove(AppConstants.keyPendingCrossingSuggestion);

  // ── Dismissal timestamp ─────────────────────────────────────────────────

  /// Saves the epoch-milliseconds timestamp of the last suggestion dismissal.
  Future<void> saveDismissedAt(int epochMs) =>
      _prefs.setInt(AppConstants.keyLastDismissedSuggestionAt, epochMs);

  /// Returns the epoch-milliseconds of the last dismissal, or null if never.
  int? loadDismissedAt() =>
      _prefs.getInt(AppConstants.keyLastDismissedSuggestionAt);
}
