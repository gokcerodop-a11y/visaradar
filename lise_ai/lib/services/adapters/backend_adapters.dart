// backend_adapters.dart
// Abstract adapter interfaces for auth, sync, storage and crash reporting.
// Each backend provider (Supabase, Firebase, CustomApi) implements these.

// ── AuthAdapter ────────────────────────────────────────────────────────────────

/// Represents a signed-in user returned by an auth adapter.
class AdapterUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AdapterUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
  });
}

/// Result wrapper for adapter operations.
class AdapterResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const AdapterResult.success(this.data)
      : error = null,
        isSuccess = true;

  const AdapterResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

/// Abstract interface for all authentication adapters.
abstract class AuthAdapter {
  /// Returns the currently authenticated user, or null if not signed in.
  AdapterUser? get currentUser;

  /// Whether there is an active authenticated session.
  bool get isAuthenticated;

  /// Sign in with email and password.
  Future<AdapterResult<AdapterUser>> signInWithEmail(
      String email, String password);

  /// Sign in with Apple OAuth.
  Future<AdapterResult<AdapterUser>> signInWithApple();

  /// Sign in with Google OAuth.
  Future<AdapterResult<AdapterUser>> signInWithGoogle();

  /// Sign out the current user.
  Future<AdapterResult<void>> signOut();

  /// Register a new user with email and password.
  Future<AdapterResult<AdapterUser>> registerWithEmail(
      String email, String password);

  /// Reset password for the given email address.
  Future<AdapterResult<void>> resetPassword(String email);

  /// Update the current user's display name.
  Future<AdapterResult<AdapterUser>> updateDisplayName(String name);
}

// ── SyncAdapter ────────────────────────────────────────────────────────────────

/// Abstract interface for cloud sync adapters.
abstract class SyncAdapter {
  /// Push a local record to the remote backend.
  /// [collection]: e.g. 'lessons', 'progress', 'achievements'
  /// [id]: unique record identifier
  /// [data]: serializable map
  Future<AdapterResult<void>> push({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  });

  /// Pull a single record from the remote backend.
  Future<AdapterResult<Map<String, dynamic>>> pull({
    required String collection,
    required String id,
  });

  /// Pull all records in a collection for the given user.
  Future<AdapterResult<List<Map<String, dynamic>>>> pullAll({
    required String collection,
    required String userId,
  });

  /// Delete a record from the remote backend.
  Future<AdapterResult<void>> delete({
    required String collection,
    required String id,
  });

  /// Perform a full bidirectional sync for all collections.
  Future<AdapterResult<int>> syncAll(String userId);
}

// ── StorageAdapter ─────────────────────────────────────────────────────────────

/// Abstract interface for cloud file storage adapters.
abstract class StorageAdapter {
  /// Upload bytes to [remotePath]. Returns the public URL on success.
  Future<AdapterResult<String>> upload({
    required String remotePath,
    required List<int> bytes,
    String contentType = 'application/octet-stream',
  });

  /// Download bytes from [remotePath].
  Future<AdapterResult<List<int>>> download(String remotePath);

  /// Delete a file at [remotePath].
  Future<AdapterResult<void>> delete(String remotePath);

  /// Get a signed (time-limited) URL for [remotePath].
  Future<AdapterResult<String>> getSignedUrl(String remotePath,
      {Duration expiry = const Duration(hours: 1)});
}

// ── CrashAdapter ───────────────────────────────────────────────────────────────

/// Abstract interface for crash-reporting adapters.
abstract class CrashAdapter {
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false});
  Future<void> log(String message);
  Future<void> setUserId(String? userId);
  Future<void> setCustomKey(String key, Object value);
}
