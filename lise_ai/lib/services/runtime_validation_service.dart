// runtime_validation_service.dart
// Active stability test suite — exercises the runtime end-to-end without
// touching real backends. Each check is self-contained and reports a
// pass/warn/fail status with timing.

import 'dart:async';

import '../services/connectivity_service.dart';
import '../services/runtime_stability_monitor.dart';
import '../services/storage_service.dart';

enum ValidationStatus { pass, warn, fail }

class ValidationCheck {
  final String name;
  final ValidationStatus status;
  final String detail;
  final Duration elapsed;

  const ValidationCheck({
    required this.name,
    required this.status,
    required this.detail,
    required this.elapsed,
  });

  String get icon => switch (status) {
        ValidationStatus.pass => '✅',
        ValidationStatus.warn => '⚠️',
        ValidationStatus.fail => '❌',
      };
}

class ValidationReport {
  final List<ValidationCheck> checks;
  final DateTime generatedAt;
  final Duration totalElapsed;

  const ValidationReport({
    required this.checks,
    required this.generatedAt,
    required this.totalElapsed,
  });

  int get passCount => checks.where((c) => c.status == ValidationStatus.pass).length;
  int get warnCount => checks.where((c) => c.status == ValidationStatus.warn).length;
  int get failCount => checks.where((c) => c.status == ValidationStatus.fail).length;

  bool get isClean => failCount == 0;

  String get verdict => isClean
      ? '✅ Doğrulama temiz — $passCount geçti, $warnCount uyarı'
      : '❌ Doğrulamada $failCount kritik hata bulundu';
}

class RuntimeValidationService {
  RuntimeValidationService._();
  static final RuntimeValidationService instance = RuntimeValidationService._();

  bool _isRunning = false;
  ValidationReport? _lastReport;

  bool get isRunning => _isRunning;
  ValidationReport? get lastReport => _lastReport;

  /// Run all validation scenarios sequentially.
  /// [storage] and [connectivity] are required for the round-trip checks.
  Future<ValidationReport> runAll({
    required StorageService storage,
    required ConnectivityService connectivity,
    void Function(String)? onLog,
  }) async {
    _isRunning = true;
    final overall = Stopwatch()..start();
    final checks = <ValidationCheck>[];
    final log = onLog ?? ((_) {});

    log('🧪 Doğrulama süiti başladı');

    checks.add(await _check(
      name: 'Hızlı sohbet gönderimleri',
      run: () => _simulateRapidChatSends(20),
    ));

    checks.add(await _check(
      name: 'Bağlantı durumu okuma',
      run: () => _checkConnectivityRead(connectivity),
    ));

    checks.add(await _check(
      name: 'Bellek geri yükleme döngüsü',
      run: () => _simulateMemoryRestore(storage),
    ));

    checks.add(await _check(
      name: 'Büyük konuşma kaydet / yükle',
      run: () => _simulateLargeConversation(storage, 120),
    ));

    checks.add(await _check(
      name: 'Tahta tekrar boyama yükü',
      run: () => _simulateBoardOperations(80),
    ));

    checks.add(await _check(
      name: 'Yinelenen dinleyici tespiti',
      run: () => _checkNoDuplicateListeners(),
    ));

    checks.add(await _check(
      name: 'Zombi zamanlayıcı tespiti',
      run: () => _checkNoZombieTimers(),
    ));

    checks.add(await _check(
      name: 'AI istek zaman aşımı sayacı',
      run: () => _checkAiTimeoutBudget(),
    ));

    checks.add(await _check(
      name: 'Yetim yükleme tespiti',
      run: () => _checkNoOrphanLoading(),
    ));

    overall.stop();

    final report = ValidationReport(
      checks: checks,
      generatedAt: DateTime.now(),
      totalElapsed: overall.elapsed,
    );
    _lastReport = report;
    _isRunning = false;

    log('${report.verdict} (${overall.elapsed.inMilliseconds}ms)');

    return report;
  }

  // ── Individual checks ──────────────────────────────────────────────────────

  Future<_CheckResult> _simulateRapidChatSends(int count) async {
    final monitor = RuntimeStabilityMonitor.instance;
    final beforeStreams = monitor.activeStreamCount;
    for (int i = 0; i < count; i++) {
      final id = 'sim_chat_$i';
      monitor.noteStreamOpen(id);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      monitor.noteStreamClose(id);
    }
    final afterStreams = monitor.activeStreamCount;
    if (afterStreams != beforeStreams) {
      return _CheckResult(
        ValidationStatus.fail,
        'Açık akış sızıntısı: $beforeStreams → $afterStreams',
      );
    }
    if (monitor.duplicateStreamIds.isNotEmpty) {
      return _CheckResult(
        ValidationStatus.warn,
        'Yinelenen akış ID: ${monitor.duplicateStreamIds.join(", ")}',
      );
    }
    return _CheckResult(ValidationStatus.pass, '$count akış temiz açıldı ve kapandı');
  }

  Future<_CheckResult> _checkConnectivityRead(
      ConnectivityService connectivity) async {
    final state = connectivity.isOnline;
    return _CheckResult(
      ValidationStatus.pass,
      'Bağlantı durumu okundu: ${state ? "online" : "offline"}',
    );
  }

  Future<_CheckResult> _simulateMemoryRestore(StorageService storage) async {
    final id = 'validation_${DateTime.now().millisecondsSinceEpoch}';
    final conv = StoredConversation(
      id: id,
      title: 'Doğrulama oturumu',
      createdAt: DateTime.now(),
      messages: [
        StoredMessage(
          text: 'Merhaba, doğrulama mesajı.',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      ],
    );
    try {
      await storage.saveConversation(conv);
      final restored = await storage.loadConversation(id);
      await storage.deleteConversation(id);
      if (restored == null) {
        return _CheckResult(
            ValidationStatus.fail, 'Konuşma kaydedildi fakat geri yüklenemedi');
      }
      if (restored.messages.length != 1) {
        return _CheckResult(
            ValidationStatus.fail, 'Mesaj sayısı eşleşmiyor: ${restored.messages.length}');
      }
      return _CheckResult(
          ValidationStatus.pass, 'Kaydet → yükle → sil döngüsü temiz');
    } catch (e) {
      return _CheckResult(ValidationStatus.fail, 'Hive hatası: $e');
    }
  }

  Future<_CheckResult> _simulateLargeConversation(
      StorageService storage, int messageCount) async {
    final id = 'large_${DateTime.now().millisecondsSinceEpoch}';
    final messages = List.generate(
      messageCount,
      (i) => StoredMessage(
        text: 'Test mesajı $i — uzun bir konuşma simülasyonu için.',
        isUser: i.isEven,
        timestamp: DateTime.now(),
      ),
    );
    final conv = StoredConversation(
      id: id,
      title: 'Büyük konuşma',
      createdAt: DateTime.now(),
      messages: messages,
    );
    final sw = Stopwatch()..start();
    try {
      await storage.saveConversation(conv);
      final restored = await storage.loadConversation(id);
      await storage.deleteConversation(id);
      sw.stop();
      if (restored == null || restored.messages.length != messageCount) {
        return _CheckResult(
            ValidationStatus.fail,
            'Geri yükleme başarısız: beklenen $messageCount, '
            'gelen ${restored?.messages.length ?? 0}');
      }
      if (sw.elapsedMilliseconds > 2000) {
        return _CheckResult(
            ValidationStatus.warn,
            '$messageCount mesajlık döngü ${sw.elapsedMilliseconds}ms sürdü');
      }
      return _CheckResult(
          ValidationStatus.pass,
          '$messageCount mesaj ${sw.elapsedMilliseconds}ms içinde döngüsü tamamlandı');
    } catch (e) {
      return _CheckResult(ValidationStatus.fail, 'Hive yazma hatası: $e');
    }
  }

  Future<_CheckResult> _simulateBoardOperations(int count) async {
    final monitor = RuntimeStabilityMonitor.instance;
    for (int i = 0; i < count; i++) {
      monitor.noteBoardRepaint();
    }
    final observed = monitor.boardRepaintsLastMinute;
    if (observed < count) {
      return _CheckResult(
        ValidationStatus.warn,
        '$count tahta tekrar boyama bildirildi, $observed kaydedildi',
      );
    }
    return _CheckResult(
      ValidationStatus.pass,
      '$count tahta tekrar boyama temiz kaydedildi',
    );
  }

  Future<_CheckResult> _checkNoDuplicateListeners() async {
    final monitor = RuntimeStabilityMonitor.instance;
    final dups = monitor.duplicateStreamIds;
    if (dups.isEmpty) {
      return _CheckResult(
          ValidationStatus.pass, 'Yinelenen aktif akış bulunamadı');
    }
    return _CheckResult(
      ValidationStatus.warn,
      'Yinelenen akış ID tespit edildi: ${dups.length}',
    );
  }

  Future<_CheckResult> _checkNoZombieTimers() async {
    // Best-effort: heartbeat exists and produced at least one snapshot.
    final monitor = RuntimeStabilityMonitor.instance;
    if (!monitor.isStarted) {
      return _CheckResult(
          ValidationStatus.warn, 'Monitör başlatılmamış');
    }
    return _CheckResult(
      ValidationStatus.pass,
      'Monitör aktif, anlık görüntü sayısı: ${monitor.snapshots.length}',
    );
  }

  Future<_CheckResult> _checkAiTimeoutBudget() async {
    final monitor = RuntimeStabilityMonitor.instance;
    final timeouts = monitor.aiTimeoutCount;
    final total = monitor.aiRequestCount;
    if (total == 0) {
      return _CheckResult(
        ValidationStatus.pass,
        'Henüz AI isteği yok — bütçe ihlali yok',
      );
    }
    final ratio = timeouts / total;
    if (ratio > 0.1) {
      return _CheckResult(
        ValidationStatus.fail,
        'Zaman aşımı oranı yüksek: $timeouts / $total (${(ratio * 100).toStringAsFixed(1)}%)',
      );
    }
    if (ratio > 0.02) {
      return _CheckResult(
        ValidationStatus.warn,
        'Zaman aşımı sınırda: $timeouts / $total',
      );
    }
    return _CheckResult(
      ValidationStatus.pass,
      'Zaman aşımı sağlıklı: $timeouts / $total',
    );
  }

  Future<_CheckResult> _checkNoOrphanLoading() async {
    final monitor = RuntimeStabilityMonitor.instance;
    final orphans = monitor.orphanLoadingIds;
    if (orphans.isEmpty) {
      return _CheckResult(
          ValidationStatus.pass, 'Yetim yükleme yok');
    }
    return _CheckResult(
      ValidationStatus.warn,
      'Yetim yükleme tespit edildi: ${orphans.length}',
    );
  }

  // ── Wrapper ────────────────────────────────────────────────────────────────

  Future<ValidationCheck> _check({
    required String name,
    required Future<_CheckResult> Function() run,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final r = await run();
      sw.stop();
      return ValidationCheck(
        name: name,
        status: r.status,
        detail: r.detail,
        elapsed: sw.elapsed,
      );
    } catch (e, st) {
      sw.stop();
      return ValidationCheck(
        name: name,
        status: ValidationStatus.fail,
        detail: 'İstisna: $e\n$st',
        elapsed: sw.elapsed,
      );
    }
  }
}

class _CheckResult {
  final ValidationStatus status;
  final String detail;
  const _CheckResult(this.status, this.detail);
}
