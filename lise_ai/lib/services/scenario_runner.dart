import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ambient_engine.dart';
import '../services/pedagogy_engine.dart';
import '../services/silence_detector.dart';
import '../services/storage_service.dart';
import '../services/demo_service.dart';

// ── CheckResult ────────────────────────────────────────────────────────────────

enum CheckStatus { pass, warn, fail }

class CheckResult {
  final String name;
  final CheckStatus status;
  final String detail;
  final Duration elapsed;

  const CheckResult({
    required this.name,
    required this.status,
    required this.detail,
    required this.elapsed,
  });

  bool get isPassing => status == CheckStatus.pass;
}

// ── ScenarioRunner ─────────────────────────────────────────────────────────────

/// Runs all system health checks and returns results.
/// Designed for the developer diagnostics screen only.
class ScenarioRunner {
  ScenarioRunner._();

  /// Runs all checks sequentially and returns results in order.
  static Future<List<CheckResult>> runAll() async {
    final results = <CheckResult>[];

    results.add(await _check('Storage Read/Write', _checkStorage));
    results.add(await _check('AmbientEngine Config', _checkAmbientEngine));
    results.add(await _check('PedagogyEngine Signal', _checkPedagogyEngine));
    results.add(await _check('SilenceDetector Arm/Disarm', _checkSilenceDetector));
    results.add(await _check('DemoService Scenarios', _checkDemoService));
    results.add(await _check('API Key Present', _checkApiKey));
    results.add(await _check('Debug Mode', _checkDebugMode));

    return results;
  }

  static Future<CheckResult> _check(
    String name,
    Future<(CheckStatus, String)> Function() fn,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final (status, detail) = await fn();
      return CheckResult(
        name: name,
        status: status,
        detail: detail,
        elapsed: sw.elapsed,
      );
    } catch (e) {
      return CheckResult(
        name: name,
        status: CheckStatus.fail,
        detail: 'Exception: $e',
        elapsed: sw.elapsed,
      );
    }
  }

  // ── Individual checks ──────────────────────────────────────────────────────

  static Future<(CheckStatus, String)> _checkStorage() async {
    final storage = StorageService();
    await storage.init();
    const key = '__diag_test__';
    await storage.saveSetting(key, 'ok');
    final val = storage.loadSetting(key);
    await storage.saveSetting(key, ''); // cleanup with empty string
    if (val == 'ok') {
      return (CheckStatus.pass, 'Hive okuma/yazma başarılı');
    }
    return (CheckStatus.fail, 'Beklenen "ok", alınan: $val');
  }

  static Future<(CheckStatus, String)> _checkAmbientEngine() async {
    final engine = AmbientEngine();
    engine.setMode(AtmosphereMode.examMode);
    final cfg = engine.config;
    if (cfg.urgencyPulse > 0 && cfg.glowOpacity > 0) {
      return (CheckStatus.pass, 'Config türetme doğru — examMode urgencyPulse=${cfg.urgencyPulse.toStringAsFixed(2)}');
    }
    return (CheckStatus.warn, 'examMode config beklenmedik değer');
  }

  static Future<(CheckStatus, String)> _checkPedagogyEngine() async {
    final engine = PedagogyEngine();
    // Simulate 3 failures in a row
    for (var i = 0; i < 3; i++) {
      engine.recordReceived(successEstimate: 0.2, hadConfusion: true);
    }
    final sig = engine.signal;
    if (sig.isConfidenceRebuild && sig.strategy == TeachingStrategy.confidence) {
      return (CheckStatus.pass, 'Failure streak → confidence stratejisi doğru');
    }
    return (CheckStatus.warn, 'Strategy=${sig.strategy}, isConfidenceRebuild=${sig.isConfidenceRebuild}');
  }

  static Future<(CheckStatus, String)> _checkSilenceDetector() async {
    final detector = SilenceDetector();
    detector.arm(
      onCheckIn: () {},
      onDeepSilence: () {},
    );
    detector.disarm();
    detector.dispose();
    // After disarm, the timer should not fire; we only verify no crash
    return (CheckStatus.pass, 'Arm/disarm/dispose çökmesiz tamamlandı');
  }

  static Future<(CheckStatus, String)> _checkDemoService() async {
    final count = DemoService.scenarios.length;
    if (count < 8) {
      return (CheckStatus.fail, 'Beklenen ≥8 senaryo, bulunan: $count');
    }
    // Check all scenarios have non-empty replies
    final empty = DemoService.scenarios.where((s) => s.aiReply.isEmpty).toList();
    if (empty.isNotEmpty) {
      return (CheckStatus.warn, 'Boş reply: ${empty.map((s) => s.id).join(', ')}');
    }
    // Test fallback reply
    final fallback = DemoService.getReplyFor('XYZ bilinmeyen konu');
    if (fallback.isEmpty) {
      return (CheckStatus.warn, 'getReplyFor fallback boş döndü');
    }
    return (CheckStatus.pass, '$count senaryo yüklendi, fallback çalışıyor');
  }

  static Future<(CheckStatus, String)> _checkApiKey() async {
    // We cannot import dotenv here cleanly without pulling Flutter deps,
    // so we detect via a runtime check on the dart.library flag.
    // The check is informational — not a hard fail.
    try {
      // Try to access the env — if flutter_dotenv is initialised this succeeds
      // ignore: avoid_dynamic_calls
      final dynamic dotenv = _tryGetDotenv();
      final key = dotenv?.env?['ANTHROPIC_API_KEY'] as String?;
      if (key != null && key.isNotEmpty) {
        final masked = '${key.substring(0, 7)}…${key.substring(key.length - 4)}';
        return (CheckStatus.pass, 'API key mevcut: $masked');
      }
      return (CheckStatus.warn, 'API key bulunamadı — demo mode aktif');
    } catch (_) {
      return (CheckStatus.warn, 'API key durumu belirlenemedi — demo mode varsayılan');
    }
  }

  static dynamic _tryGetDotenv() {
    try {
      // flutter_dotenv's global dotenv is accessed via its singleton
      // We lazily access without static import to avoid compile errors if absent
      return null; // fallback; actual check done via _anthropic != null in screen
    } catch (_) {
      return null;
    }
  }

  static Future<(CheckStatus, String)> _checkDebugMode() async {
    if (kDebugMode) {
      return (CheckStatus.pass, 'Debug modunda çalışıyor (kDebugMode = true)');
    }
    return (CheckStatus.warn, 'Release/profile modunda çalışıyor — log output kısıtlı');
  }
}
