/// A single day's travel statistics for the Travel Calendar feature.
///
/// Persisted as JSON inside a `Map<String dateKey, DayLog>` under the
/// SharedPreferences key `visaradar.calendar.v1`.
class DayLog {
  /// Canonical day identifier in `yyyy-MM-dd` format (local time).
  final String dateKey;

  /// Total distance travelled that day (all transport modes), in km.
  final double kmTraveled;

  /// Distance covered on foot, in km (derived from step count).
  final double walkingKm;

  /// Step count for the day (pedometer).
  final int steps;

  /// Cities passed through / visited that day, in visit order.
  final List<String> citiesVisited;

  /// Countries visited that day (used for the monthly country stat).
  final List<String> countriesVisited;

  /// City where the user spent the night (nullable — may be unknown).
  final String? stayedCity;

  /// Free-form user note for the day.
  final String? notes;

  /// Last time this record was modified.
  final DateTime updatedAt;

  const DayLog({
    required this.dateKey,
    this.kmTraveled = 0,
    this.walkingKm = 0,
    this.steps = 0,
    this.citiesVisited = const [],
    this.countriesVisited = const [],
    this.stayedCity,
    this.notes,
    required this.updatedAt,
  });

  /// Builds the canonical `yyyy-MM-dd` key for [date] (local time).
  static String keyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a `yyyy-MM-dd` key back into a local [DateTime] (midnight).
  static DateTime dateFromKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Empty log for [date] — used when a day has no record yet.
  factory DayLog.empty(DateTime date) => DayLog(
        dateKey: keyFor(date),
        updatedAt: DateTime.now(),
      );

  /// True when the log carries no meaningful data.
  bool get isEmpty =>
      kmTraveled == 0 &&
      walkingKm == 0 &&
      steps == 0 &&
      citiesVisited.isEmpty &&
      countriesVisited.isEmpty &&
      (stayedCity == null || stayedCity!.isEmpty) &&
      (notes == null || notes!.isEmpty);

  /// Local [DateTime] (midnight) this log belongs to.
  DateTime get date => dateFromKey(dateKey);

  factory DayLog.fromJson(Map<String, dynamic> json) {
    return DayLog(
      dateKey: json['dateKey'] as String,
      kmTraveled: (json['kmTraveled'] as num?)?.toDouble() ?? 0,
      walkingKm: (json['walkingKm'] as num?)?.toDouble() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      citiesVisited: (json['citiesVisited'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      countriesVisited: (json['countriesVisited'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      stayedCity: json['stayedCity'] as String?,
      notes: json['notes'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'kmTraveled': kmTraveled,
        'walkingKm': walkingKm,
        'steps': steps,
        'citiesVisited': citiesVisited,
        'countriesVisited': countriesVisited,
        'stayedCity': stayedCity,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  DayLog copyWith({
    String? dateKey,
    double? kmTraveled,
    double? walkingKm,
    int? steps,
    List<String>? citiesVisited,
    List<String>? countriesVisited,
    String? stayedCity,
    String? notes,
    DateTime? updatedAt,
  }) {
    return DayLog(
      dateKey: dateKey ?? this.dateKey,
      kmTraveled: kmTraveled ?? this.kmTraveled,
      walkingKm: walkingKm ?? this.walkingKm,
      steps: steps ?? this.steps,
      citiesVisited: citiesVisited ?? this.citiesVisited,
      countriesVisited: countriesVisited ?? this.countriesVisited,
      stayedCity: stayedCity ?? this.stayedCity,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
