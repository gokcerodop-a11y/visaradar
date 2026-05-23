import 'package:flutter/material.dart';

import '../models/lesson_mode.dart';
import '../models/student_profile.dart';
import '../services/learning_graph_engine.dart';
import '../services/profile_service.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> showAnalyticsPanel(
  BuildContext context,
  ProfileService profileService,
  LearningGraphEngine graphEngine,
  StudentLevel level,
) {
  return showDialog(
    context: context,
    builder: (ctx) => _AnalyticsDialog(
      profile: profileService.profile,
      graph: graphEngine,
      level: level,
    ),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _AnalyticsDialog extends StatefulWidget {
  final StudentProfile profile;
  final LearningGraphEngine graph;
  final StudentLevel level;

  const _AnalyticsDialog({
    required this.profile,
    required this.graph,
    required this.level,
  });

  @override
  State<_AnalyticsDialog> createState() => _AnalyticsDialogState();
}

class _AnalyticsDialogState extends State<_AnalyticsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Flexible(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ProfileTab(profile: widget.profile),
                  _GraphTab(graph: widget.graph, level: widget.level),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1435), Color(0xFF0D0D0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C6BF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Color(0xFF9B8BFB), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('İlerleme & Öğrenim Haritası',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF6B7280), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1435).withValues(alpha: 0.5),
      child: TabBar(
        controller: _tab,
        indicatorColor: const Color(0xFF7C6BF8),
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: const Color(0xFF9B8BFB),
        unselectedLabelColor: const Color(0xFF4B5563),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Profil & Geçmiş'),
          Tab(text: 'Öğrenim Haritası'),
        ],
      ),
    );
  }
}

// ── Profile tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final StudentProfile profile;

  const _ProfileTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weak = profile.weakTopics;
    final strong = profile.strongTopics;
    final recent = profile.recentHistory.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                label: 'Gün Serisi',
                value: '${profile.streakDays}',
                unit: 'gün',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF7C6BF8),
                label: 'Toplam Ders',
                value: '${profile.totalInteractions}',
                unit: 'etkileşim',
              ),
            ],
          ),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFF87171),
              title: 'Güçlendirilmesi Gereken Konular',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: weak
                  .map((t) => _TopicChip(
                      label: t,
                      color: const Color(0xFFF87171),
                      bgColor: const Color(0xFF2A1A1A)))
                  .toList(),
            ),
          ],
          if (strong.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFF4ADE80),
              title: 'Güçlü Konular',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: strong
                  .map((t) => _TopicChip(
                      label: t,
                      color: const Color(0xFF4ADE80),
                      bgColor: const Color(0xFF0F2A1A)))
                  .toList(),
            ),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.history_rounded,
              color: const Color(0xFF9CA3AF),
              title: 'Son Dersler',
            ),
            const SizedBox(height: 8),
            ...recent.map((r) => _RecentItem(record: r)),
          ],
          if (profile.totalInteractions == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.auto_stories_rounded,
                        color: Color(0xFF374151), size: 44),
                    SizedBox(height: 12),
                    Text('Soru sordukça burada istatistiklerin görünür.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Graph tab ─────────────────────────────────────────────────────────────────

class _GraphTab extends StatelessWidget {
  final LearningGraphEngine graph;
  final StudentLevel level;

  const _GraphTab({required this.graph, required this.level});

  @override
  Widget build(BuildContext context) {
    final path = graph.learningPath(level, count: 6);
    final mastery = graph.allMastery;
    final progress = graph.curriculumProgress(level);
    final confidence = graph.overallConfidence();
    final studiedTopics = mastery.entries
        .where((e) => e.value.hasData)
        .toList()
      ..sort((a, b) => b.value.masteryScore.compareTo(a.value.masteryScore));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress row
          Row(
            children: [
              _StatCard(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF60A5FA),
                label: 'Müfredat',
                value: '%$progress',
                unit: 'tamamlandı',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFFFBBF24),
                label: 'Güven Puanı',
                value: '$confidence',
                unit: '/ 100',
              ),
            ],
          ),

          // Recommended path
          if (path.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.route_rounded,
              color: const Color(0xFF7C6BF8),
              title: 'Önerilen Öğrenim Yolu',
            ),
            const SizedBox(height: 8),
            ...path.asMap().entries.map((entry) =>
                _PathItem(index: entry.key + 1, entry: entry.value)),
          ],

          // Mastery breakdown
          if (studiedTopics.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF9CA3AF),
              title: 'Konu Ustalık Seviyeleri',
            ),
            const SizedBox(height: 8),
            ...studiedTopics.map((e) => _MasteryBar(
                  topic: e.key,
                  mastery: e.value,
                  difficulty: graph.difficultyFor(e.key),
                )),
          ],

          if (mastery.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_tree_outlined,
                        color: Color(0xFF374151), size: 44),
                    SizedBox(height: 12),
                    Text(
                      'Ders yaptıkça öğrenim haritası\nburada oluşmaya başlar.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Path item ─────────────────────────────────────────────────────────────────

class _PathItem extends StatelessWidget {
  final int index;
  final LearningPathEntry entry;

  const _PathItem({required this.index, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF7C6BF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: const Color(0xFF7C6BF8).withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                    color: Color(0xFF9B8BFB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.topic,
                    style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(entry.reason,
                    style: const TextStyle(
                        color: Color(0xFF4B5563), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mastery bar ───────────────────────────────────────────────────────────────

class _MasteryBar extends StatelessWidget {
  final String topic;
  final TopicMastery mastery;
  final DifficultyLevel difficulty;

  const _MasteryBar(
      {required this.topic,
      required this.mastery,
      required this.difficulty});

  Color get _barColor {
    final s = mastery.masteryScore;
    if (s >= 75) return const Color(0xFF4ADE80);
    if (s >= 50) return const Color(0xFF60A5FA);
    if (s >= 30) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  @override
  Widget build(BuildContext context) {
    final score = mastery.masteryScore;
    final conf = mastery.confidenceScore;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(topic,
                    style: const TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 12)),
              ),
              Text('${difficulty.label} · Güven: $conf',
                  style: const TextStyle(
                      color: Color(0xFF4B5563), fontSize: 10)),
              const SizedBox(width: 8),
              Text('$score',
                  style: TextStyle(
                      color: _barColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                Container(
                  height: 5,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 5,
                  width: constraints.maxWidth * (score / 100),
                  decoration: BoxDecoration(
                    color: _barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            const SizedBox(height: 2),
            Text(unit,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 11)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _SectionLabel(
      {required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _TopicChip(
      {required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final InteractionRecord record;

  const _RecentItem({required this.record});

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays == 1) return 'Dün';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: record.successEstimate >= 0.65
                  ? const Color(0xFF4ADE80)
                  : record.successEstimate >= 0.45
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFF87171),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(record.topic,
                style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 13)),
          ),
          if (record.usedHints)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFFFBBF24), size: 12),
            ),
          Text(_fmtTime(record.timestamp),
              style: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 11)),
        ],
      ),
    );
  }
}
