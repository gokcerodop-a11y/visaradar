/// Represents a single entry into / exit from a country.
class TravelEntry {
  const TravelEntry({
    required this.id,
    required this.country,
    this.countryLabel,
    required this.entryDate,
    this.exitDate,
    this.isSchengen = false,
    this.confirmedByUser = true,
    this.note,
  });

  final String id;

  /// ISO 3166-1 alpha-2 country code, e.g. "FR".
  final String country;

  /// Human-readable country name, e.g. "France".
  final String? countryLabel;

  final DateTime entryDate;

  /// Null means the traveller is still in the country (ongoing stay).
  final DateTime? exitDate;

  final bool isSchengen;

  /// Whether the user has confirmed this crossing (for uncertain detections).
  final bool confirmedByUser;

  /// Optional free-text note.
  final String? note;

  /// True while [exitDate] is null.
  bool get isOngoing => exitDate == null;

  /// Inclusive number of days spent in this entry.
  int get daysSpent {
    final end = exitDate ?? DateTime.now().toUtc();
    return end.difference(entryDate).inDays + 1;
  }

  TravelEntry copyWith({
    String? id,
    String? country,
    String? countryLabel,
    DateTime? entryDate,
    DateTime? exitDate,
    bool? isSchengen,
    bool? confirmedByUser,
    String? note,
  }) {
    return TravelEntry(
      id: id ?? this.id,
      country: country ?? this.country,
      countryLabel: countryLabel ?? this.countryLabel,
      entryDate: entryDate ?? this.entryDate,
      exitDate: exitDate ?? this.exitDate,
      isSchengen: isSchengen ?? this.isSchengen,
      confirmedByUser: confirmedByUser ?? this.confirmedByUser,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'country': country,
        'countryLabel': countryLabel,
        'entryDate': entryDate.toIso8601String(),
        'exitDate': exitDate?.toIso8601String(),
        'isSchengen': isSchengen,
        'confirmedByUser': confirmedByUser,
        'note': note,
      };

  factory TravelEntry.fromJson(Map<String, dynamic> json) => TravelEntry(
        id: json['id'] as String,
        country: json['country'] as String,
        countryLabel: json['countryLabel'] as String?,
        entryDate: DateTime.parse(json['entryDate'] as String),
        exitDate: json['exitDate'] != null
            ? DateTime.parse(json['exitDate'] as String)
            : null,
        isSchengen: json['isSchengen'] as bool? ?? false,
        confirmedByUser: json['confirmedByUser'] as bool? ?? true,
        note: json['note'] as String?,
      );
}
