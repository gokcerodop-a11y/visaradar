import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/scenario_runner.dart';

/// Developer diagnostics screen — hidden behind long-press on "Lise AI" title.
/// Shows system health checks for all major components.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

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

        const SizedBox(height: 24),
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
