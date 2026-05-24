import 'dart:convert';
import '../services/storage_service.dart';

// ── TelemetryEvent ─────────────────────────────────────────────────────────────

enum TelemetryEventType {
  lessonStarted,
  lessonCompleted,
  confusionSpike,
  visualModeOpened,
  boardOpened,
  voiceModeUsed,
  sessionDuration,
  onboardingCompleted,
  streakRecovery,
  achievementUnlocked,
  examCampStarted,
  examCampCompleted,
  pdfUploaded,
  imageAnalyzed,
  settingsOpened,
  dashboardOpened,
}

class TelemetryEvent {
  final String id;
  final TelemetryEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> properties;
  bool isSynced;

  TelemetryEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.properties = const {},
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'properties': properties,
        'isSynced': isSynced,
      };

  factory TelemetryEvent.fromJson(Map<String, dynamic> j) => TelemetryEvent(
        id: j['id'] as String,
        type: TelemetryEventType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => TelemetryEventType.lessonStarted,
        ),
        timestamp: DateTime.parse(j['timestamp'] as String),
        properties: (j['properties'] as Map?)?.cast<String, dynamic>() ?? {},
        isSynced: j['isSynced'] as bool? ?? false,
      );
}

// ── TelemetryService ───────────────────────────────────────────────────────────

/// Local-first telemetry. Events are queued on device and can be flushed
/// to a backend when connectivity is available.
///
/// Queue is capped at [_maxQueueSize] events; oldest are discarded on overflow.
class TelemetryService {
  static const _kKey = 'telemetry_queue_v1';
  static const int _maxQueueSize = 500;

  final List<TelemetryEvent> _queue = [];
  int _eventCounter = 0;

  List<TelemetryEvent> get queue => List.unmodifiable(_queue);
  int get queueSize => _queue.length;
  int get unsyncedCount => _queue.where((e) => !e.isSynced).length;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _queue.addAll(
          list.map((e) => TelemetryEvent.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {
        await storage.saveSetting(_kKey, '');
      }
    }
  }

  // ── Track ────────────────────────────────────────────────────────────────────

  Future<void> track(
    TelemetryEventType type, {
    Map<String, dynamic> properties = const {},
    StorageService? storage,
  }) async {
    _eventCounter++;
    final event = TelemetryEvent(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}_$_eventCounter',
      type: type,
      timestamp: DateTime.now(),
      properties: properties,
    );

    _queue.add(event);

    // Evict oldest events to keep queue bounded.
    while (_queue.length > _maxQueueSize) {
      _queue.removeAt(0);
    }

    if (storage != null) await _persist(storage);
  }

  // ── Convenience event builders ───────────────────────────────────────────────

  Future<void> lessonStarted({required String topic, required String mode, StorageService? storage}) =>
      track(TelemetryEventType.lessonStarted,
          properties: {'topic': topic, 'mode': mode}, storage: storage);

  Future<void> lessonCompleted({
    required String topic,
    required int durationSeconds,
    required double successEstimate,
    StorageService? storage,
  }) =>
      track(TelemetryEventType.lessonCompleted, properties: {
        'topic': topic,
        'durationSeconds': durationSeconds,
        'successEstimate': successEstimate,
      }, storage: storage);

  Future<void> confusionSpike({required String topic, StorageService? storage}) =>
      track(TelemetryEventType.confusionSpike,
          properties: {'topic': topic}, storage: storage);

  Future<void> voiceModeUsed({required String modeLabel, StorageService? storage}) =>
      track(TelemetryEventType.voiceModeUsed,
          properties: {'mode': modeLabel}, storage: storage);

  Future<void> boardOpened({StorageService? storage}) =>
      track(TelemetryEventType.boardOpened, storage: storage);

  Future<void> visualModeOpened({StorageService? storage}) =>
      track(TelemetryEventType.visualModeOpened, storage: storage);

  Future<void> sessionEnded({required int durationSeconds, StorageService? storage}) =>
      track(TelemetryEventType.sessionDuration,
          properties: {'durationSeconds': durationSeconds}, storage: storage);

  Future<void> onboardingCompleted({StorageService? storage}) =>
      track(TelemetryEventType.onboardingCompleted, storage: storage);

  Future<void> streakRecovery({required int streak, StorageService? storage}) =>
      track(TelemetryEventType.streakRecovery,
          properties: {'streak': streak}, storage: storage);

  Future<void> achievementUnlocked({required String achievementId, StorageService? storage}) =>
      track(TelemetryEventType.achievementUnlocked,
          properties: {'achievementId': achievementId}, storage: storage);

  // ── Flush ────────────────────────────────────────────────────────────────────

  /// Mark all queued events as synced (call after successful remote upload).
  void markAllSynced() {
    for (final e in _queue) { e.isSynced = true; }
  }

  /// Remove all synced events.
  Future<void> prunesynced(StorageService storage) async {
    _queue.removeWhere((e) => e.isSynced);
    await _persist(storage);
  }

  // ── Persist ──────────────────────────────────────────────────────────────────

  Future<void> _persist(StorageService storage) async {
    final json = jsonEncode(_queue.map((e) => e.toJson()).toList());
    await storage.saveSetting(_kKey, json);
  }
}
