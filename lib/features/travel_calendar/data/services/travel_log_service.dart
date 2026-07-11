import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/day_log.dart';

/// Persistence + mutation layer for the Travel Calendar feature.
///
/// All day logs live in a single SharedPreferences entry
/// (`visaradar.calendar.v1`) as a JSON map of `dateKey -> DayLog`.
class TravelLogService {
  static const _storeKey = 'visaradar.calendar.v1';

  /// Last known GPS fix, used to derive km deltas in [updateFromPosition].
  static const _lastPositionKey = 'visaradar.calendar.lastpos.v1';

  /// Pedometer baseline (`Pedometer.stepCountStream` reports steps since
  /// boot, not per-day), used by [recordPedometerReading].
  static const _stepBaseKey = 'visaradar.calendar.stepbase.v1';

  /// Average step length (metres) used to derive walking km from steps.
  static const _metersPerStep = 0.762;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // -------------------------------------------------------------------------
  // Raw store helpers
  // -------------------------------------------------------------------------

  Future<Map<String, DayLog>> _readStore() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) =>
            MapEntry(key, DayLog.fromJson(value as Map<String, dynamic>)),
      );
    } catch (_) {
      // Corrupt store — never crash the app over calendar data.
      return {};
    }
  }

  Future<void> _writeStore(Map<String, DayLog> store) async {
    final prefs = await _prefs;
    final encoded =
        jsonEncode(store.map((key, log) => MapEntry(key, log.toJson())));
    await prefs.setString(_storeKey, encoded);
  }

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  /// Log for today (empty log if none saved yet).
  Future<DayLog> getTodayLog() => getLogForDate(DateTime.now());

  /// Log for [date] (empty log if none saved yet).
  Future<DayLog> getLogForDate(DateTime date) async {
    final store = await _readStore();
    return store[DayLog.keyFor(date)] ?? DayLog.empty(date);
  }

  /// All saved logs, sorted by date ascending.
  Future<List<DayLog>> getAllLogs() async {
    final store = await _readStore();
    final logs = store.values.toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return logs;
  }

  /// Logs belonging to the month of [month] (year+month matter).
  Future<List<DayLog>> getLogsForMonth(DateTime month) async {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final store = await _readStore();
    final logs = store.values
        .where((log) => log.dateKey.startsWith(prefix))
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return logs;
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  /// Inserts or replaces the log for its `dateKey`.
  Future<void> upsertLog(DayLog log) async {
    final store = await _readStore();
    store[log.dateKey] = log.copyWith(updatedAt: DateTime.now());
    await _writeStore(store);
  }

  /// Removes the log for [dateKey] entirely.
  Future<void> deleteLog(String dateKey) async {
    final store = await _readStore();
    store.remove(dateKey);
    await _writeStore(store);
  }

  /// Overwrites the day's step count (and the derived walking km).
  Future<DayLog> updateSteps(int steps, {DateTime? date}) async {
    final log = await getLogForDate(date ?? DateTime.now());
    final updated = log.copyWith(
      steps: steps,
      walkingKm: (steps * _metersPerStep) / 1000,
    );
    await upsertLog(updated);
    return updated;
  }

  /// Adds [city] to the day's visited list (duplicate-safe,
  /// case-insensitive).
  Future<DayLog> addCity(String city, {DateTime? date}) async {
    final trimmed = city.trim();
    final log = await getLogForDate(date ?? DateTime.now());
    if (trimmed.isEmpty ||
        log.citiesVisited
            .any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return log;
    }
    final updated =
        log.copyWith(citiesVisited: [...log.citiesVisited, trimmed]);
    await upsertLog(updated);
    return updated;
  }

  /// Adds [km] to the day's travelled distance.
  Future<DayLog> addKm(double km, {DateTime? date}) async {
    if (km <= 0) return getLogForDate(date ?? DateTime.now());
    final log = await getLogForDate(date ?? DateTime.now());
    final updated = log.copyWith(kmTraveled: log.kmTraveled + km);
    await upsertLog(updated);
    return updated;
  }

  /// Replaces the user note for [dateKey].
  Future<DayLog> updateNote(String dateKey, String note) async {
    final log = await getLogForDate(DayLog.dateFromKey(dateKey));
    final updated = log.copyWith(notes: note.trim());
    await upsertLog(updated);
    return updated;
  }

  /// Replaces the overnight city for [dateKey].
  Future<DayLog> updateStayedCity(String dateKey, String city) async {
    final log = await getLogForDate(DayLog.dateFromKey(dateKey));
    final updated = log.copyWith(stayedCity: city.trim());
    await upsertLog(updated);
    return updated;
  }

  // -------------------------------------------------------------------------
  // Automatic capture
  // -------------------------------------------------------------------------

  /// One-stop location update: adds the km delta since the previous fix to
  /// today's total AND records the resolved [city]/[country] on the day.
  ///
  /// Call this from wherever the app already receives GPS fixes (radar /
  /// border tracking) so the calendar fills itself without user action.
  Future<DayLog> updateFromPosition(
    Position pos,
    String? city,
    String? country,
  ) async {
    final now = DateTime.now();
    final prefs = await _prefs;

    // --- km delta from previous fix (same day only) ---
    double deltaKm = 0;
    final rawLast = prefs.getString(_lastPositionKey);
    if (rawLast != null && rawLast.isNotEmpty) {
      try {
        final last = jsonDecode(rawLast) as Map<String, dynamic>;
        if (last['dateKey'] == DayLog.keyFor(now)) {
          final meters = Geolocator.distanceBetween(
            (last['lat'] as num).toDouble(),
            (last['lng'] as num).toDouble(),
            pos.latitude,
            pos.longitude,
          );
          // Ignore GPS jitter below 50 m.
          if (meters >= 50) deltaKm = meters / 1000;
        }
      } catch (_) {
        // Corrupt marker — fall through and just reseed it below.
      }
    }
    await prefs.setString(
      _lastPositionKey,
      jsonEncode({
        'dateKey': DayLog.keyFor(now),
        'lat': pos.latitude,
        'lng': pos.longitude,
        'ts': now.toIso8601String(),
      }),
    );

    // --- merge into today's log ---
    var log = await getTodayLog();
    var cities = log.citiesVisited;
    var countries = log.countriesVisited;

    final trimmedCity = city?.trim() ?? '';
    if (trimmedCity.isNotEmpty &&
        !cities.any((c) => c.toLowerCase() == trimmedCity.toLowerCase())) {
      cities = [...cities, trimmedCity];
    }
    final trimmedCountry = country?.trim() ?? '';
    if (trimmedCountry.isNotEmpty &&
        !countries
            .any((c) => c.toLowerCase() == trimmedCountry.toLowerCase())) {
      countries = [...countries, trimmedCountry];
    }

    log = log.copyWith(
      kmTraveled: log.kmTraveled + deltaKm,
      citiesVisited: cities,
      countriesVisited: countries,
      // The most recent city of the day is the best guess for the overnight
      // city until the user edits it explicitly.
      stayedCity: (log.stayedCity == null || log.stayedCity!.isEmpty)
          ? (trimmedCity.isEmpty ? log.stayedCity : trimmedCity)
          : log.stayedCity,
    );
    await upsertLog(log);
    return log;
  }

  /// Converts a cumulative pedometer reading (steps since device boot) into
  /// today's step count and persists it. Handles day rollover and reboots.
  Future<DayLog> recordPedometerReading(int cumulativeSteps) async {
    final prefs = await _prefs;
    final todayKey = DayLog.keyFor(DateTime.now());
    final today = await getTodayLog();

    int base = cumulativeSteps;
    int offset = today.steps;
    final rawMeta = prefs.getString(_stepBaseKey);
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        final meta = jsonDecode(rawMeta) as Map<String, dynamic>;
        if (meta['dateKey'] == todayKey &&
            (meta['base'] as num).toInt() <= cumulativeSteps) {
          base = (meta['base'] as num).toInt();
          offset = (meta['offset'] as num?)?.toInt() ?? 0;
        }
        // else: new day OR device rebooted (counter reset) — rebase with the
        // already-saved daily steps as offset so nothing is lost.
      } catch (_) {
        // Corrupt meta — rebase.
      }
    }
    await prefs.setString(
      _stepBaseKey,
      jsonEncode({'dateKey': todayKey, 'base': base, 'offset': offset}),
    );

    return updateSteps(offset + (cumulativeSteps - base));
  }
}

/// App-wide singleton for the travel log service.
final travelLogServiceProvider =
    Provider<TravelLogService>((ref) => TravelLogService());
