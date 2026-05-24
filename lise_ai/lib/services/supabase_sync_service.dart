// supabase_sync_service.dart
// Offline-first sync service backed by Supabase PostgREST.
//
// Strategy:
//   1. Write data locally (Hive) first — always succeeds.
//   2. Attempt to push to Supabase immediately.
//   3. On failure, enqueue the op in a persisted Hive box.
//   4. Call flush() when connectivity is restored to retry all queued ops.
//
// Usage:
//   await SupabaseSyncService.instance.init(storage);
//   SupabaseSyncService.instance.push(collection: 'profiles', id: uid, data: map);

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'adapters/supabase_auth_adapter.dart';
import 'adapters/supabase_sync_adapter.dart';
import 'storage_service.dart';

// ── SyncStatus ────────────────────────────────────────────────────────────────

enum SyncStatus {
  /// No Supabase configured — fully local mode.
  localOnly,

  /// Actively pushing or pulling data.
  syncing,

  /// Last sync completed successfully.
  synced,

  /// Network unavailable or Supabase unreachable.
  offline,

  /// A conflict was detected (remote data differs from local).
  conflict,
}

extension SyncStatusExt on SyncStatus {
  String get label => switch (this) {
        SyncStatus.localOnly => 'Yerel',
        SyncStatus.syncing   => 'Senkronize…',
        SyncStatus.synced    => 'Senkronize',
        SyncStatus.offline   => 'Çevrimdışı',
        SyncStatus.conflict  => 'Çakışma',
      };
}

// ── Queued op (persisted as JSON in Hive) ────────────────────────────────────

class _QueuedOp {
  final String collection;
  final String id;
  final Map<String, dynamic> data;
  final int enqueuedAt; // millisecondsSinceEpoch

  _QueuedOp({
    required this.collection,
    required this.id,
    required this.data,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'collection': collection,
        'id': id,
        'data': data,
        'enqueuedAt': enqueuedAt,
      };

  factory _QueuedOp.fromJson(Map<String, dynamic> j) => _QueuedOp(
        collection: j['collection'] as String,
        id: j['id'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map),
        enqueuedAt: j['enqueuedAt'] as int,
      );
}

// ── SupabaseSyncService ────────────────────────────────────────────────────────

class SupabaseSyncService extends ChangeNotifier {
  SupabaseSyncService._();
  static final SupabaseSyncService instance = SupabaseSyncService._();

  static const _boxName = 'sync_queue_v1';

  final _authAdapter = SupabaseAuthAdapter();
  final _syncAdapter = SupabaseSyncAdapter();

  Box<String>? _queueBox;

  // ── Observable state ──────────────────────────────────────────────────────

  SyncStatus _status = SyncStatus.localOnly;
  String? _currentUserId;
  int _lastLatencyMs = 0;
  String? _lastError;

  SyncStatus get status       => _status;
  String?    get currentUserId => _currentUserId;
  int        get lastLatencyMs => _lastLatencyMs;
  String?    get lastError     => _lastError;
  int        get pendingCount  => _queueBox?.length ?? 0;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    if (!SupabaseConfig.isConfigured) {
      _status = SyncStatus.localOnly;
      notifyListeners();
      return;
    }

    // Open or reuse the sync queue Hive box.
    if (!Hive.isBoxOpen(_boxName)) {
      _queueBox = await Hive.openBox<String>(_boxName);
    } else {
      _queueBox = Hive.box<String>(_boxName);
    }

    // Auto anonymous sign-in.
    await _ensureSession();
  }

  // ── Anonymous sign-in helper ──────────────────────────────────────────────

  Future<void> _ensureSession() async {
    if (!SupabaseConfig.isConfigured) return;

    // If already signed in, just capture the user ID.
    final existing = _authAdapter.currentUser;
    if (existing != null) {
      _currentUserId = existing.id;
      _status = SyncStatus.synced;
      notifyListeners();
      return;
    }

    _status = SyncStatus.syncing;
    notifyListeners();

    final result = await _authAdapter.signInAnonymously();
    if (result.isSuccess) {
      _currentUserId = result.data!.id;
      _status = SyncStatus.synced;
      _lastError = null;
    } else {
      _status = SyncStatus.offline;
      _lastError = result.error;
    }
    notifyListeners();
  }

  // ── Push (write-through with offline queue) ───────────────────────────────

  Future<void> push({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (!SupabaseConfig.isConfigured) return;

    await _ensureSession();
    if (_currentUserId == null) {
      _enqueue(collection, id, data);
      return;
    }

    _status = SyncStatus.syncing;
    notifyListeners();

    final sw = Stopwatch()..start();
    final result = await _syncAdapter.push(
      collection: collection,
      id: id,
      data: data,
    );
    sw.stop();
    _lastLatencyMs = sw.elapsedMilliseconds;

    if (result.isSuccess) {
      _status = SyncStatus.synced;
      _lastError = null;
    } else {
      _enqueue(collection, id, data);
      _status = SyncStatus.offline;
      _lastError = result.error;
    }
    notifyListeners();
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> pull({
    required String collection,
    required String id,
  }) async {
    if (!SupabaseConfig.isConfigured || _currentUserId == null) return null;

    final sw = Stopwatch()..start();
    final result = await _syncAdapter.pull(collection: collection, id: id);
    sw.stop();
    _lastLatencyMs = sw.elapsedMilliseconds;

    if (result.isSuccess) {
      _status = SyncStatus.synced;
      _lastError = null;
      notifyListeners();
      return result.data;
    }
    return null;
  }

  // ── Flush queued ops ──────────────────────────────────────────────────────

  Future<int> flush() async {
    final box = _queueBox;
    if (box == null || box.isEmpty) return 0;
    if (!SupabaseConfig.isConfigured) return 0;

    await _ensureSession();
    if (_currentUserId == null) return 0;

    _status = SyncStatus.syncing;
    notifyListeners();

    int successCount = 0;
    final keys = box.keys.toList();

    for (final key in keys) {
      final raw = box.get(key as String);
      if (raw == null) continue;

      try {
        final op = _QueuedOp.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        final result = await _syncAdapter.push(
          collection: op.collection,
          id: op.id,
          data: op.data,
        );
        if (result.isSuccess) {
          await box.delete(key);
          successCount++;
        }
      } catch (_) {
        // Malformed entry — remove it.
        await box.delete(key);
      }
    }

    _status = box.isEmpty ? SyncStatus.synced : SyncStatus.offline;
    notifyListeners();
    return successCount;
  }

  // ── Latency probe ─────────────────────────────────────────────────────────

  Future<int> measureLatency() async {
    if (!SupabaseConfig.isConfigured || _currentUserId == null) return 0;

    final sw = Stopwatch()..start();
    try {
      await Supabase.instance.client
          .from('user_data')
          .select('id')
          .eq('user_id', _currentUserId!)
          .limit(1);
      sw.stop();
      _lastLatencyMs = sw.elapsedMilliseconds;
      notifyListeners();
      return _lastLatencyMs;
    } catch (_) {
      sw.stop();
      _lastLatencyMs = -1;
      notifyListeners();
      return -1;
    }
  }

  // ── Internal queue helpers ────────────────────────────────────────────────

  void _enqueue(String collection, String id, Map<String, dynamic> data) {
    final box = _queueBox;
    if (box == null) return;

    final op = _QueuedOp(
      collection: collection,
      id: id,
      data: data,
      enqueuedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final key = '${collection}_${id}_${op.enqueuedAt}';
    box.put(key, jsonEncode(op.toJson()));
    notifyListeners();
  }
}
