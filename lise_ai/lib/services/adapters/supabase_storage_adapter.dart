// supabase_storage_adapter.dart
// Supabase storage adapter — PLACEHOLDER (no SDK connected yet).
//
// Uses the Supabase Storage bucket API.
// Bucket setup:
//   1. Create a private bucket named "user-files" in Supabase Dashboard
//   2. Set RLS policy: auth.uid() = owner column
//
// To activate:
//   1. Add `supabase_flutter: ^2.x.x` to pubspec.yaml
//   2. Uncomment all TODO blocks below

// ignore_for_file: unused_import
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_adapters.dart';

class SupabaseStorageAdapter implements StorageAdapter {
  // ignore: unused_field
  static const _bucket = 'user-files';

  // TODO: SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<AdapterResult<String>> upload({
    required String remotePath,
    required List<int> bytes,
    String contentType = 'application/octet-stream',
  }) async {
    // TODO:
    // await _client.storage.from(_bucket).uploadBinary(
    //   remotePath,
    //   Uint8List.fromList(bytes),
    //   fileOptions: FileOptions(contentType: contentType, upsert: true),
    // );
    // final url = _client.storage.from(_bucket).getPublicUrl(remotePath);
    // return AdapterResult.success(url);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<List<int>>> download(String remotePath) async {
    // TODO:
    // final bytes = await _client.storage.from(_bucket).download(remotePath);
    // return AdapterResult.success(bytes.toList());
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> delete(String remotePath) async {
    // TODO:
    // await _client.storage.from(_bucket).remove([remotePath]);
    // return const AdapterResult.success(null);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<String>> getSignedUrl(
    String remotePath, {
    Duration expiry = const Duration(hours: 1),
  }) async {
    // TODO:
    // final url = await _client.storage.from(_bucket)
    //     .createSignedUrl(remotePath, expiry.inSeconds);
    // return AdapterResult.success(url);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }
}
