import 'package:shared_preferences/shared_preferences.dart';

import '../domain/stay_record.dart';

class StaysService {
  static const _key = 'stays_v1';
  final SharedPreferences _prefs;

  const StaysService(this._prefs);

  List<StayRecord> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return StayRecord.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<StayRecord> records) =>
      _prefs.setString(_key, StayRecord.listToJson(records));
}
