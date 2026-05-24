import 'dart:convert';
import '../services/storage_service.dart';

// ── SyncOperationType ─────────────────────────────────────────────────────────

enum SyncOperationType {
  pushHistory,
  pushProgress,
  pushAchievements,
  pushStreak,
  pushSettings,
  pushMemory,
  pushAnalytics,
}

// ── SyncOperation ─────────────────────────────────────────────────────────────

class SyncOperation {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.enqueuedAt,
    this.retryCount = 0,
  });

  static const int maxRetries = 5;
  bool get isExhausted => retryCount >= maxRetries;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> j) => SyncOperation(
        id: j['id'] as String,
        type: SyncOperationType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => SyncOperationType.pushProgress,
        ),
        payload: j['payload'] as Map<String, dynamic>,
        enqueuedAt: DateTime.parse(j['enqueuedAt'] as String),
        retryCount: j['retryCount'] as int? ?? 0,
      );
}

// ── SyncConflictStrategy ──────────────────────────────────────────────────────

enum SyncConflictStrategy {
  newerWins,    // compare timestamps, keep the more recent record
  localWins,    // always prefer local unsynced work
  remoteWins,   // always prefer server data
  merge,        // combine both (used for analytics lists)
}

// ── SyncConflictResolver ──────────────────────────────────────────────────────

class SyncConflictResolver {
  SyncConflictResolver._();

  /// Resolve a conflict between [local] and [remote] data maps.
  /// Both must contain a 'updatedAt' ISO-8601 field for newerWins strategy.
  static Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    SyncConflictStrategy strategy,
  ) {
    return switch (strategy) {
      SyncConflictStrategy.localWins  => local,
      SyncConflictStrategy.remoteWins => remote,
      SyncConflictStrategy.newerWins  => _newerWins(local, remote),
      SyncConflictStrategy.merge      => _merge(local, remote),
    };
  }

  static Map<String, dynamic> _newerWins(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localTs  = _ts(local['updatedAt']);
    final remoteTs = _ts(remote['updatedAt']);
    return (remoteTs != null && (localTs == null || remoteTs.isAfter(localTs)))
        ? remote
        : local;
  }

  /// Merge strategy: concatenate list fields, take the max of numeric fields.
  static Map<String, dynamic> _merge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final result = Map<String, dynamic>.from(local);
    for (final entry in remote.entries) {
      final localVal  = result[entry.key];
      final remoteVal = entry.value;
      if (localVal is List && remoteVal is List) {
        // Deduplicate by converting to set of strings
        final merged = <String>{};
        for (final v in [...localVal, ...remoteVal]) {
          merged.add(v.toString());
        }
        result[entry.key] = merged.toList();
      } else if (localVal is num && remoteVal is num) {
        result[entry.key] = localVal > remoteVal ? localVal : remoteVal;
      } else {
        // Default: newer timestamp wins per field
        final localTs  = _ts(local['updatedAt']);
        final remoteTs = _ts(remote['updatedAt']);
        if (remoteTs != null &&
            (localTs == null || remoteTs.isAfter(localTs))) {
          result[entry.key] = remoteVal;
        }
      }
    }
    return result;
  }

  static DateTime? _ts(dynamic raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}

// ── SyncQueue ─────────────────────────────────────────────────────────────────

/// Offline-first sync queue. Enqueued operations are persisted to local
/// storage and flushed when connectivity is restored.
class SyncQueue {
  static const _kKey = 'sync_queue_v1';

  final List<SyncOperation> _queue = [];
  List<SyncOperation> get pending => List.unmodifiable(_queue);
  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _queue.addAll(
          list.map((e) => SyncOperation.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {
        // corrupt queue — start fresh
        await storage.saveSetting(_kKey, '');
      }
    }
  }

  // ── Enqueue ─────────────────────────────────────────────────────────────────

  Future<void> enqueue(
    SyncOperation op,
    StorageService storage,
  ) async {
    // Replace existing op of same type to avoid duplicates
    _queue.removeWhere((o) => o.type == op.type);
    _queue.add(op);
    await _persist(storage);
  }

  // ── Flush ────────────────────────────────────────────────────────────────────

  /// Flush queue by executing [handler] for each operation.
  /// Removes successful ops; increments retryCount on failure.
  Future<void> flush(
    Future<bool> Function(SyncOperation op) handler,
    StorageService storage,
  ) async {
    final toRemove = <String>[];
    for (final op in List<SyncOperation>.from(_queue)) {
      if (op.isExhausted) {
        toRemove.add(op.id);
        continue;
      }
      final success = await handler(op);
      if (success) {
        toRemove.add(op.id);
      } else {
        op.retryCount++;
      }
    }
    _queue.removeWhere((o) => toRemove.contains(o.id));
    await _persist(storage);
  }

  // ── Clear ─────────────────────────────────────────────────────────────────────

  Future<void> clear(StorageService storage) async {
    _queue.clear();
    await storage.saveSetting(_kKey, '');
  }

  Future<void> _persist(StorageService storage) async {
    await storage.saveSetting(
      _kKey,
      jsonEncode(_queue.map((o) => o.toJson()).toList()),
    );
  }
}
