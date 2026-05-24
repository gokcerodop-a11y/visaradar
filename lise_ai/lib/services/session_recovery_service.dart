import 'dart:convert';
import '../services/storage_service.dart';

// ── SessionSnapshot ────────────────────────────────────────────────────────────

class SessionSnapshot {
  final String? lastTopic;
  final int historyLength;
  final String? lastSubtitle;
  final String? emotionalState;  // TeacherEmotionalState.name
  final String? lessonMode;      // LessonMode.name
  final DateTime savedAt;

  const SessionSnapshot({
    this.lastTopic,
    this.historyLength = 0,
    this.lastSubtitle,
    this.emotionalState,
    this.lessonMode,
    required this.savedAt,
  });

  bool get isRecoverable =>
      (lastTopic != null || historyLength > 0) &&
      DateTime.now().difference(savedAt).inHours < 24;

  Map<String, dynamic> toJson() => {
        'lastTopic': lastTopic,
        'historyLength': historyLength,
        'lastSubtitle': lastSubtitle,
        'emotionalState': emotionalState,
        'lessonMode': lessonMode,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SessionSnapshot.fromJson(Map<String, dynamic> j) => SessionSnapshot(
        lastTopic: j['lastTopic'] as String?,
        historyLength: j['historyLength'] as int? ?? 0,
        lastSubtitle: j['lastSubtitle'] as String?,
        emotionalState: j['emotionalState'] as String?,
        lessonMode: j['lessonMode'] as String?,
        savedAt: DateTime.parse(j['savedAt'] as String),
      );
}

// ── SessionRecoveryService ────────────────────────────────────────────────────

class SessionRecoveryService {
  static const _kKey = 'session_snapshot_v1';

  SessionSnapshot? _pending;

  /// The snapshot from the previous session, if recoverable.
  SessionSnapshot? get pendingRecovery => _pending;
  bool get hasRecovery => _pending?.isRecoverable == true;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final snap = SessionSnapshot.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        if (snap.isRecoverable) {
          _pending = snap;
        } else {
          await _clear(storage);
        }
      } catch (_) {
        await _clear(storage);
      }
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Call after each AI response to persist current session state.
  Future<void> save(SessionSnapshot snap, StorageService storage) async {
    await storage.saveSetting(_kKey, jsonEncode(snap.toJson()));
  }

  // ── Consume ─────────────────────────────────────────────────────────────────

  /// Mark recovery as consumed — call after successfully restoring session.
  Future<void> consume(StorageService storage) async {
    _pending = null;
    await _clear(storage);
  }

  // ── Clear ────────────────────────────────────────────────────────────────────

  /// Call at clean session end (user explicitly ended session).
  Future<void> clearOnCleanExit(StorageService storage) async {
    _pending = null;
    await _clear(storage);
  }

  Future<void> _clear(StorageService storage) async {
    await storage.saveSetting(_kKey, '');
  }
}
