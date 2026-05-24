// simulation_lab_screen.dart
// Full simulation / QA / developer screen — 8 tabs.
// No real network calls are made from this screen.

import 'package:flutter/material.dart';
import '../core/feature_flags.dart';
import '../services/simulation_engine.dart';
import '../services/stress_test_runner.dart';
import '../services/release_validator.dart';
import '../services/subscription_service.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';
import '../services/ai_cost_tracker.dart';
import '../services/haptics_service.dart';

// ── Color constants ────────────────────────────────────────────────────────────

const _kBg      = Color(0xFF050510);
const _kSurface = Color(0xFF0A0A18);
const _kCard    = Color(0xFF0F0F1E);
const _kBorder  = Color(0xFF1F2937);
const _kAccent  = Color(0xFF7C6BF8);
const _kMuted   = Color(0xFF4B5563);
const _kText    = Color(0xFFE8E8FF);
const _kSub     = Color(0xFF8888AA);
const _kRed     = Color(0xFFEF4444);
const _kGreen   = Color(0xFF4ADE80);
const _kYellow  = Color(0xFFFBBF24);
// ignore: unused_element
const _kBlue    = Color(0xFF60A5FA);

// ── Main Widget ────────────────────────────────────────────────────────────────

class SimulationLabScreen extends StatefulWidget {
  final StorageService storage;
  final TelemetryService telemetrySvc;
  final AICostTracker costTracker;

  const SimulationLabScreen({
    super.key,
    required this.storage,
    required this.telemetrySvc,
    required this.costTracker,
  });

  @override
  State<SimulationLabScreen> createState() => _SimLabState();
}

class _SimLabState extends State<SimulationLabScreen> with TickerProviderStateMixin {
  TabController? _tabCtrl;

  // Stress test
  bool _stressRunning = false;
  StressTestStats? _stressResult;
  List<String> _stressLog = [];

  // RC Validation
  bool _rcRunning = false;
  RCReport? _rcReport;
  List<String> _rcLog = [];

  // QA reset confirm state
  Set<int> _confirming = {};

  // Developer tools
  late TextEditingController _tokenCtrl;
  String _tokenText = '';

  // Backend running flag
  bool _backendRunning = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 8, vsync: this);
    _tokenCtrl = TextEditingController();
    _tokenCtrl.addListener(() {
      if (mounted) setState(() => _tokenText = _tokenCtrl.text);
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  // ── Stress Test ──────────────────────────────────────────────────────────────

  Future<void> _runStressTest() async {
    if (_stressRunning) return;
    setState(() {
      _stressRunning = true;
      _stressLog = [];
      _stressResult = null;
    });
    await HapticsService.heavy();
    final result = await StressTestRunner.instance.run(
      onLog: (msg) {
        if (mounted) setState(() => _stressLog.add(msg));
      },
    );
    if (mounted) setState(() { _stressRunning = false; _stressResult = result; });
  }

  // ── RC Validation ────────────────────────────────────────────────────────────

  Future<void> _runRCValidation() async {
    if (_rcRunning) return;
    setState(() {
      _rcRunning = true;
      _rcLog = [];
      _rcReport = null;
    });
    await HapticsService.heavy();
    final report = await ReleaseValidator.instance.validate(
      onProgress: (msg) {
        if (mounted) setState(() => _rcLog.add(msg));
      },
    );
    if (mounted) setState(() { _rcRunning = false; _rcReport = report; });
  }

  // ── SnackBar helper ──────────────────────────────────────────────────────────

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: _kText, fontSize: 13)),
        backgroundColor: _kCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _kBorder),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Page wrapper ─────────────────────────────────────────────────────────────

  Widget _scrollPage({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  // ── Section header ───────────────────────────────────────────────────────────

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: _kAccent,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );

  // ── Card helper ──────────────────────────────────────────────────────────────

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: child,
  );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Text(
          'Simülasyon Laboratuvarı',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: _kAccent,
          labelColor: _kAccent,
          unselectedLabelColor: _kMuted,
          tabs: const [
            Tab(icon: Icon(Icons.dns_rounded), text: 'Backend'),
            Tab(icon: Icon(Icons.workspace_premium_rounded), text: 'Premium'),
            Tab(icon: Icon(Icons.signal_wifi_4_bar_rounded), text: 'Ağ'),
            Tab(icon: Icon(Icons.smart_toy_rounded), text: 'Yapay Zeka'),
            Tab(icon: Icon(Icons.speed_rounded), text: 'Stres'),
            Tab(icon: Icon(Icons.bug_report_rounded), text: 'QA'),
            Tab(icon: Icon(Icons.developer_mode_rounded), text: 'Araçlar'),
            Tab(icon: Icon(Icons.verified_rounded), text: 'RC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBackendTab(),
          _buildPremiumTab(),
          _buildNetworkTab(),
          _buildAIProviderTab(),
          _buildStressTab(),
          _buildQATab(),
          _buildDevToolsTab(),
          _buildRCTab(),
        ],
      ),
    );
  }

  // ── Tab 0 — Backend Simulator ─────────────────────────────────────────────────

  Widget _buildBackendTab() {
    return ListenableBuilder(
      listenable: SimulationEngine.instance,
      builder: (context, _) {
        final log = SimulationEngine.instance.backendLog.reversed.toList();
        return _scrollPage(children: [
          _sectionHeader('Sahte Backend İşlemleri'),
          _card(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OpButton(
                  label: 'Giriş',
                  onTap: () async {
                    setState(() => _backendRunning = true);
                    await HapticsService.light();
                    await SimulationEngine.instance.simulateLogin();
                    if (mounted) setState(() => _backendRunning = false);
                  },
                ),
                _OpButton(
                  label: 'Bulut Sync',
                  onTap: () async {
                    setState(() => _backendRunning = true);
                    await HapticsService.light();
                    await SimulationEngine.instance.simulateCloudSync();
                    if (mounted) setState(() => _backendRunning = false);
                  },
                ),
                _OpButton(
                  label: 'Abonelik',
                  onTap: () async {
                    setState(() => _backendRunning = true);
                    await HapticsService.light();
                    await SimulationEngine.instance.simulateSubscriptionFetch();
                    if (mounted) setState(() => _backendRunning = false);
                  },
                ),
                _OpButton(
                  label: 'Ders Yükle',
                  onTap: () async {
                    setState(() => _backendRunning = true);
                    await HapticsService.light();
                    await SimulationEngine.instance.simulateLessonUpload();
                    if (mounted) setState(() => _backendRunning = false);
                  },
                ),
                _OpButton(
                  label: 'Analitik',
                  onTap: () async {
                    setState(() => _backendRunning = true);
                    await HapticsService.light();
                    await SimulationEngine.instance.simulateAnalyticsUpload();
                    if (mounted) setState(() => _backendRunning = false);
                  },
                ),
              ],
            ),
          ),
          if (_backendRunning) ...[
            const SizedBox(height: 4),
            const LinearProgressIndicator(
              backgroundColor: _kSurface,
              color: _kAccent,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _sectionHeader('Çevrimdışı Kuyruk Tekrarı'),
          _card(
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticsService.light();
                  await SimulationEngine.instance.replayOfflineQueue(5);
                },
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Kuyruğu Tekrarla (5 işlem)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kSurface,
                  foregroundColor: _kAccent,
                  side: const BorderSide(color: _kAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _sectionHeader('İşlem Geçmişi'),
          if (log.isEmpty)
            _card(
              const Text('Henüz işlem yok', style: TextStyle(color: _kMuted, fontSize: 12)),
            )
          else
            ...log.map((result) => _card(
              Row(
                children: [
                  Icon(
                    result.success
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: result.success ? _kGreen : _kRed,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.operationName,
                      style: const TextStyle(fontSize: 12, color: _kText),
                    ),
                  ),
                  Text(
                    '${result.latencyMs}ms',
                    style: const TextStyle(fontSize: 10, color: _kMuted),
                  ),
                ],
              ),
            )),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => SimulationEngine.instance.clearLog(),
            child: const Text('Geçmişi Temizle', style: TextStyle(color: _kRed, fontSize: 12)),
          ),
        ]);
      },
    );
  }

  // ── Tab 1 — Premium Switcher ──────────────────────────────────────────────────

  Widget _buildPremiumTab() {
    return ListenableBuilder(
      listenable: SimulationEngine.instance,
      builder: (context, _) {
        final current = SimulationEngine.instance.fakeSubscriptionTier;
        final entitlements = _entitlementsFor(current);
        return _scrollPage(children: [
          _sectionHeader('Abonelik Katmanı'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccent),
            ),
            child: const Text(
              'Bu, uygulama içi satın alma olmadan abonelik davranışını test etmek için sahte bir katman geçişidir.',
              style: TextStyle(fontSize: 11, color: _kSub),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: SubscriptionTier.values.map((tier) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _TierButton(
                  tier: tier,
                  isSelected: current == tier,
                  onTap: () {
                    SimulationEngine.instance.setSubscriptionTier(tier);
                    HapticsService.medium();
                  },
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktif Katman: ${current.label}',
                  style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entitlements.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 11, color: _kAccent)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ]);
      },
    );
  }

  List<String> _entitlementsFor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return ['10 soru/gün', 'Sesli mod (temel)', 'Sınav kampı'];
      case SubscriptionTier.premium:
        return ['Sınırsız sohbet', 'PDF yükleme', 'Sesli mod', 'Bulut sync', 'Öncelikli model', 'Gelişmiş analitik'];
      case SubscriptionTier.family:
        return ['Premium özellikler', '5 hesap paylaşımı', 'Aile panosu'];
    }
  }

  // ── Tab 2 — Network Profile ───────────────────────────────────────────────────

  Widget _buildNetworkTab() {
    return ListenableBuilder(
      listenable: SimulationEngine.instance,
      builder: (context, _) {
        final current = SimulationEngine.instance.networkProfile;
        return _scrollPage(children: [
          _sectionHeader('Ağ Profili'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: const Text(
              'API çağrıları bu gecikme ve hata oranıyla simüle edilir.',
              style: TextStyle(fontSize: 11, color: _kSub),
            ),
          ),
          ...NetworkProfile.values.map((profile) {
            final isSelected = current == profile;
            return GestureDetector(
              onTap: () {
                SimulationEngine.instance.setNetworkProfile(profile);
                HapticsService.light();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kAccent.withValues(alpha: 0.10)
                      : _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _kAccent : _kBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(profile.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? _kAccent : _kText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${profile.latencyMs}ms gecikme • %${(profile.failureRate * 100).toInt()} hata',
                            style: const TextStyle(fontSize: 11, color: _kSub),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: _kAccent, size: 18),
                  ],
                ),
              ),
            );
          }),
        ]);
      },
    );
  }

  // ── Tab 3 — AI Provider ───────────────────────────────────────────────────────

  Widget _buildAIProviderTab() {
    return ListenableBuilder(
      listenable: SimulationEngine.instance,
      builder: (context, _) {
        final current = SimulationEngine.instance.aiProvider;
        final preview = SimulationEngine.instance.generateFakeReply('Türev nedir?');
        return _scrollPage(children: [
          _sectionHeader('Yapay Zeka Sağlayıcısı'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: const Text(
              'Bu ayar yalnızca simülasyon ortamında geçerlidir. Gerçek API çağrısı yapılmaz.',
              style: TextStyle(fontSize: 11, color: _kSub),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: FakeAIProvider.values.map((provider) {
              final isSelected = current == provider;
              return GestureDetector(
                onTap: () {
                  SimulationEngine.instance.setAIProvider(provider);
                  HapticsService.light();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kAccent.withValues(alpha: 0.12)
                        : _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _kAccent : _kBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? _kAccent : _kText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (provider.isOffline)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _kYellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Çevrimdışı',
                                style: TextStyle(fontSize: 9, color: _kYellow),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Yanıt Önizleme'),
          _card(
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  preview,
                  style: const TextStyle(fontSize: 12, color: _kSub, height: 1.5),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  // ── Tab 4 — Stress Test ───────────────────────────────────────────────────────

  Widget _buildStressTab() {
    return _scrollPage(children: [
      _sectionHeader('Stres Testi'),
      _card(
        const Text(
          '5 dakikalık yoğun oturum simüle eder. Gerçek ağ trafiği kullanılmaz.',
          style: TextStyle(fontSize: 12, color: _kSub),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _stressRunning
                ? null
                : const LinearGradient(
                    colors: [_kAccent, Color(0xFF9333EA)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _stressRunning ? _kMuted : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: _stressRunning ? null : _runStressTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _stressRunning ? 'Çalışıyor…' : 'Stres Testini Başlat',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      if (_stressRunning) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          backgroundColor: _kSurface,
          color: _kAccent,
        ),
      ],
      if (_stressResult != null) ...[
        const SizedBox(height: 16),
        _sectionHeader('Sonuçlar'),
        _card(
          Column(
            children: [
              _StatRow(label: 'Altyazı güncellemeleri', value: '${_stressResult!.subtitleUpdates} güncelleme'),
              _StatRow(label: 'Tahta açılışları', value: '${_stressResult!.boardOpenings} açılış'),
              _StatRow(label: 'Analitik olaylar', value: '${_stressResult!.analyticsEvents} olay'),
              _StatRow(label: 'Çevrimdışı kuyruk', value: '${_stressResult!.offlineQueueEntries} giriş'),
              _StatRow(label: 'Bellek büyümesi', value: '${_stressResult!.memoryGrowthKb} KB'),
              _StatRow(label: 'Kare düşme', value: '${_stressResult!.frameDropCount} kare'),
              _StatRow(label: 'Süre', value: '${_stressResult!.elapsed.inMilliseconds}ms'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _stressResult!.passed
                          ? _kGreen.withValues(alpha: 0.15)
                          : _kRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _stressResult!.passed ? _kGreen : _kRed,
                      ),
                    ),
                    child: Text(
                      _stressResult!.passed ? 'GEÇTİ' : 'BAŞARISIZ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _stressResult!.passed ? _kGreen : _kRed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      if (_stressLog.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionHeader('Günlük'),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _stressLog.reversed.take(10).map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(line, style: const TextStyle(fontSize: 11, color: _kSub)),
            )).toList(),
          ),
        ),
      ],
    ]);
  }

  // ── Tab 5 — QA Tools ─────────────────────────────────────────────────────────

  Widget _buildQATab() {
    return ListenableBuilder(
      listenable: SimulationEngine.instance,
      builder: (context, _) {
        final isActive = SimulationEngine.instance.isSimulationActive;
        return _scrollPage(children: [
          _sectionHeader('Özellik Bayrakları'),
          _card(
            Column(
              children: [
                _FlagRow(name: 'streakBanner', value: FeatureFlags.streakBanner),
                _FlagRow(name: 'achievementToasts', value: FeatureFlags.achievementToasts),
                _FlagRow(name: 'sessionRecovery', value: FeatureFlags.sessionRecovery),
                _FlagRow(name: 'glassmorphism', value: FeatureFlags.glassmorphism),
                _FlagRow(name: 'localAnalytics', value: FeatureFlags.localAnalytics),
                _FlagRow(name: 'diagnosticsScreen', value: FeatureFlags.diagnosticsScreen),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: const Text(
              'Bayraklar derleme zamanında belirlenir. Değiştirmek için --dart-define kullanın.',
              style: TextStyle(fontSize: 11, color: _kSub, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Veri Sıfırlama'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kRed.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_rounded, color: _kRed, size: 16),
                SizedBox(width: 8),
                Text(
                  'Aşağıdaki işlemler geri alınamaz!',
                  style: TextStyle(fontSize: 12, color: _kRed, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _ResetButton(
            label: "Onboarding'ı Sıfırla",
            isConfirming: _confirming.contains(0),
            onTap: () async {
              if (_confirming.contains(0)) {
                _confirming.remove(0);
                await widget.storage.saveSetting('onboarding_done', 'false');
                _showSnack("Onboarding sıfırlandı.");
              } else {
                setState(() => _confirming.add(0));
              }
            },
          ),
          _ResetButton(
            label: 'Seri Kaydını Sıfırla',
            isConfirming: _confirming.contains(1),
            onTap: () async {
              if (_confirming.contains(1)) {
                _confirming.remove(1);
                await widget.storage.saveSetting('streak_record', '');
                _showSnack('Seri kaydı sıfırlandı.');
              } else {
                setState(() => _confirming.add(1));
              }
            },
          ),
          _ResetButton(
            label: 'Başarımları Sıfırla',
            isConfirming: _confirming.contains(2),
            onTap: () async {
              if (_confirming.contains(2)) {
                _confirming.remove(2);
                await widget.storage.saveSetting('achievements_v1', '');
                _showSnack('Başarımlar sıfırlandı.');
              } else {
                setState(() => _confirming.add(2));
              }
            },
          ),
          _ResetButton(
            label: 'Oturum Kurtarmayı Temizle',
            isConfirming: _confirming.contains(3),
            onTap: () async {
              if (_confirming.contains(3)) {
                _confirming.remove(3);
                await widget.storage.saveSetting('session_snapshot_v1', '');
                _showSnack('Oturum kurtarma temizlendi.');
              } else {
                setState(() => _confirming.add(3));
              }
            },
          ),
          _ResetButton(
            label: 'Tüm Belleği Temizle',
            isConfirming: _confirming.contains(4),
            onTap: () async {
              if (_confirming.contains(4)) {
                _confirming.remove(4);
                await widget.storage.saveSetting('long_term_memory_v1', '');
                await widget.storage.saveSetting('episodic_memory_v1', '');
                _showSnack('Tüm bellek temizlendi.');
              } else {
                setState(() => _confirming.add(4));
              }
            },
          ),
          _ResetButton(
            label: 'Uygulama Güncellemesini Simüle Et',
            isConfirming: _confirming.contains(5),
            onTap: () {
              if (_confirming.contains(5)) {
                setState(() => _confirming.remove(5));
                _showSnack('Güncelleme simüle edildi — depolama geçişleri normal tamamlandı');
              } else {
                setState(() => _confirming.add(5));
              }
            },
          ),
          const SizedBox(height: 16),
          _sectionHeader('Simülasyon Durumu'),
          _card(
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Simülasyon Aktif',
                    style: TextStyle(fontSize: 13, color: _kText),
                  ),
                ),
                Switch.adaptive(
                  value: isActive,
                  onChanged: (v) => SimulationEngine.instance.setSimulationActive(v),
                  activeColor: _kAccent,
                ),
              ],
            ),
          ),
        ]);
      },
    );
  }

  // ── Tab 6 — Developer Tools ───────────────────────────────────────────────────

  Widget _buildDevToolsTab() {
    final session = widget.costTracker.currentSession;
    final estimatedTokens = _tokenText.isEmpty ? 0 : (_tokenText.length / 4).ceil();
    return _scrollPage(children: [
      _sectionHeader('AI Maliyet Simülasyonu'),
      _card(
        Column(
          children: [
            _StatRow(label: 'Oturum maliyeti', value: session.displayCost),
            _StatRow(label: 'Giriş token', value: '${session.inputTokens}'),
            _StatRow(label: 'Çıkış token', value: '${session.outputTokens}'),
            _StatRow(label: 'Toplam token', value: '${session.totalTokens}'),
          ],
        ),
      ),
      const SizedBox(height: 4),
      _sectionHeader('Token Simülasyonu'),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tokenCtrl,
              style: const TextStyle(fontSize: 13, color: _kText),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Metin girin…',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kAccent),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Tahmini token sayısı: ', style: TextStyle(fontSize: 12, color: _kSub)),
                Text(
                  '$estimatedTokens',
                  style: const TextStyle(fontSize: 13, color: _kAccent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      _sectionHeader('Telemetri Denetçisi'),
      _card(
        Column(
          children: [
            _StatRow(label: 'Kuyruk boyutu', value: '${widget.telemetrySvc.queueSize}'),
            _StatRow(label: 'Senkronize edilmemiş', value: '${widget.telemetrySvc.unsyncedCount}'),
          ],
        ),
      ),
      const SizedBox(height: 4),
      _sectionHeader('Oturum Denetçisi'),
      ListenableBuilder(
        listenable: SimulationEngine.instance,
        builder: (context, _) {
          final engine = SimulationEngine.instance;
          return _card(
            Column(
              children: [
                _StatRow(label: 'Ağ profili', value: engine.networkProfile.label),
                _StatRow(label: 'Yapay zeka sağlayıcı', value: engine.aiProvider.label),
                _StatRow(label: 'Abonelik katmanı', value: engine.fakeSubscriptionTier.label),
              ],
            ),
          );
        },
      ),
    ]);
  }

  // ── Tab 7 — RC Validator ──────────────────────────────────────────────────────

  Widget _buildRCTab() {
    return _scrollPage(children: [
      _sectionHeader('Yayın Adayı Doğrulama'),
      _card(
        const Text(
          'Tüm servisleri, ekranları ve kritik akışları doğrular. Hiçbir gerçek ağ çağrısı yapılmaz.',
          style: TextStyle(fontSize: 12, color: _kSub),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _rcRunning
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _rcRunning ? _kMuted : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: _rcRunning ? null : _runRCValidation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _rcRunning ? 'Doğrulanıyor…' : 'Doğrulamayı Başlat',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      if (_rcRunning) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          backgroundColor: _kSurface,
          color: _kGreen,
        ),
        const SizedBox(height: 8),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _rcLog.reversed.take(8).map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(line, style: const TextStyle(fontSize: 11, color: _kSub)),
            )).toList(),
          ),
        ),
      ],
      if (_rcReport != null) ...[
        const SizedBox(height: 16),
        _sectionHeader('Sonuç Özeti'),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RCBadge(count: _rcReport!.passCount, color: _kGreen, label: 'Başarılı'),
                  const SizedBox(width: 8),
                  _RCBadge(count: _rcReport!.warnCount, color: _kYellow, label: 'Uyarı'),
                  const SizedBox(width: 8),
                  _RCBadge(count: _rcReport!.failCount, color: _kRed, label: 'Hatalı'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _rcReport!.verdict,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _rcReport!.isReleasable ? _kGreen : _kRed,
                ),
              ),
            ],
          ),
        ),
        _sectionHeader('Kontrol Detayları'),
        ..._rcReport!.checks.map((check) => _card(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _rcStatusIcon(check.status),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _rcStatusColor(check.status),
                      ),
                    ),
                    if (check.detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        check.detail,
                        style: const TextStyle(fontSize: 11, color: _kSub),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${check.elapsed.inMilliseconds}ms',
                      style: const TextStyle(fontSize: 10, color: _kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 4),
        _card(
          Text(
            'Oluşturuldu: ${_rcReport!.generatedAt}',
            style: const TextStyle(fontSize: 11, color: _kSub),
          ),
        ),
      ],
    ]);
  }

  String _rcStatusIcon(RCCheckStatus status) {
    return switch (status) {
      RCCheckStatus.pass => '✅',
      RCCheckStatus.warn => '⚠️',
      RCCheckStatus.fail => '❌',
    };
  }

  Color _rcStatusColor(RCCheckStatus status) {
    return switch (status) {
      RCCheckStatus.pass => _kGreen,
      RCCheckStatus.warn => _kYellow,
      RCCheckStatus.fail => _kRed,
    };
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _OpButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OpButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kAccent.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _kAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TierButton extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isSelected;
  final VoidCallback onTap;

  const _TierButton({
    required this.tier,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon => switch (tier) {
    SubscriptionTier.free    => Icons.lock_open_rounded,
    SubscriptionTier.premium => Icons.workspace_premium_rounded,
    SubscriptionTier.family  => Icons.family_restroom_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withValues(alpha: 0.15) : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kAccent : _kBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: isSelected ? _kAccent : _kMuted, size: 20),
            const SizedBox(height: 4),
            Text(
              tier.label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? _kAccent : _kSub,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: _kMuted)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _kText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  final String label;
  final bool isConfirming;
  final VoidCallback onTap;

  const _ResetButton({
    required this.label,
    required this.isConfirming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isConfirming
              ? _kRed.withValues(alpha: 0.10)
              : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConfirming ? _kRed : _kRed.withValues(alpha: 0.4),
            width: isConfirming ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isConfirming ? Icons.warning_rounded : Icons.delete_outline_rounded,
              color: _kRed,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isConfirming ? 'Emin misin? Tekrar dokun.' : label,
                style: TextStyle(
                  fontSize: 13,
                  color: isConfirming ? _kRed : _kText,
                  fontWeight: isConfirming ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  final String name;
  final bool value;

  const _FlagRow({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: _kSub, fontFamily: 'monospace'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: value
                  ? _kGreen.withValues(alpha: 0.12)
                  : _kRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value ? 'true' : 'false',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: value ? _kGreen : _kRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RCBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String label;

  const _RCBadge({required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
