// supabase_auth_adapter.dart
// Supabase authentication adapter — PLACEHOLDER (no SDK connected yet).
//
// To activate:
//   1. Add `supabase_flutter: ^2.x.x` to pubspec.yaml
//   2. Uncomment all TODO blocks below
//   3. Call `await Supabase.initialize(url: ..., anonKey: ...)` in main()

// ignore_for_file: unused_import
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_adapters.dart';

class SupabaseAuthAdapter implements AuthAdapter {
  // TODO: uncomment when SDK is added
  // SupabaseClient get _client => Supabase.instance.client;

  @override
  AdapterUser? get currentUser {
    // TODO: return AdapterUser from _client.auth.currentUser
    return null;
  }

  @override
  bool get isAuthenticated {
    // TODO: return _client.auth.currentSession != null
    return false;
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithEmail(
      String email, String password) async {
    // TODO:
    // final response = await _client.auth.signInWithPassword(
    //   email: email, password: password);
    // if (response.user == null) return AdapterResult.failure('Giriş başarısız');
    // return AdapterResult.success(_mapUser(response.user!));
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithApple() async {
    // TODO: await _client.auth.signInWithOAuth(OAuthProvider.apple);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithGoogle() async {
    // TODO: await _client.auth.signInWithOAuth(OAuthProvider.google);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> signOut() async {
    // TODO: await _client.auth.signOut();
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> registerWithEmail(
      String email, String password) async {
    // TODO:
    // final response = await _client.auth.signUp(
    //   email: email, password: password);
    // if (response.user == null) return AdapterResult.failure('Kayıt başarısız');
    // return AdapterResult.success(_mapUser(response.user!));
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<void>> resetPassword(String email) async {
    // TODO: await _client.auth.resetPasswordForEmail(email);
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  @override
  Future<AdapterResult<AdapterUser>> updateDisplayName(String name) async {
    // TODO:
    // final response = await _client.auth.updateUser(
    //   UserAttributes(data: {'display_name': name}));
    // if (response.user == null) return AdapterResult.failure('Güncelleme başarısız');
    // return AdapterResult.success(_mapUser(response.user!));
    return const AdapterResult.failure('Supabase SDK henüz bağlı değil');
  }

  // TODO: private mapper
  // AdapterUser _mapUser(User user) => AdapterUser(
  //   id: user.id,
  //   email: user.email,
  //   displayName: user.userMetadata?['display_name'] as String?,
  //   createdAt: DateTime.tryParse(user.createdAt),
  // );
}
