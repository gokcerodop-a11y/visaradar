// key_value_storage.dart
// Minimal storage contract every OmniCore-aware service can depend on.
//
// Concrete implementation lives in the app (LiseAI's StorageService).
// Services in `omnicore_memory` and `omnicore_session` declare this
// interface as their dependency instead of the concrete class so they
// can be reused across verticals (LiseAI, Personal AI, Visa AI, etc.).
//
// Evolution policy:
//   This interface is intentionally minimal. New methods land here when a
//   real downstream need appears (the same way [deleteSetting] was added
//   to support clean session-recovery deletion). Aim is a long-lived,
//   provider-independent contract — backed by Hive today, by SQLite /
//   IndexedDB / cloud KV in the future.

abstract class KeyValueStorage {
  /// Open / lazily initialize the underlying backing store.
  ///
  /// Implementations are expected to be idempotent — calling [init]
  /// multiple times must not lose data or throw.
  Future<void> init();

  /// Load a previously stored string value, or `null` when absent.
  String? loadSetting(String key);

  /// Persist a string value under [key]. Overwrites any prior value.
  Future<void> saveSetting(String key, String value);

  /// Remove a previously stored value. No-op when [key] is not present.
  ///
  /// Implementations that physically cannot delete (e.g. append-only
  /// log stores) should overwrite with an empty value as their best
  /// effort and document the deviation. Callers should treat [deleteSetting]
  /// as the canonical "forget this entry" operation.
  Future<void> deleteSetting(String key);
}
