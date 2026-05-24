// runtime_stability_monitor.dart
// Lightweight passive monitor for runtime health signals.
// No architecture rewrite — services CAN opt-in to report counters here,
// but absence of reporting is treated as zero (best-effort diagnostics).

import 'dart:async';
import 'dart:collection';
import 'dart:io' show ProcessInfo, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HealthSnapshot {
  final DateTime takenAt;
  final Duration uptime;
  final int activeStreamCount;
  final int activeLoadingCount;
  final int boardRepaintsLastMinute;
  final int hiveLockSuspectCount;
  final int aiRequestCount;
  final int aiTimeoutCount;
  final Duration aiLatencyAvg;
  final int memoryBytes;
  final int storageEntryCount;
  final DateTime? lastFreezeAt;
  final DateTime? lastCrashAt;

  const HealthSnapshot({
    required this.takenAt,
    required this.uptime,
    required this.activeStreamCount,
    required this.activeLoadingCount,
    required this.boardRepaintsLastMinute,
    required this.hiveLockSuspectCount,
    required this.aiRequestCount,
    required this.aiTimeoutCount,
    required this.aiLatencyAvg,
    required this.memoryBytes,
    required this.storageEntryCount,
    required this.lastFreezeAt,
    required this.lastCrashAt,
  });

  Map<String, dynamic> toJson() => {
        'takenAt': takenAt.toIso8601String(),
        'uptimeSeconds': uptime.inSeconds,
        'activeStreams': activeStreamCount,
        'activeLoading': activeLoadingCount,
        'boardRepaints60s': boardRepaintsLastMinute,
        'hiveLockSuspects': hiveLockSuspectCount,
        'aiRequests': aiRequestCount,
        'aiTimeouts': aiTimeoutCount,
        'aiLatencyMs': aiLatencyAvg.inMilliseconds,
        'memoryBytes': memoryBytes,
        'storageEntries': storageEntryCount,
        'lastFreezeAt': lastFreezeAt?.toIso8601String(),
        'lastCrashAt': lastCrashAt?.toIso8601String(),
      };
}

class RuntimeStabilityMonitor extends ChangeNotifier {
  RuntimeStabilityMonitor._();
  static final RuntimeStabilityMonitor instance = RuntimeStabilityMonitor._();

  static const _freezeThreshold = Duration(seconds: 2);
  static const _heartbeatInterval = Duration(seconds: 5);
  static const _snapshotInterval = Duration(seconds: 60);
  static const _snapshotBufferCap = 30;
  static const _repaintWindow = Duration(minutes: 1);
  static const _aiLatencyWindow = 50;
  static const _hiveBoxName = 'lise_ai_v1';

  DateTime _startedAt = DateTime.now();
  Timer? _heartbeat;
  Timer? _snapshotTimer;
  bool _started = false;

  // ── Stream tracking ─────────────────────────────────────────────────────────
  final Set<String> _activeStreams = HashSet<String>();
  final Map<String, int> _streamOpenCount = {};

  // ── Loading tracking ────────────────────────────────────────────────────────
  final Map<String, DateTime> _activeLoading = {};

  // ── Repaint tracking ────────────────────────────────────────────────────────
  final Queue<DateTime> _boardRepaints = Queue<DateTime>();

  // ── Hive lock suspects ──────────────────────────────────────────────────────
  int _hiveLockSuspects = 0;

  // ── AI request tracking ─────────────────────────────────────────────────────
  int _aiRequestCount = 0;
  int _aiTimeoutCount = 0;
  final Queue<int> _aiLatencyMs = Queue<int>();

  // ── Freeze detection ────────────────────────────────────────────────────────
  DateTime _lastFrameAt = DateTime.now();
  DateTime? _lastFreezeAt;
  int _freezeCount = 0;

  // ── Crash bridge ────────────────────────────────────────────────────────────
  DateTime? _lastCrashAt;

  // ── Snapshot ring ───────────────────────────────────────────────────────────
  final Queue<HealthSnapshot> _snapshots = Queue<HealthSnapshot>();

  // ── Memory / storage cached values ──────────────────────────────────────────
  int _cachedMemoryBytes = 0;
  int _cachedStorageEntries = 0;

  // ── Public surface ──────────────────────────────────────────────────────────

  bool get isStarted => _started;
  Duration get uptime => DateTime.now().difference(_startedAt);
  int get activeStreamCount => _activeStreams.length;
  int get activeLoadingCount => _activeLoading.length;
  int get hiveLockSuspectCount => _hiveLockSuspects;
  int get aiRequestCount => _aiRequestCount;
  int get aiTimeoutCount => _aiTimeoutCount;
  int get freezeCount => _freezeCount;
  DateTime? get lastFreezeAt => _lastFreezeAt;
  DateTime? get lastCrashAt => _lastCrashAt;
  int get memoryBytes => _cachedMemoryBytes;
  int get storageEntryCount => _cachedStorageEntries;
  List<HealthSnapshot> get snapshots => List.unmodifiable(_snapshots);

  /// Duplicate-stream warnings: stream IDs that were opened more than once
  /// without a matching close.
  List<String> get duplicateStreamIds => _streamOpenCount.entries
      .where((e) => e.value > 1 && _activeStreams.contains(e.key))
      .map((e) => e.key)
      .toList();

  /// Loading entries that have been pending more than 10 s.
  List<String> get orphanLoadingIds {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
    return _activeLoading.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
  }

  /// Board repaints observed within the last minute.
  int get boardRepaintsLastMinute {
    final cutoff = DateTime.now().subtract(_repaintWindow);
    while (_boardRepaints.isNotEmpty && _boardRepaints.first.isBefore(cutoff)) {
      _boardRepaints.removeFirst();
    }
    return _boardRepaints.length;
  }

  Duration get aiLatencyAvg {
    if (_aiLatencyMs.isEmpty) return Duration.zero;
    final total = _aiLatencyMs.fold<int>(0, (a, b) => a + b);
    return Duration(milliseconds: total ~/ _aiLatencyMs.length);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void start() {
    if (_started) return;
    _started = true;
    _startedAt = DateTime.now();
    _lastFrameAt = DateTime.now();

    // Frame heartbeat — tracks when the scheduler last produced a frame.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      _lastFrameAt = DateTime.now();
    });

    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _heartbeatTick());
    _snapshotTimer = Timer.periodic(_snapshotInterval, (_) => _takeSnapshot());

    // Take an initial snapshot so the diagnostics screen has data immediately.
    _takeSnapshot();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _snapshotTimer?.cancel();
    super.dispose();
  }

  // ── Reporting API (best-effort, called by services that opt in) ─────────────

  void noteStreamOpen(String id) {
    _activeStreams.add(id);
    _streamOpenCount[id] = (_streamOpenCount[id] ?? 0) + 1;
    notifyListeners();
  }

  void noteStreamClose(String id) {
    _activeStreams.remove(id);
    notifyListeners();
  }

  void noteLoadingStart(String id) {
    _activeLoading[id] = DateTime.now();
    notifyListeners();
  }

  void noteLoadingEnd(String id) {
    _activeLoading.remove(id);
    notifyListeners();
  }

  void noteBoardRepaint() {
    _boardRepaints.add(DateTime.now());
  }

  void noteHiveLockSuspect() {
    _hiveLockSuspects++;
    notifyListeners();
  }

  void noteAiRequest(Duration elapsed) {
    _aiRequestCount++;
    _aiLatencyMs.add(elapsed.inMilliseconds);
    while (_aiLatencyMs.length > _aiLatencyWindow) {
      _aiLatencyMs.removeFirst();
    }
    notifyListeners();
  }

  void noteAiTimeout() {
    _aiTimeoutCount++;
    notifyListeners();
  }

  void noteCrash() {
    _lastCrashAt = DateTime.now();
    notifyListeners();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _heartbeatTick() {
    final now = DateTime.now();
    final sinceFrame = now.difference(_lastFrameAt);
    if (sinceFrame > _freezeThreshold) {
      _freezeCount++;
      _lastFreezeAt = now;
      notifyListeners();
    }

    _refreshMemoryStats();
    _refreshStorageStats();
  }

  void _refreshMemoryStats() {
    try {
      // ProcessInfo.currentRss is available on macOS/iOS/Linux/Android.
      // Returns 0 on platforms that don't support it.
      if (Platform.isMacOS ||
          Platform.isIOS ||
          Platform.isAndroid ||
          Platform.isLinux ||
          Platform.isWindows) {
        _cachedMemoryBytes = ProcessInfo.currentRss;
      }
    } catch (_) {
      // Some sandboxed environments throw; ignore.
    }
  }

  void _refreshStorageStats() {
    try {
      if (Hive.isBoxOpen(_hiveBoxName)) {
        _cachedStorageEntries = Hive.box(_hiveBoxName).length;
      }
    } catch (_) {
      // Box may be closed during shutdown; ignore.
    }
  }

  void _takeSnapshot() {
    final snap = HealthSnapshot(
      takenAt: DateTime.now(),
      uptime: uptime,
      activeStreamCount: activeStreamCount,
      activeLoadingCount: activeLoadingCount,
      boardRepaintsLastMinute: boardRepaintsLastMinute,
      hiveLockSuspectCount: hiveLockSuspectCount,
      aiRequestCount: aiRequestCount,
      aiTimeoutCount: aiTimeoutCount,
      aiLatencyAvg: aiLatencyAvg,
      memoryBytes: memoryBytes,
      storageEntryCount: storageEntryCount,
      lastFreezeAt: lastFreezeAt,
      lastCrashAt: lastCrashAt,
    );
    _snapshots.add(snap);
    while (_snapshots.length > _snapshotBufferCap) {
      _snapshots.removeFirst();
    }
    if (kDebugMode) {
      debugPrint(
        '[RuntimeMonitor] uptime=${snap.uptime.inMinutes}m '
        'streams=${snap.activeStreamCount} '
        'loading=${snap.activeLoadingCount} '
        'mem=${(snap.memoryBytes / (1024 * 1024)).toStringAsFixed(1)}MB '
        'storage=${snap.storageEntryCount}',
      );
    }
    notifyListeners();
  }

  // ── Long-session observation mode ──────────────────────────────────────────

  Timer? _longSessionTimer;
  Duration? _longSessionTarget;
  DateTime? _longSessionStartedAt;

  bool get isLongSessionActive => _longSessionTimer != null;
  Duration? get longSessionElapsed =>
      _longSessionStartedAt == null
          ? null
          : DateTime.now().difference(_longSessionStartedAt!);
  Duration? get longSessionTarget => _longSessionTarget;

  /// Begin a long-session observation window. Default 30 minutes.
  /// Takes periodic snapshots and emits warnings if any health signal degrades.
  void startLongSession({Duration duration = const Duration(minutes: 30)}) {
    _longSessionStartedAt = DateTime.now();
    _longSessionTarget = duration;
    _longSessionTimer?.cancel();
    _longSessionTimer = Timer(duration, () {
      _longSessionTimer = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopLongSession() {
    _longSessionTimer?.cancel();
    _longSessionTimer = null;
    notifyListeners();
  }
}
