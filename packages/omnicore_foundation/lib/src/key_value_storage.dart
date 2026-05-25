// key_value_storage.dart
// Minimal storage contract every OmniCore-aware service can depend on.
//
// Concrete implementation lives in the app (LiseAI's StorageService).
// Services in `omnicore_memory` and `omnicore_session` declare this
// interface as their dependency instead of the concrete class so they
// can be reused across verticals (LiseAI, Personal AI, Visa AI, etc.).

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
}
