/// The suggestion type determined when a country change is detected.
enum CrossingSuggestionType {
  /// An ongoing trip exists in a different country.
  /// Suggest: close previous stay + start a new one in [toCountryCode].
  closeAndStartNew,

  /// No ongoing trip.
  /// Suggest: start a new trip in [toCountryCode].
  startNew,
}

/// A pending, unconfirmed border crossing suggestion.
///
/// Created when the detected country changes from [fromCountryCode] to
/// [toCountryCode]. Never auto-written to trips — requires user confirmation.
class CrossingSuggestion {
  const CrossingSuggestion({
    required this.id,
    required this.fromCountryCode,
    this.fromCountryName,
    required this.toCountryCode,
    this.toCountryName,
    required this.detectedAt,
    required this.type,
  });

  final String id;

  /// ISO code of the country the user was previously in.
  final String fromCountryCode;
  final String? fromCountryName;

  /// ISO code of the newly detected country.
  final String toCountryCode;
  final String? toCountryName;

  /// UTC timestamp when the change was first detected.
  final DateTime detectedAt;

  final CrossingSuggestionType type;

  String get fromLabel => fromCountryName ?? fromCountryCode;
  String get toLabel => toCountryName ?? toCountryCode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromCountryCode': fromCountryCode,
        'fromCountryName': fromCountryName,
        'toCountryCode': toCountryCode,
        'toCountryName': toCountryName,
        'detectedAt': detectedAt.toIso8601String(),
        'type': type.name,
      };

  factory CrossingSuggestion.fromJson(Map<String, dynamic> json) =>
      CrossingSuggestion(
        id: json['id'] as String,
        fromCountryCode: json['fromCountryCode'] as String,
        fromCountryName: json['fromCountryName'] as String?,
        toCountryCode: json['toCountryCode'] as String,
        toCountryName: json['toCountryName'] as String?,
        detectedAt: DateTime.parse(json['detectedAt'] as String),
        type: CrossingSuggestionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => CrossingSuggestionType.startNew,
        ),
      );
}
