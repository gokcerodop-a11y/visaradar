// supabase_auth_adapter.dart
// Real Supabase authentication adapter.
// Requires: SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.
// Supabase.initialize() must be called before any method here.
//
// Tables referenced:
//   profiles (id uuid PK, display_name text, created_at timestamptz)
//   — row is upserted on first anonymous sign-in.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import 'backend_adapters.dart';

class SupabaseAuthAdapter implements AuthAdapter {
  SupabaseClient get _client => Supabase.instance.client;

  // ── Current user ──────────────────────────────────────────────────────────

  @override
  AdapterUser? get currentUser {
    final u = _client.auth.currentUser;
    return u == null ? null : _mapUser(u);
  }

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  // ── Anonymous sign-in (offline-first bootstrap) ───────────────────────────

  /// Signs in anonymously if no session exists. Safe to call multiple times.
  Future<AdapterResult<AdapterUser>> signInAnonymously() async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      // Already authenticated — return existing user.
      final existing = _client.auth.currentUser;
      if (existing != null) return AdapterResult.success(_mapUser(existing));

      final response = await _client.auth.signInAnonymously();
      final user = response.user;
      if (user == null) return const AdapterResult.failure('Anonim giriş başarısız');

      // Upsert a minimal profile row.
      await _client.from('profiles').upsert({
        'id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      return AdapterResult.success(_mapUser(user));
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Email / password ──────────────────────────────────────────────────────

  @override
  Future<AdapterResult<AdapterUser>> signInWithEmail(
      String email, String password) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) return const AdapterResult.failure('Giriş başarısız');
      return AdapterResult.success(_mapUser(user));
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  @override
  Future<AdapterResult<AdapterUser>> registerWithEmail(
      String email, String password) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      final response =
          await _client.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) return const AdapterResult.failure('Kayıt başarısız');
      return AdapterResult.success(_mapUser(user));
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  @override
  Future<AdapterResult<void>> resetPassword(String email) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const AdapterResult.success(null);
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── OAuth (placeholders — needs platform deep-link setup) ─────────────────

  @override
  Future<AdapterResult<AdapterUser>> signInWithApple() async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.liseai://login-callback/',
      );
      // OAuth completes via deep-link redirect; user state updates via auth listener.
      final user = _client.auth.currentUser;
      if (user == null) return const AdapterResult.failure('Apple girişi tamamlanmadı');
      return AdapterResult.success(_mapUser(user));
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  @override
  Future<AdapterResult<AdapterUser>> signInWithGoogle() async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.liseai://login-callback/',
      );
      final user = _client.auth.currentUser;
      if (user == null) return const AdapterResult.failure('Google girişi tamamlanmadı');
      return AdapterResult.success(_mapUser(user));
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  @override
  Future<AdapterResult<void>> signOut() async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      await _client.auth.signOut();
      return const AdapterResult.success(null);
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  @override
  Future<AdapterResult<AdapterUser>> updateDisplayName(String name) async {
    if (!SupabaseConfig.isConfigured) {
      return const AdapterResult.failure('Supabase yapılandırılmamış');
    }
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(data: {'display_name': name}),
      );
      final user = response.user;
      if (user == null) return const AdapterResult.failure('Güncelleme başarısız');
      // Mirror to profiles table.
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': name,
      }, onConflict: 'id');
      return AdapterResult.success(_mapUser(user));
    } on AuthException catch (e) {
      return AdapterResult.failure(e.message);
    } catch (e) {
      return AdapterResult.failure(e.toString());
    }
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  AdapterUser _mapUser(User user) => AdapterUser(
        id: user.id,
        email: user.email,
        displayName: user.userMetadata?['display_name'] as String?,
        createdAt: DateTime.tryParse(user.createdAt),
      );
}
