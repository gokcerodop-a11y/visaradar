// supabase_sync_adapter.dart
// Real Supabase sync adapter using PostgREST.
// Requires: SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.
//
// SQL schema (run once in Supabase SQL editor):
//
//   -- Generic key-value store for all collections
//   CREATE TABLE user_data (
//     id          text PRIMARY KEY,          -- '{collection}_{id}'
//     user_id     uuid REFERENCES auth.users NOT NULL,
//     collection  text NOT NULL,
//     payload     jsonb NOT NULL,
//     updated_at  timestamptz DEFAULT now()
//   );
//   CREATE INDEX ON user_data (user_id, collection);
//   ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "Users own their data"
//     ON user_data FOR ALL USING (auth.uid() = user_id);
//
//   -- Predefined collections used by this adapter:
//   --   'profiles'             — student profile snapshot
//   --   'conversation_history' — per-conversation turn list
//   --   'student_progress'     — mastery/topic progress

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import 'backend_adapters.dart';

class SupabaseSyncAdapter implements SyncAdapter {
  static const _table = 'user_data';
  SupabaseClient get _client => Supabase.instance.client;

  String _compositeId(String collection, String id) => '${collection}_$id';

  // ── Push (upsert) ─────────────────────────────────────────────────────────

  @override
  Future<AdapterResult<void>> push({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const AdapterResult.failure('Oturum açılmamış');

    try {
      await _client.from(_table).upsert({
        'id': _compositeId(collection, id),
        'user_id': userId,
        'collection': collection,
        'payload': data,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      return const AdapterResult.success(null);
    } on PostgrestException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Pull (single record) ──────────────────────────────────────────────────

  @override
  Future<AdapterResult<Map<String, dynamic>>> pull({
    required String collection,
    required String id,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      final response = await _client
          .from(_table)
          .select('payload')
          .eq('id', _compositeId(collection, id))
          .maybeSingle();

      if (response == null) {
        return AdapterResult.failure('Kayıt bulunamadı: $collection/$id');
      }
      return AdapterResult.success(response['payload'] as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Pull all (collection) ─────────────────────────────────────────────────

  @override
  Future<AdapterResult<List<Map<String, dynamic>>>> pullAll({
    required String collection,
    required String userId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      final rows = await _client
          .from(_table)
          .select('payload')
          .eq('user_id', userId)
          .eq('collection', collection)
          .order('updated_at', ascending: false);

      final list = rows
          .map<Map<String, dynamic>>((r) => r['payload'] as Map<String, dynamic>)
          .toList();
      return AdapterResult.success(list);
    } on PostgrestException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  @override
  Future<AdapterResult<void>> delete({
    required String collection,
    required String id,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', _compositeId(collection, id));
      return const AdapterResult.success(null);
    } on PostgrestException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Sync all (flush pending local queue) ──────────────────────────────────
  // Called by SupabaseSyncService.flush() — iterates the queue, not all records.
  // Returns number of records synced successfully.

  @override
  Future<AdapterResult<int>> syncAll(String userId) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    // Actual queue flushing is handled by SupabaseSyncService which holds
    // the persisted queue. This method just verifies connectivity.
    try {
      await _client.from(_table).select('id').eq('user_id', userId).limit(1);
      return const AdapterResult.success(0);
    } on PostgrestException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }
}
