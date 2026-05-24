// supabase_sync_adapter.dart
// Supabase sync adapter — PLACEHOLDER (no SDK connected yet).
//
// Uses Supabase PostgREST to store records in a generic `user_data` table:
//   CREATE TABLE user_data (
//     id          text PRIMARY KEY,
//     user_id     uuid REFERENCES auth.users NOT NULL,
//     collection  text NOT NULL,
//     payload     jsonb NOT NULL,
//     updated_at  timestamptz DEFAULT now()
//   );
//   CREATE INDEX ON user_data (user_id, collection);
//
// To activate:
//   1. Add `supabase_flutter: ^2.x.x` to pubspec.yaml
//   2. Run the SQL above in the Supabase SQL editor
//   3. Uncomment all TODO blocks below

// ignore_for_file: unused_import
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_adapters.dart';

class SupabaseSyncAdapter implements SyncAdapter {
  // ignore: unused_field
  static const _table = 'user_data';

  // TODO: SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<AdapterResult<void>> push({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    // TODO:
    // await _client.from(_table).upsert({
    //   'id': '${collection}_$id',
    //   'user_id': _client.auth.currentUser!.id,
    //   'collection': collection,
    //   'payload': data,
    //   'updated_at': DateTime.now().toIso8601String(),
    // });
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<Map<String, dynamic>>> pull({
    required String collection,
    required String id,
  }) async {
    // TODO:
    // final response = await _client
    //     .from(_table)
    //     .select('payload')
    //     .eq('id', '${collection}_$id')
    //     .maybeSingle();
    // if (response == null) return AdapterResult.failure('Kayıt bulunamadı');
    // return AdapterResult.success(response['payload'] as Map<String, dynamic>);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<List<Map<String, dynamic>>>> pullAll({
    required String collection,
    required String userId,
  }) async {
    // TODO:
    // final rows = await _client
    //     .from(_table)
    //     .select('payload')
    //     .eq('user_id', userId)
    //     .eq('collection', collection);
    // final list = rows.map<Map<String,dynamic>>((r) =>
    //     r['payload'] as Map<String, dynamic>).toList();
    // return AdapterResult.success(list);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> delete({
    required String collection,
    required String id,
  }) async {
    // TODO:
    // await _client.from(_table).delete().eq('id', '${collection}_$id');
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<int>> syncAll(String userId) async {
    // TODO: iterate all collections and call push/pull per record.
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }
}
