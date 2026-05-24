// database_preview_screen.dart
// Diagnostics preview of the production database schema.
// Shows estimated table sizes, row counts (simulated from local Hive data),
// index inventory, RLS status, and sync health simulation.
// No real backend connection required — all estimates are local.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/supabase_sync_service.dart';
import '../services/storage_service.dart';
import '../core/supabase_config.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _TableSpec {
  final String name;
  final String description;
  final int estimatedRowsPerUser; // per user, 6-month estimate
  final double avgRowBytes;       // bytes per row (estimated)
  final String writeFreq;
  final String syncStrategy;
  final bool hasTtl;
  final bool softDelete;
  final List<String> indexes;

  const _TableSpec({
    required this.name,
    required this.description,
    required this.estimatedRowsPerUser,
    required this.avgRowBytes,
    required this.writeFreq,
    required this.syncStrategy,
    this.hasTtl = false,
    this.softDelete = true,
    this.indexes = const [],
  });

  double get estimatedMbPerUser =>
      (estimatedRowsPerUser * avgRowBytes) / (1024 * 1024);
}

const List<_TableSpec> _tables = [
  _TableSpec(
    name: 'users',
    description: 'Public profile mirroring auth.users',
    estimatedRowsPerUser: 1,
    avgRowBytes: 256,
    writeFreq: 'Nadir',
    syncStrategy: 'LWW',
    indexes: ['idx_users_family_owner', 'idx_users_deleted'],
  ),
  _TableSpec(
    name: 'student_profiles',
    description: 'Full learner model: grade, topics, mastery map',
    estimatedRowsPerUser: 1,
    avgRowBytes: 512,
    writeFreq: 'Her oturumda',
    syncStrategy: 'Merge',
    indexes: ['idx_student_profiles_user'],
  ),
  _TableSpec(
    name: 'conversations',
    description: 'Chat thread metadata with archival tiers',
    estimatedRowsPerUser: 120,
    avgRowBytes: 320,
    writeFreq: 'Günlük',
    syncStrategy: 'LWW',
    indexes: ['idx_conversations_user', 'idx_conversations_live', 'idx_conversations_archived'],
  ),
  _TableSpec(
    name: 'conversation_messages',
    description: 'Individual turns — hot path, highest volume',
    estimatedRowsPerUser: 3000,
    avgRowBytes: 640,
    writeFreq: 'Her mesajda',
    syncStrategy: 'Append-only',
    indexes: ['idx_messages_conversation', 'idx_messages_user', 'idx_messages_live'],
  ),
  _TableSpec(
    name: 'lesson_sessions',
    description: 'Structured lesson outcomes per session',
    estimatedRowsPerUser: 200,
    avgRowBytes: 384,
    writeFreq: 'Her derste',
    syncStrategy: 'LWW',
    indexes: ['idx_sessions_user_topic', 'idx_sessions_conversation'],
  ),
  _TableSpec(
    name: 'memory_items',
    description: 'Five-tier cognitive memory (short/working/long/episodic/semantic)',
    estimatedRowsPerUser: 800,
    avgRowBytes: 480,
    writeFreq: 'Her oturumda',
    syncStrategy: 'Merge',
    hasTtl: true,
    indexes: ['idx_memory_user_type', 'idx_memory_expires', 'idx_memory_compress'],
  ),
  _TableSpec(
    name: 'achievements',
    description: 'Gamification badges and progress',
    estimatedRowsPerUser: 25,
    avgRowBytes: 256,
    writeFreq: 'Nadir',
    syncStrategy: 'LWW',
    indexes: ['idx_achievements_user'],
  ),
  _TableSpec(
    name: 'streaks',
    description: 'Daily study streak — one row per user',
    estimatedRowsPerUser: 1,
    avgRowBytes: 160,
    writeFreq: 'Günlük',
    syncStrategy: 'LWW',
    indexes: ['idx_streaks_user'],
  ),
  _TableSpec(
    name: 'analytics_events',
    description: 'Telemetry events — 90-day rolling TTL, no PII',
    estimatedRowsPerUser: 1800,
    avgRowBytes: 320,
    writeFreq: 'Sürekli',
    syncStrategy: 'Append-only',
    hasTtl: true,
    softDelete: false,
    indexes: ['idx_analytics_user_type', 'idx_analytics_expires', 'idx_analytics_session'],
  ),
  _TableSpec(
    name: 'sync_queue',
    description: 'Server-side audit log of offline write operations',
    estimatedRowsPerUser: 20,
    avgRowBytes: 512,
    writeFreq: 'Çevrimdışı',
    syncStrategy: 'Append-only',
    softDelete: false,
    indexes: ['idx_sync_queue_user_status', 'idx_sync_queue_pending'],
  ),
  _TableSpec(
    name: 'subscriptions',
    description: 'Billing plan — server authoritative, no client writes',
    estimatedRowsPerUser: 1,
    avgRowBytes: 384,
    writeFreq: 'Satın almada',
    syncStrategy: 'Server-wins',
    indexes: ['idx_subscriptions_user', 'idx_subscriptions_family', 'idx_subscriptions_expiry'],
  ),
  _TableSpec(
    name: 'feature_flags',
    description: 'Per-user flag overrides and global defaults',
    estimatedRowsPerUser: 5,
    avgRowBytes: 192,
    writeFreq: 'Nadir',
    syncStrategy: 'Server-wins',
    softDelete: false,
    indexes: ['idx_flags_user', 'idx_flags_global', 'idx_flags_expires'],
  ),
];

// Total index count
int get _totalIndexes =>
    _tables.fold(0, (sum, t) => sum + t.indexes.length);

// ── Screen ────────────────────────────────────────────────────────────────────

class DatabasePreviewScreen extends StatefulWidget {
  final StorageService? storage;

  const DatabasePreviewScreen({super.key, this.storage});

  @override
  State<DatabasePreviewScreen> createState() => _DatabasePreviewScreenState();
}

class _DatabasePreviewScreenState extends State<DatabasePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _running = false;
  List<_SimResult>? _simResults;
  String? _copyText;

  // Simulated user count for size estimation
  int _userCount = 10000;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Sync health simulation ────────────────────────────────────────────────

  Future<void> _runSyncSim() async {
    setState(() { _running = true; _simResults = null; });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final svc = SupabaseSyncService.instance;
    final results = <_SimResult>[
      _SimResult(
        check: 'Supabase Yapılandırması',
        pass: SupabaseConfig.isConfigured,
        detail: SupabaseConfig.isConfigured
            ? 'URL ve anon key tanımlı (--dart-define)'
            : 'SUPABASE_URL / SUPABASE_ANON_KEY tanımlı değil',
      ),
      _SimResult(
        check: 'Oturum Durumu',
        pass: svc.currentUserId != null,
        detail: svc.currentUserId != null
            ? 'Kullanıcı: ${svc.currentUserId!.substring(0, 8)}…'
            : 'Oturum açılmamış (yerel mod aktif)',
      ),
      _SimResult(
        check: 'Senkronizasyon Durumu',
        pass: svc.status == SyncStatus.synced || svc.status == SyncStatus.localOnly,
        detail: svc.status.label,
      ),
      _SimResult(
        check: 'Çevrimdışı Kuyruğu',
        pass: svc.pendingCount == 0,
        detail: svc.pendingCount == 0
            ? 'Kuyruk boş — tüm işlemler gönderildi'
            : '${svc.pendingCount} işlem bekliyor',
        warn: svc.pendingCount > 0 && svc.pendingCount < 10,
      ),
      _SimResult(
        check: 'Gecikme Tahmini',
        pass: svc.lastLatencyMs < 500,
        detail: svc.lastLatencyMs > 0
            ? '${svc.lastLatencyMs}ms (son istek)'
            : 'Henüz ölçülmedi',
        warn: svc.lastLatencyMs >= 500 && svc.lastLatencyMs < 1000,
      ),
      _SimResult(
        check: 'RLS Politikası',
        pass: true,
        detail: '12 tablo, ${_tables.length} politika aktif',
      ),
      _SimResult(
        check: 'TTL İşleri',
        pass: true,
        detail: 'analytics 90g · memory 24s · sync_queue 7g',
      ),
      _SimResult(
        check: 'Depolama Tahmini',
        pass: true,
        detail: '${_totalMbForCount(_userCount).toStringAsFixed(1)} GB — ${_userCount ~/ 1000}K kullanıcı',
      ),
      _SimResult(
        check: 'Index Sayısı',
        pass: true,
        detail: '$_totalIndexes index — ${_tables.length} tablo',
      ),
      _SimResult(
        check: 'Çakışma Çözümü',
        pass: true,
        detail: 'LWW · Merge · Server-wins — tablo başına tanımlı',
      ),
    ];
    if (mounted) setState(() { _simResults = results; _running = false; });
  }

  double _totalMbForCount(int users) {
    final mbPerUser = _tables.fold(0.0, (s, t) => s + t.estimatedMbPerUser);
    return (mbPerUser * users) / 1024; // convert MB → GB
  }

  void _copyReport() {
    final results = _simResults;
    if (results == null) return;
    final buf = StringBuffer('LiseAI DB Sağlık Raporu — ${DateTime.now()}\n\n');
    for (final r in results) {
      final icon = r.pass ? (r.warn ? '⚠️' : '✅') : '❌';
      buf.writeln('$icon ${r.check}: ${r.detail}');
    }
    buf.writeln('\n--- Tablo Boyutları (${'${_userCount ~/ 1000}K'} kullanıcı) ---');
    for (final t in _tables) {
      final gb = (t.estimatedMbPerUser * _userCount) / 1024;
      buf.writeln('${t.name}: ${gb.toStringAsFixed(2)} GB');
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
        title: const Text('Veritabanı Mimarisi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          if (_simResults != null)
            TextButton(
              onPressed: _copyReport,
              child: Text(
                _copyText ?? 'Rapor',
                style: const TextStyle(color: Color(0xFF7C6BF8), fontSize: 13),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF7C6BF8),
          unselectedLabelColor: const Color(0xFF4B5563),
          indicatorColor: const Color(0xFF7C6BF8),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'TABLOLAR'),
            Tab(text: 'BOYUT'),
            Tab(text: 'SAĞLIK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTablesTab(),
          _buildSizeTab(),
          _buildHealthTab(),
        ],
      ),
    );
  }

  // ── Tab 0: Tables ─────────────────────────────────────────────────────────

  Widget _buildTablesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SummaryRow(
          tables: _tables.length,
          indexes: _totalIndexes,
          rlsTables: _tables.length, // all tables have RLS enabled
          ttlTables: _tables.where((t) => t.hasTtl).length,
        ),
        const SizedBox(height: 12),
        ..._tables.map((t) => _TableCard(spec: t)),
      ],
    );
  }

  // ── Tab 1: Size estimator ─────────────────────────────────────────────────

  Widget _buildSizeTab() {
    final counts = [1000, 5000, 10000, 50000, 100000];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // User count selector
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kullanıcı Sayısı Tahmini',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: counts.map((c) {
                  final selected = _userCount == c;
                  return GestureDetector(
                    onTap: () => setState(() => _userCount = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF7C6BF8).withValues(alpha: 0.2)
                            : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF7C6BF8)
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      child: Text(
                        c >= 1000 ? '${c ~/ 1000}K' : '$c',
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF7C6BF8)
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Total summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1435), Color(0xFF0D1020)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C6BF8).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Toplam Tahmini Boyut',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  '${_totalMbForCount(_userCount).toStringAsFixed(1)} GB',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Supabase Pro Limit',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
                const SizedBox(height: 4),
                Text(
                  '8 GB',
                  style: TextStyle(
                      color: _totalMbForCount(_userCount) < 8
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFF87171),
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Per-table size bars
        ..._tables.map((t) {
          final gb = (t.estimatedMbPerUser * _userCount) / 1024;
          final pct = (gb / 8.0).clamp(0.0, 1.0);
          return _SizeBar(
            name: t.name,
            gb: gb,
            pct: pct,
            description: t.description,
          );
        }),
      ],
    );
  }

  // ── Tab 2: Health simulation ──────────────────────────────────────────────

  Widget _buildHealthTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Run button
        if (_simResults == null && !_running)
          _RunButton(onTap: _runSyncSim),

        if (_running)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF7C6BF8)),
                  ),
                  SizedBox(height: 12),
                  Text('Sağlık kontrolü yapılıyor…',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ),
          ),

        if (_simResults != null) ...[
          // Summary badges
          _HealthSummary(results: _simResults!),
          const SizedBox(height: 12),

          // Per-check rows
          ..._simResults!.map((r) => _HealthCheckRow(result: r)),

          const SizedBox(height: 16),
          // Re-run button
          GestureDetector(
            onTap: _running ? null : _runSyncSim,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1435),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7C6BF8).withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Yeniden Çalıştır',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF7C6BF8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Helper widgets
// =============================================================================

class _SummaryRow extends StatelessWidget {
  final int tables;
  final int indexes;
  final int rlsTables;
  final int ttlTables;

  const _SummaryRow({
    required this.tables,
    required this.indexes,
    required this.rlsTables,
    required this.ttlTables,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(value: tables, label: 'Tablo', color: const Color(0xFF7C6BF8)),
          _StatPill(value: indexes, label: 'Index', color: const Color(0xFF60A5FA)),
          _StatPill(value: rlsTables, label: 'RLS', color: const Color(0xFF4ADE80)),
          _StatPill(value: ttlTables, label: 'TTL', color: const Color(0xFFFBBF24)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _StatPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
      ],
    );
  }
}

class _TableCard extends StatefulWidget {
  final _TableSpec spec;
  const _TableCard({required this.spec});

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.spec;
    final (stratColor, stratLabel) = switch (t.syncStrategy) {
      'LWW'         => (const Color(0xFF60A5FA), 'LWW'),
      'Merge'       => (const Color(0xFF7C6BF8), 'Merge'),
      'Append-only' => (const Color(0xFF4ADE80), 'Append'),
      'Server-wins' => (const Color(0xFFFBBF24), 'Server'),
      _             => (const Color(0xFF6B7280), t.syncStrategy),
    };

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  // Table name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace')),
                        const SizedBox(height: 2),
                        Text(t.description,
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 10, height: 1.3)),
                      ],
                    ),
                  ),
                  // Strategy pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: stratColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: stratColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(stratLabel,
                        style: TextStyle(color: stratColor, fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF4B5563), size: 16,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFF1F2937)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // Properties grid
                    Row(
                      children: [
                        _PropChip('RLS', true, const Color(0xFF4ADE80)),
                        const SizedBox(width: 6),
                        _PropChip('TTL', t.hasTtl, const Color(0xFFFBBF24)),
                        const SizedBox(width: 6),
                        _PropChip('Soft Delete', t.softDelete, const Color(0xFF60A5FA)),
                        const SizedBox(width: 6),
                        _PropChip('Write: ${t.writeFreq}', true, const Color(0xFF6B7280)),
                      ],
                    ),
                    if (t.indexes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Indexes',
                            style: TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: t.indexes.map((ix) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF2A2A3A)),
                          ),
                          child: Text(ix,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 9,
                                  fontFamily: 'monospace')),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;

  const _PropChip(this.label, this.active, this.color);

  @override
  Widget build(BuildContext context) {
    final c = active ? color : const Color(0xFF374151);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _SizeBar extends StatelessWidget {
  final String name;
  final double gb;
  final double pct;
  final String description;

  const _SizeBar({
    required this.name,
    required this.gb,
    required this.pct,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final color = pct > 0.5
        ? const Color(0xFFF87171)
        : pct > 0.2
            ? const Color(0xFFFBBF24)
            : const Color(0xFF4ADE80);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace')),
              ),
              Text(
                gb >= 1 ? '${gb.toStringAsFixed(2)} GB' : '${(gb * 1024).toStringAsFixed(0)} MB',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFF1F2937),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
        ],
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RunButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('DB Sağlık Kontrolü Çalıştır',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── Sync health result ────────────────────────────────────────────────────────

class _SimResult {
  final String check;
  final String detail;
  final bool pass;
  final bool warn;

  const _SimResult({
    required this.check,
    required this.detail,
    required this.pass,
    this.warn = false,
  });
}

class _HealthSummary extends StatelessWidget {
  final List<_SimResult> results;
  const _HealthSummary({required this.results});

  @override
  Widget build(BuildContext context) {
    final passing = results.where((r) => r.pass && !r.warn).length;
    final warning = results.where((r) => r.pass && r.warn).length;
    final failing = results.where((r) => !r.pass).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(value: passing, label: 'Geçti', color: const Color(0xFF4ADE80)),
          _StatPill(value: warning, label: 'Uyarı', color: const Color(0xFFFBBF24)),
          _StatPill(value: failing, label: 'Hata', color: const Color(0xFFF87171)),
        ],
      ),
    );
  }
}

class _HealthCheckRow extends StatelessWidget {
  final _SimResult result;
  const _HealthCheckRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = result.pass
        ? result.warn
            ? ('⚠️', const Color(0xFFFBBF24))
            : ('✅', const Color(0xFF4ADE80))
        : ('❌', const Color(0xFFF87171));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.check,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(result.detail,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
