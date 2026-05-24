import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';

// ── AuthProviderStrategy (interface) ──────────────────────────────────────────

/// Implement one of these for each sign-in method.
/// Implementations are injected into [AuthService].
abstract class AuthProviderStrategy {
  AuthProvider get providerType;

  /// Attempt sign-in. Returns a [UserAccount] on success.
  /// Throws [AuthException] on failure.
  Future<UserAccount> signIn();

  /// Sign out of this provider.
  Future<void> signOut(UserAccount account);
}

// ── AuthException ─────────────────────────────────────────────────────────────

class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException({required this.code, required this.message});

  @override
  String toString() => 'AuthException[$code]: $message';
}

// ── Concrete strategies (stubs — wire real SDK when ready) ────────────────────

class AppleSignInStrategy implements AuthProviderStrategy {
  @override
  AuthProvider get providerType => AuthProvider.apple;

  @override
  Future<UserAccount> signIn() async {
    // TODO: integrate sign_in_with_apple package
    // final credential = await SignInWithApple.getAppleIDCredential(...);
    throw const AuthException(
      code: 'not_implemented',
      message: 'Apple Sign In is not yet wired — coming soon.',
    );
  }

  @override
  Future<void> signOut(UserAccount account) async {
    // Apple does not provide a sign-out API; revoke via Settings.
  }
}

class GoogleSignInStrategy implements AuthProviderStrategy {
  @override
  AuthProvider get providerType => AuthProvider.google;

  @override
  Future<UserAccount> signIn() async {
    // TODO: integrate google_sign_in package
    // final googleUser = await GoogleSignIn().signIn();
    throw const AuthException(
      code: 'not_implemented',
      message: 'Google Sign In is not yet wired — coming soon.',
    );
  }

  @override
  Future<void> signOut(UserAccount account) async {
    // await GoogleSignIn().signOut();
  }
}

class GuestModeStrategy implements AuthProviderStrategy {
  @override
  AuthProvider get providerType => AuthProvider.guest;

  @override
  Future<UserAccount> signIn() async {
    return UserAccount(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      provider: AuthProvider.guest,
      displayName: 'Misafir Öğrenci',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> signOut(UserAccount account) async {
    // Guest sign-out is handled locally.
  }
}

class AnonymousSessionStrategy implements AuthProviderStrategy {
  @override
  AuthProvider get providerType => AuthProvider.anonymous;

  @override
  Future<UserAccount> signIn() async {
    return UserAccount(
      id: 'anon_${DateTime.now().millisecondsSinceEpoch}',
      provider: AuthProvider.anonymous,
      displayName: 'Anonim Öğrenci',
      createdAt: DateTime.now(),
      isVerified: false,
    );
  }

  @override
  Future<void> signOut(UserAccount account) async {
    // Anonymous sessions expire on sign-out.
  }
}

// ── AuthService ───────────────────────────────────────────────────────────────

class AuthService extends ChangeNotifier {
  static const _kAccountKey = 'user_account_v1';

  UserAccount? _currentUser;
  bool _loading = false;

  UserAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isLoading => _loading;
  bool get isGuest =>
      _currentUser?.isGuest == true || _currentUser?.isAnonymous == true;

  final Map<AuthProvider, AuthProviderStrategy> _strategies = {
    AuthProvider.apple:     AppleSignInStrategy(),
    AuthProvider.google:    GoogleSignInStrategy(),
    AuthProvider.guest:     GuestModeStrategy(),
    AuthProvider.anonymous: AnonymousSessionStrategy(),
  };

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kAccountKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _currentUser = UserAccount.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
      } catch (_) {
        // corrupt — will sign in fresh
      }
    }
    // Auto-create guest account on first launch if none exists.
    if (_currentUser == null) {
      await signIn(AuthProvider.guest, storage);
    }
  }

  // ── Sign in ─────────────────────────────────────────────────────────────────

  Future<UserAccount?> signIn(
    AuthProvider provider,
    StorageService storage,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      final strategy = _strategies[provider]!;
      final account = await strategy.signIn();
      _currentUser = account;
      await _persist(storage);
      return account;
    } on AuthException catch (e) {
      debugPrint('[AuthService] sign-in failed: $e');
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────

  Future<void> signOut(StorageService storage) async {
    final account = _currentUser;
    if (account == null) return;
    final strategy = _strategies[account.provider];
    await strategy?.signOut(account);
    _currentUser = null;
    await storage.saveSetting(_kAccountKey, '');
    notifyListeners();
  }

  // ── Update profile ──────────────────────────────────────────────────────────

  Future<void> updateDisplayName(
    String name,
    StorageService storage,
  ) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = user.copyWith(displayName: name);
    await _persist(storage);
    notifyListeners();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _persist(StorageService storage) async {
    if (_currentUser != null) {
      await storage.saveSetting(
          _kAccountKey, jsonEncode(_currentUser!.toJson()));
    }
  }
}
