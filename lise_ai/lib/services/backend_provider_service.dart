// backend_provider_service.dart
// Manages the selected backend provider and exposes its capabilities.
// Default is BackendProvider.none (fully local/offline-first).

import 'package:flutter/foundation.dart';

import '../core/backend_provider.dart';
import '../services/storage_service.dart';
import 'adapters/backend_adapters.dart';
import 'adapters/supabase_auth_adapter.dart';
import 'adapters/supabase_sync_adapter.dart';
import 'adapters/supabase_storage_adapter.dart';
import 'adapters/firebase_auth_adapter.dart';
import 'adapters/firebase_firestore_sync_adapter.dart';
import 'adapters/firebase_crashlytics_adapter.dart';

// ── ProviderStatus ─────────────────────────────────────────────────────────────

enum ProviderStatus {
  /// Provider not configured — fully local mode.
  unconfigured,

  /// Connection test is in progress.
  testing,

  /// Connected and healthy.
  connected,

  /// Connection test failed or provider unavailable.
  disconnected,
}

extension ProviderStatusExt on ProviderStatus {
  String get label => switch (this) {
        ProviderStatus.unconfigured  => 'Yapılandırılmadı',
        ProviderStatus.testing       => 'Test ediliyor…',
        ProviderStatus.connected     => 'Bağlandı',
        ProviderStatus.disconnected  => 'Bağlantı Kesildi',
      };

  bool get isHealthy => this == ProviderStatus.connected;
}

// ── BackendProviderService ─────────────────────────────────────────────────────

/// Singleton that manages the active backend provider.
///
/// Usage:
///   - Read [selectedProvider] to know which backend is active.
///   - Call [setProvider] to switch providers (dev/debug mode only).
///   - Check capability booleans before using adapters.
///   - Call [testConnection] to update [status].
///
/// Adapters are returned as abstract interfaces — consumers never depend
/// on the concrete SDK type, so switching providers requires no call-site changes.
class BackendProviderService extends ChangeNotifier {
  BackendProviderService._();
  static final BackendProviderService instance = BackendProviderService._();

  static const _kProviderKey = 'backend_provider_v1';

  // ── State ──────────────────────────────────────────────────────────────────

  BackendProvider _selectedProvider = BackendProvider.none;
  ProviderStatus _status = ProviderStatus.unconfigured;
  String? _lastError;

  BackendProvider get selectedProvider => _selectedProvider;
  ProviderStatus  get status           => _status;
  String?         get lastError        => _lastError;

  // ── Capabilities (derived from selected provider) ──────────────────────────

  bool get authAvailable    => _selectedProvider.supportsAuth;
  bool get syncAvailable    => _selectedProvider.supportsSync;
  bool get storageAvailable => _selectedProvider.supportsStorage;
  bool get crashAvailable   => _selectedProvider.supportsCrashReporting;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final saved = storage.loadSetting(_kProviderKey);
    if (saved != null && saved.isNotEmpty) {
      final match = BackendProvider.values
          .where((p) => p.name == saved)
          .firstOrNull;
      if (match != null) {
        _selectedProvider = match;
      }
    }
    // Status reflects whether we have a provider configured.
    _status = _selectedProvider == BackendProvider.none
        ? ProviderStatus.unconfigured
        : ProviderStatus.disconnected; // not yet tested
    notifyListeners();
  }

  // ── Switch provider ────────────────────────────────────────────────────────

  /// Switch the active provider. Only callable in debug mode.
  Future<void> setProvider(BackendProvider provider,
      StorageService storage) async {
    assert(kDebugMode, 'Provider switching is only allowed in debug mode.');
    if (_selectedProvider == provider) return;

    _selectedProvider = provider;
    _status = provider == BackendProvider.none
        ? ProviderStatus.unconfigured
        : ProviderStatus.disconnected;
    _lastError = null;

    await storage.saveSetting(_kProviderKey, provider.name);
    notifyListeners();
  }

  // ── Connection test ────────────────────────────────────────────────────────

  /// Performs a lightweight connection test for the selected provider.
  /// Updates [status] and [lastError] accordingly.
  ///
  /// NOTE: All tests are SIMULATED until real SDKs are added.
  Future<void> testConnection() async {
    if (_selectedProvider == BackendProvider.none) {
      _status = ProviderStatus.unconfigured;
      notifyListeners();
      return;
    }

    _status = ProviderStatus.testing;
    _lastError = null;
    notifyListeners();

    // Simulated 400ms network probe.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // TODO: Replace with real connectivity checks per provider:
    //
    // Supabase:
    //   final client = Supabase.instance.client;
    //   await client.from('_health').select().limit(1);
    //
    // Firebase:
    //   await FirebaseFirestore.instance.doc('_health/ping').get(
    //       const GetOptions(source: Source.server));
    //
    // CustomApi:
    //   final response = await http.get(Uri.parse('$baseUrl/health'));
    //   if (response.statusCode != 200) throw Exception(response.body);

    // Placeholder: providers are always "disconnected" until SDK is wired.
    _status = ProviderStatus.disconnected;
    _lastError = '${_selectedProvider.label} SDK henüz yapılandırılmadı. '
        'SDK bağımlılıklarını ekleyip TODO bloklarını açın.';
    notifyListeners();
  }

  // ── Adapter accessors ──────────────────────────────────────────────────────
  // Returns the correct adapter for the selected provider.
  // Returns null when the provider does not support the capability.

  AuthAdapter? get authAdapter => switch (_selectedProvider) {
        BackendProvider.supabase  => SupabaseAuthAdapter(),
        BackendProvider.firebase  => FirebaseAuthAdapter(),
        BackendProvider.customApi => null, // TODO: CustomApiAuthAdapter()
        BackendProvider.none      => null,
      };

  SyncAdapter? get syncAdapter => switch (_selectedProvider) {
        BackendProvider.supabase  => SupabaseSyncAdapter(),
        BackendProvider.firebase  => FirebaseFirestoreSyncAdapter(),
        BackendProvider.customApi => null, // TODO: CustomApiSyncAdapter()
        BackendProvider.none      => null,
      };

  StorageAdapter? get storageAdapter => switch (_selectedProvider) {
        BackendProvider.supabase  => SupabaseStorageAdapter(),
        BackendProvider.firebase  => null, // TODO: FirebaseStorageAdapter()
        BackendProvider.customApi => null, // TODO: CustomApiStorageAdapter()
        BackendProvider.none      => null,
      };

  CrashAdapter? get crashAdapter => switch (_selectedProvider) {
        BackendProvider.firebase  => FirebaseCrashlyticsAdapter(),
        BackendProvider.supabase  => null,
        BackendProvider.customApi => null,
        BackendProvider.none      => null,
      };
}
