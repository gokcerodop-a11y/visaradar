import 'dart:convert';

class StayRecord {
  const StayRecord({
    required this.id,
    required this.countryCode,
    required this.countryNameEn,
    required this.countryNameTr,
    this.city,
    required this.entryDate,
    this.exitDate,
  });

  final String id;
  final String countryCode; // ISO alpha-2
  final String countryNameEn;
  final String countryNameTr;
  final String? city;
  final DateTime entryDate;
  final DateTime? exitDate; // null = ongoing

  bool get isOngoing => exitDate == null;

  int get daysSpent {
    final end = exitDate ?? DateTime.now();
    return (end.difference(entryDate).inDays).clamp(0, 9999);
  }

  StayRecord copyWith({DateTime? exitDate}) => StayRecord(
        id: id,
        countryCode: countryCode,
        countryNameEn: countryNameEn,
        countryNameTr: countryNameTr,
        city: city,
        entryDate: entryDate,
        exitDate: exitDate ?? this.exitDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'countryCode': countryCode,
        'countryNameEn': countryNameEn,
        'countryNameTr': countryNameTr,
        'city': city,
        'entryDate': entryDate.toIso8601String(),
        'exitDate': exitDate?.toIso8601String(),
      };

  factory StayRecord.fromJson(Map<String, dynamic> j) => StayRecord(
        id: j['id'] as String,
        countryCode: j['countryCode'] as String,
        countryNameEn: j['countryNameEn'] as String,
        countryNameTr:
            j['countryNameTr'] as String? ?? j['countryCode'] as String,
        city: j['city'] as String?,
        entryDate: DateTime.parse(j['entryDate'] as String),
        exitDate: j['exitDate'] != null
            ? DateTime.parse(j['exitDate'] as String)
            : null,
      );

  static List<StayRecord> listFromJson(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => StayRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<StayRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());
}
