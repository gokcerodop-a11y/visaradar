import 'dart:math' as math;

/// A land border crossing point VisaRadar can detect proximity to.
class BorderPost {
  const BorderPost({
    required this.id,
    required this.name,
    required this.fromCode,
    required this.toCode,
    required this.toNameTr,
    required this.toNameEn,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name; // gate name (proper noun, same in both languages)
  final String fromCode; // ISO of side A
  final String toCode; // ISO of the country you'd be entering
  final String toNameTr;
  final String toNameEn;
  final double lat;
  final double lng;

  String toName(bool tr) => tr ? toNameTr : toNameEn;
}

/// Turkey's main land border gates toward Greece and Bulgaria.
/// Coordinates are approximate (gate vicinity) — used only for ~50 km proximity.
const List<BorderPost> kBorderPosts = [
  BorderPost(
    id: 'kapikule',
    name: 'Kapıkule',
    fromCode: 'TR',
    toCode: 'BG',
    toNameTr: 'Bulgaristan',
    toNameEn: 'Bulgaria',
    lat: 41.7167,
    lng: 26.3667,
  ),
  BorderPost(
    id: 'hamzabeyli',
    name: 'Hamzabeyli',
    fromCode: 'TR',
    toCode: 'BG',
    toNameTr: 'Bulgaristan',
    toNameEn: 'Bulgaria',
    lat: 41.8300,
    lng: 26.6200,
  ),
  BorderPost(
    id: 'derekoy',
    name: 'Dereköy',
    fromCode: 'TR',
    toCode: 'BG',
    toNameTr: 'Bulgaristan',
    toNameEn: 'Bulgaria',
    lat: 41.9200,
    lng: 27.2800,
  ),
  BorderPost(
    id: 'pazarkule',
    name: 'Pazarkule',
    fromCode: 'TR',
    toCode: 'GR',
    toNameTr: 'Yunanistan',
    toNameEn: 'Greece',
    lat: 41.6800,
    lng: 26.5500,
  ),
  BorderPost(
    id: 'ipsala',
    name: 'İpsala – Kipi',
    fromCode: 'TR',
    toCode: 'GR',
    toNameTr: 'Yunanistan',
    toNameEn: 'Greece',
    lat: 40.9250,
    lng: 26.3800,
  ),
];

/// Great-circle distance in kilometres (Haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;

class NearestBorder {
  const NearestBorder({required this.post, required this.km});
  final BorderPost post;
  final double km;
}

/// Returns the nearest border and its distance, or null if list empty.
NearestBorder? nearestBorder(double lat, double lng) {
  NearestBorder? best;
  for (final p in kBorderPosts) {
    final d = distanceKm(lat, lng, p.lat, p.lng);
    if (best == null || d < best.km) {
      best = NearestBorder(post: p, km: d);
    }
  }
  return best;
}
