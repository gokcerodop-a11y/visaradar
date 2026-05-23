import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/profile_service.dart';

// ── Analytics panel ───────────────────────────────────────────────────────────

Future<void> showAnalyticsPanel(
    BuildContext context, ProfileService profileService) {
  return showDialog(
    context: context,
    builder: (ctx) => _AnalyticsDialog(profile: profileService.profile),
  );
}

class _AnalyticsDialog extends StatelessWidget {
  final StudentProfile profile;

  const _AnalyticsDialog({required this.profile});

  @override
  Widget build(BuildContext context) {
    final weak = profile.weakTopics;
    final strong = profile.strongTopics;
    final recent = profile.recentHistory.take(5).toList();

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1435), Color(0xFF0D0D0D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
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
                    child: Text(
                      'İlerleme & Analiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF6B7280), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
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
                      const SizedBox(height: 20),
                      _SectionLabel(
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFF87171),
                          title: 'Güçlendirilmesi Gereken Konular'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: weak
                            .map((t) => _TopicChip(
                                  label: t,
                                  color: const Color(0xFFF87171),
                                  bgColor: const Color(0xFF2A1A1A),
                                ))
                            .toList(),
                      ),
                    ],

                    if (strong.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionLabel(
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFF4ADE80),
                          title: 'Güçlü Konular'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: strong
                            .map((t) => _TopicChip(
                                  label: t,
                                  color: const Color(0xFF4ADE80),
                                  bgColor: const Color(0xFF0F2A1A),
                                ))
                            .toList(),
                      ),
                    ],

                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionLabel(
                          icon: Icons.history_rounded,
                          color: const Color(0xFF9CA3AF),
                          title: 'Son Dersler'),
                      const SizedBox(height: 8),
                      ...recent.map((r) => _RecentItem(record: r)),
                    ],

                    if (profile.totalInteractions == 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.auto_stories_rounded,
                                  color: Color(0xFF374151), size: 48),
                              SizedBox(height: 12),
                              Text(
                                'Henüz ders kaydı yok.\nSoru sormaya başlayınca\nburada istatistiklerini göreceksin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xFF4B5563), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────────────

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
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
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
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600),
        ),
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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final InteractionRecord record;

  const _RecentItem({required this.record});

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays == 1) return 'Dün';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
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
            child: Text(
              record.topic,
              style:
                  const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            ),
          ),
          if (record.usedHints)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFFFBBF24), size: 13),
            ),
          Text(
            _fmtTime(record.timestamp),
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
