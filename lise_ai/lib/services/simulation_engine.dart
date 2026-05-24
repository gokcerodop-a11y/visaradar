// simulation_engine.dart
// Core simulation state for the local production simulation environment.
// Singleton — access via SimulationEngine.instance.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../services/subscription_service.dart';

// ── NetworkProfile ─────────────────────────────────────────────────────────────

enum NetworkProfile { fast, slow, timeout, intermittent, offline }

extension NetworkProfileExt on NetworkProfile {
  String get label => switch (this) {
        NetworkProfile.fast         => 'Hızlı',
        NetworkProfile.slow         => 'Yavaş',
        NetworkProfile.timeout      => 'Zaman Aşımı',
        NetworkProfile.intermittent => 'Kesintili',
        NetworkProfile.offline      => 'Çevrimdışı',
      };

  int get latencyMs => switch (this) {
        NetworkProfile.fast         => 80,
        NetworkProfile.slow         => 2400,
        NetworkProfile.timeout      => 12000,
        NetworkProfile.intermittent => 1200,
        NetworkProfile.offline      => 0,
      };

  double get failureRate => switch (this) {
        NetworkProfile.fast         => 0.0,
        NetworkProfile.slow         => 0.05,
        NetworkProfile.timeout      => 1.0,
        NetworkProfile.intermittent => 0.35,
        NetworkProfile.offline      => 1.0,
      };

  String get icon => switch (this) {
        NetworkProfile.fast         => '⚡',
        NetworkProfile.slow         => '🐢',
        NetworkProfile.timeout      => '⏱️',
        NetworkProfile.intermittent => '📶',
        NetworkProfile.offline      => '🚫',
      };
}

// ── FakeAIProvider ─────────────────────────────────────────────────────────────

enum FakeAIProvider { claude, openai, gemini, offlineDemo }

extension FakeAIProviderExt on FakeAIProvider {
  String get label => switch (this) {
        FakeAIProvider.claude      => 'Claude Sonnet',
        FakeAIProvider.openai      => 'OpenAI GPT-4o',
        FakeAIProvider.gemini      => 'Google Gemini',
        FakeAIProvider.offlineDemo => 'Demo Modu',
      };

  bool get isOffline => this == FakeAIProvider.offlineDemo;

  String get responsePrefix => switch (this) {
        FakeAIProvider.claude      => '[Claude] ',
        FakeAIProvider.openai      => '[GPT-4o] ',
        FakeAIProvider.gemini      => '[Gemini] ',
        FakeAIProvider.offlineDemo => '[Demo] ',
      };
}

// ── BackendOpResult ────────────────────────────────────────────────────────────

class BackendOpResult {
  final String operationName;
  final bool success;
  final int latencyMs;
  final String detail;
  final DateTime timestamp;

  const BackendOpResult._({
    required this.operationName,
    required this.success,
    required this.latencyMs,
    required this.detail,
    required this.timestamp,
  });

  static BackendOpResult pass(String name, int latencyMs, String detail) =>
      BackendOpResult._(
        operationName: name,
        success: true,
        latencyMs: latencyMs,
        detail: detail,
        timestamp: DateTime.now(),
      );

  static BackendOpResult fail(String name, int latencyMs, String reason) =>
      BackendOpResult._(
        operationName: name,
        success: false,
        latencyMs: latencyMs,
        detail: reason,
        timestamp: DateTime.now(),
      );
}

// ── SimulationEngine ──────────────────────────────────────────────────────────

class SimulationEngine extends ChangeNotifier {
  SimulationEngine._();

  static final SimulationEngine instance = SimulationEngine._();

  NetworkProfile networkProfile = NetworkProfile.fast;
  FakeAIProvider aiProvider = FakeAIProvider.claude;
  SubscriptionTier fakeSubscriptionTier = SubscriptionTier.free;
  bool isSimulationActive = false;
  final List<BackendOpResult> backendLog = [];
  int _opCounter = 0;

  // ── Setters ─────────────────────────────────────────────────────────────────

  void setNetworkProfile(NetworkProfile p) {
    networkProfile = p;
    notifyListeners();
  }

  void setAIProvider(FakeAIProvider p) {
    aiProvider = p;
    notifyListeners();
  }

  void setSubscriptionTier(SubscriptionTier t) {
    fakeSubscriptionTier = t;
    notifyListeners();
  }

  void setSimulationActive(bool v) {
    isSimulationActive = v;
    notifyListeners();
  }

  // ── Internal op runner ──────────────────────────────────────────────────────

  Future<BackendOpResult> _runOp(String name, String successDetail) async {
    _opCounter++;

    // Cap the sleep to avoid blocking the UI for too long.
    final sleepMs = networkProfile == NetworkProfile.timeout
        ? 800
        : networkProfile.latencyMs.clamp(0, 8000);

    if (sleepMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: sleepMs));
    }

    final BackendOpResult result;

    if (networkProfile == NetworkProfile.offline) {
      result = BackendOpResult.fail(name, sleepMs, 'Çevrimdışı — bağlantı yok');
    } else if (math.Random().nextDouble() < networkProfile.failureRate) {
      result = BackendOpResult.fail(name, sleepMs, 'İşlem başarısız — ağ hatası');
    } else {
      result = BackendOpResult.pass(name, sleepMs, successDetail);
    }

    backendLog.add(result);
    if (backendLog.length > 50) {
      backendLog.removeAt(0);
    }

    notifyListeners();
    return result;
  }

  // ── Public simulation methods ───────────────────────────────────────────────

  Future<BackendOpResult> simulateLogin() =>
      _runOp('Giriş / Auth', 'Token alındı — kullanıcı doğrulandı');

  Future<BackendOpResult> simulateCloudSync() =>
      _runOp('Bulut Senkronizasyonu',
          '${3 + _opCounter % 7} kayıt senkronize edildi');

  Future<BackendOpResult> simulateSubscriptionFetch() => _runOp(
        'Abonelik Durumu',
        '${fakeSubscriptionTier.label} aktif — son doğrulama: şimdi',
      );

  Future<BackendOpResult> simulateLessonUpload() =>
      _runOp('Ders Yükleme', '${4 + _opCounter % 12} ders sahnesi yüklendi');

  Future<BackendOpResult> simulateAnalyticsUpload() =>
      _runOp('Analitik Yükleme', '${10 + _opCounter % 40} olay iletildi');

  Future<List<BackendOpResult>> replayOfflineQueue(int count) async {
    final results = <BackendOpResult>[];
    for (var i = 0; i < count; i++) {
      final result = i.isEven
          ? await simulateLessonUpload()
          : await simulateAnalyticsUpload();
      results.add(result);
    }
    return results;
  }

  void clearLog() {
    backendLog.clear();
    notifyListeners();
  }

  // ── Fake AI reply generator ─────────────────────────────────────────────────

  String generateFakeReply(String userText) {
    final prefix = aiProvider.responsePrefix;

    final String body;
    switch (aiProvider) {
      case FakeAIProvider.claude:
        body = 'Bu konuyu daha iyi anlamak için önce temel kavramları '
            'ele alalım. "$userText" sorusu için adım adım ilerleyelim: '
            'önce tanımı, ardından örnekleri ve son olarak pratik uygulamayı '
            'inceleyeceğiz. Herhangi bir adımda duraksamamı ister misin?';
      case FakeAIProvider.openai:
        body = '"$userText" sorunuzu analiz ettim. Konuyu üç başlık altında '
            'inceleyebiliriz: (1) Teorik arka plan, (2) Çözüm yöntemi, '
            '(3) Benzer soru tipleri. Hangi başlıktan başlamak istersin?';
      case FakeAIProvider.gemini:
        body = 'Merhaba! "$userText" konusunda sana yardımcı olmaktan '
            'memnuniyet duyarım. Bu konu Türkiye müfredatında önemli bir yer '
            'tutuyor. Açıklamaya genel bir bakışla başlayalım, sonra soru '
            'çözümüne geçeriz. Hazır mısın?';
      case FakeAIProvider.offlineDemo:
        body = '(Çevrimdışı demo yanıtı) "$userText" sorusu alındı. '
            'İnternet bağlantısı olmadan yalnızca önbelleğe alınmış içerikler '
            'kullanılabilir. Bağlantı kurulduğunda tam yanıt alabilirsin.';
    }

    return '$prefix$body';
  }
}
