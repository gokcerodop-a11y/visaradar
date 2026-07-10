import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/models/emergency_contact.dart';

const _sosContactsKey = 'visaradar.sos.contacts.v1';

class SosContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  final SharedPreferences _prefs;

  SosContactsNotifier(this._prefs)
      : super(EmergencyContact.listFromJsonString(
            _prefs.getString(_sosContactsKey)));

  Future<void> save(List<EmergencyContact> contacts) async {
    state = contacts;
    await _prefs.setString(
        _sosContactsKey, EmergencyContact.listToJsonString(contacts));
  }

  Future<void> update(int index, EmergencyContact contact) async {
    final list = [...state];
    if (index < list.length) {
      list[index] = contact;
    } else {
      list.add(contact);
    }
    await save(list);
  }

  Future<void> remove(int index) async {
    final list = [...state];
    if (index < list.length) {
      list.removeAt(index);
      await save(list);
    }
  }
}

final sosContactsProvider =
    StateNotifierProvider<SosContactsNotifier, List<EmergencyContact>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SosContactsNotifier(prefs);
});
