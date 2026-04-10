import 'dart:convert';

enum PassportType {
  ordinary, // Standard citizen passport
  special, // Special passport (government / official duties)
  serviceOfficial, // Service / official passport
  diplomatic, // Diplomatic passport
  euEeaSwiss, // EU / EEA / Swiss — free movement rights
}

enum ResidenceStatus {
  none, // No residence permit
  euSchengenResident, // EU / Schengen residence permit
  otherResidenceStatus, // Other residence status (non-Schengen)
}

enum TravelMode {
  plane,
  car,
  train,
  bus,
  ferry,
  camperCaravan,
  motorcycle,
  onFoot,
}

/// Top-level sentinel for nullable copyWith fields.
const Object _unset = Object();

class UserProfile {
  final String? nationality; // ISO 3166-1 alpha-2 e.g. "TR"
  final String? nationalityLabel; // Display name e.g. "Turkey"
  final PassportType passportType;
  final ResidenceStatus residenceStatus;
  final TravelMode travelMode;
  final String? preferredLocale; // null = auto, 'en', 'tr'

  const UserProfile({
    this.nationality,
    this.nationalityLabel,
    this.passportType = PassportType.ordinary,
    this.residenceStatus = ResidenceStatus.none,
    this.travelMode = TravelMode.plane,
    this.preferredLocale,
  });

  static const empty = UserProfile();

  UserProfile copyWith({
    String? nationality,
    String? nationalityLabel,
    PassportType? passportType,
    ResidenceStatus? residenceStatus,
    TravelMode? travelMode,
    Object? preferredLocale = _unset,
  }) {
    return UserProfile(
      nationality: nationality ?? this.nationality,
      nationalityLabel: nationalityLabel ?? this.nationalityLabel,
      passportType: passportType ?? this.passportType,
      residenceStatus: residenceStatus ?? this.residenceStatus,
      travelMode: travelMode ?? this.travelMode,
      preferredLocale: identical(preferredLocale, _unset)
          ? this.preferredLocale
          : preferredLocale as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'nationality': nationality,
        'nationalityLabel': nationalityLabel,
        'passportType': passportType.name,
        'residenceStatus': residenceStatus.name,
        'travelMode': travelMode.name,
        'preferredLocale': preferredLocale,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        nationality: json['nationality'] as String?,
        nationalityLabel: json['nationalityLabel'] as String?,
        passportType: PassportType.values.firstWhere(
          (e) => e.name == json['passportType'],
          orElse: () => PassportType.ordinary,
        ),
        residenceStatus: ResidenceStatus.values.firstWhere(
          (e) => e.name == json['residenceStatus'],
          orElse: () => ResidenceStatus.none,
        ),
        travelMode: TravelMode.values.firstWhere(
          (e) => e.name == json['travelMode'],
          orElse: () => TravelMode.plane,
        ),
        preferredLocale: json['preferredLocale'] as String?,
      );

  factory UserProfile.fromJsonString(String raw) =>
      UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());
}
