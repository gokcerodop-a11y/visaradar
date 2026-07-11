import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/locale.dart';
import '../../domain/models/location_proof_entry.dart';

/// Riverpod handle for [LocationProofService].
final locationProofServiceProvider = Provider<LocationProofService>((ref) {
  return LocationProofService();
});

/// Persists and verifies the SHA-256 location proof chain ("Derin Bilgi").
///
/// Records are stored oldest-first as a JSON list in [SharedPreferences]
/// under [storageKey]. Each new record links to the previous one via its
/// hash, so the stored list is a tamper-evident chain.
class LocationProofService {
  LocationProofService({SharedPreferences? prefs}) : _prefs = prefs;

  /// SharedPreferences key for the JSON-encoded chain.
  static const String storageKey = 'visaradar.proof.v1';

  /// Hard cap on stored records; oldest records are evicted first.
  static const int maxEntries = 5000;

  /// `previousHash` of the very first record in a fresh chain.
  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  SharedPreferences? _prefs;
  final Random _random = Random();

  Future<SharedPreferences> _sp() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// All stored records, oldest first.
  Future<List<LocationProofEntry>> getEntries() async {
    final prefs = await _sp();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <LocationProofEntry>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LocationProofEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt payload: surface as an empty (and therefore unbroken) chain
      // rather than crashing the caller.
      return <LocationProofEntry>[];
    }
  }

  /// Records for the given local calendar day, oldest first.
  Future<List<LocationProofEntry>> getEntriesByDate(DateTime date) async {
    final entries = await getEntries();
    return entries.where((e) {
      final local = e.timestamp.toLocal();
      return local.year == date.year &&
          local.month == date.month &&
          local.day == date.day;
    }).toList();
  }

  /// Appends a new record for [pos] to the hash chain and persists it.
  ///
  /// Returns the created entry. Enforces the [maxEntries] cap by evicting the
  /// oldest records (chain verification tolerates a truncated head).
  Future<LocationProofEntry> recordCurrentLocation(
    Position pos, {
    String? city,
    String? country,
    String? countryCode,
  }) async {
    final entries = await getEntries();
    final previousHash = entries.isEmpty ? genesisHash : entries.last.hash;

    final now = DateTime.now().toUtc();
    final id = _newId(now);
    final hash = LocationProofEntry.computeHash(
      id: id,
      timestamp: now,
      lat: pos.latitude,
      lng: pos.longitude,
      city: city,
      country: country,
      previousHash: previousHash,
    );

    final entry = LocationProofEntry(
      id: id,
      timestamp: now,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      altitudeM: pos.altitude,
      city: city,
      country: country,
      countryCode: countryCode,
      previousHash: previousHash,
      hash: hash,
    );

    entries.add(entry);
    if (entries.length > maxEntries) {
      entries.removeRange(0, entries.length - maxEntries);
    }
    await _save(entries);
    return entry;
  }

  /// Verifies the integrity of the whole chain.
  ///
  /// Checks that every record's hash matches its recomputed canonical hash,
  /// and that every record (after the first stored one) links to its
  /// predecessor's hash. The first stored record is only checked for
  /// self-consistency, because the head of the chain may have been evicted by
  /// the [maxEntries] cap. An empty chain is valid.
  Future<bool> verifyChain() async {
    final entries = await getEntries();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!entry.isSelfConsistent) return false;
      if (i > 0 && entry.previousHash != entries[i - 1].hash) return false;
    }
    return true;
  }

  /// Builds a human-readable, shareable text report for [entries].
  String exportAsText(List<LocationProofEntry> entries) {
    final isTr = L.isTr;
    final buffer = StringBuffer()
      ..writeln(isTr
          ? 'VisaRadar — Derin Bilgi / Konum Kanıtı Raporu'
          : 'VisaRadar — Deep Record / Location Proof Report')
      ..writeln('=' * 46)
      ..writeln(isTr
          ? 'Oluşturulma: ${_formatUtc(DateTime.now().toUtc())}'
          : 'Generated: ${_formatUtc(DateTime.now().toUtc())}')
      ..writeln(isTr
          ? 'Kayıt sayısı: ${entries.length}'
          : 'Record count: ${entries.length}')
      ..writeln(isTr
          ? 'Bütünlük: SHA-256 hash zinciri (her kayıt bir öncekine bağlıdır)'
          : 'Integrity: SHA-256 hash chain (each record links to the previous one)')
      ..writeln();

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final place = [
        if (e.city != null && e.city!.isNotEmpty) e.city,
        if (e.country != null && e.country!.isNotEmpty) e.country,
      ].join(', ');
      final code = (e.countryCode != null && e.countryCode!.isNotEmpty)
          ? ' (${e.countryCode})'
          : '';
      final accuracy =
          e.accuracyM != null ? ' ±${e.accuracyM!.toStringAsFixed(0)}m' : '';

      buffer
        ..writeln('#${i + 1}  ${_formatUtc(e.timestamp)}')
        ..writeln(place.isEmpty
            ? (isTr ? '    Konum: —' : '    Location: —')
            : (isTr ? '    Konum: $place$code' : '    Location: $place$code'))
        ..writeln(isTr
            ? '    Koordinat: ${e.lat.toStringAsFixed(6)}, ${e.lng.toStringAsFixed(6)}$accuracy'
            : '    Coordinates: ${e.lat.toStringAsFixed(6)}, ${e.lng.toStringAsFixed(6)}$accuracy')
        ..writeln('    Hash: ${e.hash}')
        ..writeln(isTr
            ? '    Önceki hash: ${e.previousHash}'
            : '    Previous hash: ${e.previousHash}')
        ..writeln();
    }

    buffer
      ..writeln('-' * 46)
      ..writeln(isTr
          ? 'NOT: Bu kayıtlar güçlü destekleyici kanıt niteliğindedir; ancak '
              'noterin onayladığı resmi belge değildir.'
          : 'NOTE: These records constitute strong supporting evidence; '
              'however, they are not a notarized official document.');
    return buffer.toString();
  }

  Future<void> _save(List<LocationProofEntry> entries) async {
    final prefs = await _sp();
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Timestamp-derived id with a random suffix to avoid collisions when two
  /// records land within the same microsecond.
  String _newId(DateTime now) {
    final suffix =
        _random.nextInt(0x100000).toRadixString(36).padLeft(4, '0');
    return '${now.microsecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  String _formatUtc(DateTime utc) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
  }
}
