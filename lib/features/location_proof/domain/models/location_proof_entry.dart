import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A single immutable link in the SHA-256 location proof chain ("Derin
/// Bilgi" / Deep Record).
///
/// Every entry embeds the hash of the previous entry ([previousHash]) and its
/// own hash ([hash]) computed over a canonical payload of its fields. This
/// forms a tamper-evident chain: modifying any historical record invalidates
/// its own hash and breaks the linkage of every record after it.
class LocationProofEntry {
  const LocationProofEntry({
    required this.id,
    required this.timestamp,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.altitudeM,
    this.city,
    this.country,
    this.countryCode,
    required this.previousHash,
    required this.hash,
  });

  /// Unique record id (timestamp-derived, collision-safe suffix).
  final String id;

  /// Moment of capture. Always serialized as UTC ISO-8601 so the hash is
  /// reproducible regardless of device timezone.
  final DateTime timestamp;

  final double lat;
  final double lng;

  /// GPS horizontal accuracy in meters, if reported by the device.
  final double? accuracyM;

  /// Altitude in meters, if reported by the device.
  final double? altitudeM;

  /// Reverse-geocoded locality (best effort).
  final String? city;

  /// Reverse-geocoded country name (best effort).
  final String? country;

  /// ISO country code (best effort).
  final String? countryCode;

  /// SHA-256 hash of the previous record in the chain
  /// ([LocationProofEntry.computeHash] output), or the genesis constant for
  /// the very first record.
  final String previousHash;

  /// SHA-256 hash of this record's canonical payload.
  final String hash;

  /// Computes the canonical SHA-256 hash for a record.
  ///
  /// Payload: `id | timestampUtcIso | lat(6dp) | lng(6dp) | city | country |
  /// previousHash`, joined with `|`. Coordinates are fixed to 6 decimal
  /// places (≈11 cm) so re-serialization can never change the digest.
  static String computeHash({
    required String id,
    required DateTime timestamp,
    required double lat,
    required double lng,
    String? city,
    String? country,
    required String previousHash,
  }) {
    final payload = [
      id,
      timestamp.toUtc().toIso8601String(),
      lat.toStringAsFixed(6),
      lng.toStringAsFixed(6),
      city ?? '',
      country ?? '',
      previousHash,
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// True when the stored [hash] matches the recomputed canonical hash of
  /// this record's own fields (does not check linkage to the previous entry).
  bool get isSelfConsistent =>
      hash ==
      computeHash(
        id: id,
        timestamp: timestamp,
        lat: lat,
        lng: lng,
        city: city,
        country: country,
        previousHash: previousHash,
      );

  factory LocationProofEntry.fromJson(Map<String, dynamic> json) {
    return LocationProofEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: (json['accuracyM'] as num?)?.toDouble(),
      altitudeM: (json['altitudeM'] as num?)?.toDouble(),
      city: json['city'] as String?,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
      previousHash: json['previousHash'] as String,
      hash: json['hash'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracyM': accuracyM,
        if (altitudeM != null) 'altitudeM': altitudeM,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (countryCode != null) 'countryCode': countryCode,
        'previousHash': previousHash,
        'hash': hash,
      };
}
