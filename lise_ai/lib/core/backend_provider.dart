// backend_provider.dart
// BackendProvider enum — selects which backend stack the app targets.
// Only one provider is active at a time; default is none (fully local/offline-first).

// ── BackendProvider ────────────────────────────────────────────────────────────

enum BackendProvider {
  /// No remote backend — fully local, offline-first (current default).
  none,

  /// Supabase (PostgreSQL + Auth + Storage + Realtime).
  supabase,

  /// Firebase (Firestore + Auth + Storage + Crashlytics).
  firebase,

  /// Custom REST API (bring-your-own backend).
  customApi,
}

extension BackendProviderExt on BackendProvider {
  String get label => switch (this) {
        BackendProvider.none      => 'Yerel (Çevrimdışı)',
        BackendProvider.supabase  => 'Supabase',
        BackendProvider.firebase  => 'Firebase',
        BackendProvider.customApi => 'Özel API',
      };

  String get description => switch (this) {
        BackendProvider.none =>
            'Tüm veriler cihazda saklanır. İnternet bağlantısı gerekmez.',
        BackendProvider.supabase =>
            'Açık kaynak BaaS — PostgreSQL, Gerçek zamanlı, Auth ve Depolama.',
        BackendProvider.firebase =>
            'Google Firebase — Firestore, Auth, Storage ve Crashlytics.',
        BackendProvider.customApi =>
            'Özel REST/GraphQL API — tam kontrol, kendi sunucun.',
      };

  String get emoji => switch (this) {
        BackendProvider.none      => '💾',
        BackendProvider.supabase  => '⚡',
        BackendProvider.firebase  => '🔥',
        BackendProvider.customApi => '🔧',
      };

  bool get requiresApiKey => this != BackendProvider.none;

  /// Capabilities available for this provider.
  bool get supportsAuth    => this != BackendProvider.none;
  bool get supportsSync    => this != BackendProvider.none;
  bool get supportsStorage => this == BackendProvider.supabase ||
                              this == BackendProvider.firebase;
  bool get supportsCrashReporting => this == BackendProvider.firebase;
}
