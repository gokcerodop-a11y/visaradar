import 'dart:convert';

class EmergencyContact {
  final String name;
  final String phone;
  const EmergencyContact({required this.name, required this.phone});

  Map<String, String> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(name: j['name'] as String, phone: j['phone'] as String);

  static List<EmergencyContact> listFromJsonString(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<EmergencyContact> contacts) =>
      jsonEncode(contacts.map((c) => c.toJson()).toList());
}
