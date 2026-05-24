import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/scenario_runner.dart';
import '../services/telemetry_service.dart';
import '../services/ai_cost_tracker.dart';
import '../services/backend_provider_service.dart';
import '../services/storage_service.dart';
import '../core/backend_provider.dart';

/// Developer diagnostics screen — hidden behind long-press on "Lise AI" title.
/// Shows system health checks for all major components plus production readiness.
class DiagnosticsScreen extends StatefulWidget {
  final TelemetryService? telemetrySvc;
  final AICostTracker? costTracker;
  final VoidCallback? onOpenSimLab;
  final StorageService? storage;

  const DiagnosticsScreen({
    super.key,
    this.telemetrySvc,
    this.costTracker,
    this.onOpenSimLab,
    this.storage,
  });

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<CheckResult>? _results;
  bool _running = false;
  String? _copyText;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() { _running = true; _results = null; });
    final results = await ScenarioRunner.runAll();
    if (mounted) {
      setState(() { _results = results; _running = false; });
    }
  }

  void _copyReport() {
    final results = _results;
    if (results == null) return;
    final buf = StringBuffer('Lise AI Diagnostics — ${DateTime.now()}\n\n');
    for (final r in results) {
      final icon = switch (r.status) {
        CheckStatus.pass => '✅',
        CheckStatus.warn => '⚠️',
        CheckStatus.fail => '❌',
      };
      buf.writeln('$icon ${r.name}');
      buf.writeln('   ${r.detail}');
      buf.writeln('   ${r.elapsed.inMilliseconds}ms');
      buf.writeln();
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    setState(() => _copyText = 'Kopyalandı!');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copyText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        title: const Text('Tanılama',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          if (_results != null)
            TextButton(
              onPressed: _copyReport,
              child: Text(
                _copyText ?? 'Kopyala',
                style: const TextStyle(color: Color(0xFF7C6BF8), fontSize: 13),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: _running ? null : _run,
          ),
        ],
      ),
      body: _running
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF7C6BF8)),
                  ),
                  SizedBox(height: 12),
                  Text('Kontroller çalışıyor…',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            )
          : _buildResults(),
    );
  }

  Widget _buildResults() {
    final results = _results;
    if (results == null) return const SizedBox.shrink();

    final passing = results.where((r) => r.status == CheckStatus.pass).length;
    final warning = results.where((r) => r.status == CheckStatus.warn).length;
    final failing = results.where((r) => r.status == CheckStatus.fail).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryBadge(label: 'Geçti', count: passing, color: const Color(0xFF4ADE80)),
              _SummaryBadge(label: 'Uyarı', count: warning, color: const Color(0xFFFBBF24)),
              _SummaryBadge(label: 'Hata', count: failing, color: const Color(0xFFF87171)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Per-check cards
        ...results.map((r) => _CheckCard(result: r)),

        // ── Backend provider section ──────────────────────────────────────
        const SizedBox(height: 16),
        const _SectionLabel(label: 'BACKEND SAĞLAYICI'),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: BackendProviderService.instance,
          builder: (_, __) {
            final svc = BackendProviderService.instance;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricCard(
                  icon: svc.selectedProvider.emoji,
                  label: 'Aktif Sağlayıcı',
                  value: svc.selectedProvider.label,
                  sub: svc.status.label,
                ),
                const SizedBox(height: 8),
                // Capability pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _CapabilityPill('Auth', svc.authAvailable),
                    _CapabilityPill('Sync', svc.syncAvailable),
                    _CapabilityPill('Storage', svc.storageAvailable),
                    _CapabilityPill('Crashlytics', svc.crashAvailable),
                  ],
                ),
                // Provider switcher (debug mode only)
                if (kDebugMode && widget.storage != null) ...[
                  const SizedBox(height: 12),
                  const Text('Sağlayıcı Değiştir (yalnızca geliştirici)',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: BackendProvider.values.map((p) {
                      final isSelected = svc.selectedProvider == p;
                      return GestureDetector(
                        onTap: () async {
                          await svc.setProvider(p, widget.storage!);
                          if (p != BackendProvider.none) {
                            await svc.testConnection();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C6BF8).withValues(alpha: 0.15)
                                : const Color(0xFF0A0A12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C6BF8)
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          child: Text(
                            '${p.emoji} ${p.label}',
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF7C6BF8)
                                  : const Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (svc.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      svc.lastError!,
                      style: const TextStyle(
                          color: Color(0xFFF87171), fontSize: 10, height: 1.4),
                    ),
                  ],
                ],
              ],
            );
          },
        ),

        // ── Production readiness section ──────────────────────────────────
        if (widget.telemetrySvc != null || widget.costTracker != null) ...[
          const SizedBox(height: 16),
          const _SectionLabel(label: 'ÜRETIM HAZIRLIĞI'),
          const SizedBox(height: 8),
          if (widget.costTracker != null)
            _MetricCard(
              icon: '💰',
              label: 'Oturum AI Maliyeti',
              value: widget.costTracker!.currentSession.displayCost,
              sub: '${widget.costTracker!.currentSession.totalTokens} token',
            ),
          if (widget.telemetrySvc != null) ...[
            const SizedBox(height: 8),
            _MetricCard(
              icon: '📊',
              label: 'Telemetri Kuyruğu',
              value: '${widget.telemetrySvc!.queueSize} olay',
              sub: '${widget.telemetrySvc!.unsyncedCount} senkronize edilmedi',
            ),
          ],
        ],

        const SizedBox(height: 24),
        // ── Simulation Lab entry ────────────────────────────────────────────
        if (widget.onOpenSimLab != null)
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              widget.onOpenSimLab!();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Simülasyon Laboratuvarı →',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Bu ekran yalnızca geliştirici modunda görünür.\n'
          'App Store dağıtımında erişilemez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF374151), fontSize: 11),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7C6BF8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

class _MetricCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String sub;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(sub,
                    style: const TextStyle(
                        color: Color(0xFF4B5563), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final CheckResult result;

  const _CheckCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (result.status) {
      CheckStatus.pass => ('✅', const Color(0xFF4ADE80)),
      CheckStatus.warn => ('⚠️', const Color(0xFFFBBF24)),
      CheckStatus.fail => ('❌', const Color(0xFFF87171)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  result.detail,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${result.elapsed.inMilliseconds}ms',
            style: const TextStyle(color: Color(0xFF374151), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CapabilityPill extends StatelessWidget {
  final String label;
  final bool available;

  const _CapabilityPill(this.label, this.available);

  @override
  Widget build(BuildContext context) {
    final color = available
        ? const Color(0xFF4ADE80)
        : const Color(0xFF374151);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
