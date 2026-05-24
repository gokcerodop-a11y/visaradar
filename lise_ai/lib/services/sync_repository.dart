import '../models/user_account.dart';

// ── SyncRepository (interface) ────────────────────────────────────────────────

/// Generic repository interface for all synced data types.
/// [T] = the data type being synced (e.g. List<Map>, StreakRecord, etc.)
abstract class SyncRepository<T> {
  /// Fetch the latest value from local storage.
  Future<T?> loadLocal();

  /// Persist value to local storage.
  Future<void> saveLocal(T value);

  /// Upload local value to remote. No-op if no connectivity or not signed in.
  Future<void> pushRemote(T value, UserAccount user);

  /// Fetch latest value from remote. Returns null if offline or not signed in.
  Future<T?> pullRemote(UserAccount user);

  /// Sync: pull remote → resolve conflict → save local → push merged.
  Future<T?> sync(UserAccount user);
}

// ── LocalOnlySyncRepository ───────────────────────────────────────────────────

/// Default implementation: local storage only, no remote.
/// When a backend is added, override [pushRemote] and [pullRemote].
abstract class LocalOnlySyncRepository<T> implements SyncRepository<T> {
  @override
  Future<void> pushRemote(T value, UserAccount user) async {
    // No-op: backend not yet connected.
  }

  @override
  Future<T?> pullRemote(UserAccount user) async {
    // No-op: returns null (local data wins).
    return null;
  }

  @override
  Future<T?> sync(UserAccount user) async {
    // Without remote, sync is just a local read.
    return loadLocal();
  }
}

// ── HistorySyncRepository ─────────────────────────────────────────────────────

/// Chat history (list of {role, content} maps).
class HistorySyncRepository extends LocalOnlySyncRepository<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>?> loadLocal() async => null; // managed in-memory

  @override
  Future<void> saveLocal(List<Map<String, dynamic>> value) async {} // managed in-memory
}

// ── ProgressSyncRepository ────────────────────────────────────────────────────

/// Student progress (streak, solved questions, study minutes).
class ProgressSyncRepository extends LocalOnlySyncRepository<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>?> loadLocal() async => null;

  @override
  Future<void> saveLocal(Map<String, dynamic> value) async {}
}

// ── AchievementsSyncRepository ────────────────────────────────────────────────

class AchievementsSyncRepository extends LocalOnlySyncRepository<List<String>> {
  @override
  Future<List<String>?> loadLocal() async => null;

  @override
  Future<void> saveLocal(List<String> value) async {}
}

// ── StreakSyncRepository ──────────────────────────────────────────────────────

class StreakSyncRepository extends LocalOnlySyncRepository<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>?> loadLocal() async => null;

  @override
  Future<void> saveLocal(Map<String, dynamic> value) async {}
}

// ── SettingsSyncRepository ────────────────────────────────────────────────────

class SettingsSyncRepository extends LocalOnlySyncRepository<Map<String, String>> {
  @override
  Future<Map<String, String>?> loadLocal() async => null;

  @override
  Future<void> saveLocal(Map<String, String> value) async {}
}

// ── MemorySyncRepository ──────────────────────────────────────────────────────

/// Teacher/student memory (LongTermMemory, EpisodicMemory, etc.).
class MemorySyncRepository extends LocalOnlySyncRepository<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>?> loadLocal() async => null;

  @override
  Future<void> saveLocal(Map<String, dynamic> value) async {}
}

// ── SyncRepositoryBundle ──────────────────────────────────────────────────────

/// Aggregates all repositories for convenient access.
class SyncRepositoryBundle {
  final HistorySyncRepository history = HistorySyncRepository();
  final ProgressSyncRepository progress = ProgressSyncRepository();
  final AchievementsSyncRepository achievements = AchievementsSyncRepository();
  final StreakSyncRepository streak = StreakSyncRepository();
  final SettingsSyncRepository settings = SettingsSyncRepository();
  final MemorySyncRepository memory = MemorySyncRepository();

  /// Sync all repositories for the given user.
  Future<void> syncAll(UserAccount user) async {
    await Future.wait([
      history.sync(user),
      progress.sync(user),
      achievements.sync(user),
      streak.sync(user),
      settings.sync(user),
      memory.sync(user),
    ]);
  }
}
