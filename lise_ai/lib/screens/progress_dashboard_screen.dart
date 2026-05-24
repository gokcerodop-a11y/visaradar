import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/long_term_memory.dart';
import '../services/session_continuity_service.dart';
import '../services/study_analytics_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF050510);
const _kCard = Color(0xFF0C0C1E);
const _kBorder = Color(0xFF1A1A30);
const _kAccent = Color(0xFF7C6BF8);
const _kAccent2 = Color(0xFF4ADE80);
const _kText = Color(0xFFE8E8FF);
const _kMuted = Color(0xFF6B7280);
const _kRed = Color(0xFFEF4444);
const _kYellow = Color(0xFFF59E0B);

// ── ProgressDashboardScreen ───────────────────────────────────────────────────

class ProgressDashboardScreen extends StatelessWidget {
  final StudentProfile profile;
  final LongTermMemory longTermMemory;
  final SessionContinuityService continuitySvc;
  final VoidCallback? onContinueLesson;

  const ProgressDashboardScreen({
    super.key,
    required this.profile,
    required this.longTermMemory,
    required this.continuitySvc,
    this.onContinueLesson,
  });

  @override
  Widget build(BuildContext context) {
    final weekMins = StudyAnalyticsService.weeklyMinutes(profile);
    final weekTotal = weekMins.fold(0, (a, b) => a + b);
    final dayLabels = StudyAnalyticsService.weekDayLabels();
    final mastery = longTermMemory.masteryList;
    final weakTopics = profile.weakTopics;
    final unfinished = continuitySvc.data.unfinishedTopic;
    final examReadiness = longTermMemory.examReadiness;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // ── Continue lesson CTA ──────────────────────────────────
                  if (unfinished != null) ...[
                    _ContinueCTA(
                      topic: unfinished,
                      onTap: onContinueLesson,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Streak + solved stats ────────────────────────────────
                  _StatsRow(
                    streakDays: profile.streakDays,
                    solvedCount: profile.solvedQuestionCount,
                    weeklyMinutes: weekTotal,
                    targetExam: profile.targetExam,
                  ),
                  const SizedBox(height: 16),

                  // ── Weekly study chart ───────────────────────────────────
                  _SectionLabel(label: 'Bu Hafta Çalışma'),
                  const SizedBox(height: 8),
                  _WeeklyChart(minutes: weekMins, dayLabels: dayLabels),
                  const SizedBox(height: 20),

                  // ── Exam readiness ───────────────────────────────────────
                  _SectionLabel(label: 'Sınav Hazırlık Skoru'),
                  const SizedBox(height: 8),
                  _ExamReadinessBar(readiness: examReadiness),
                  const SizedBox(height: 20),

                  // ── Subject mastery ──────────────────────────────────────
                  if (mastery.isNotEmpty) ...[
                    _SectionLabel(label: 'Konu Ustalığı'),
                    const SizedBox(height: 8),
                    ...mastery
                        .take(8)
                        .map((m) => _MasteryCard(mastery: m)),
                    const SizedBox(height: 20),
                  ],

                  // ── Weak topic alerts ────────────────────────────────────
                  if (weakTopics.isNotEmpty) ...[
                    _SectionLabel(label: 'Dikkat Gerektiren Konular'),
                    const SizedBox(height: 8),
                    _WeakTopicsPanel(topics: weakTopics),
                    const SizedBox(height: 20),
                  ],

                  // ── AI disclaimer ────────────────────────────────────────
                  _DisclaimerCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final name = profile.name ?? 'Öğrenci';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: _kText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
                if (profile.targetExam != null)
                  Text('Hedef: ${profile.targetExam}',
                      style: const TextStyle(
                          color: _kAccent, fontSize: 11)),
              ],
            ),
          ),
          // Streak badge
          if (profile.streakDays > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kYellow.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('${profile.streakDays} gün',
                      style: const TextStyle(
                          color: _kYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Continue CTA ───────────────────────────────────────────────────────────────

class _ContinueCTA extends StatelessWidget {
  final String topic;
  final VoidCallback? onTap;

  const _ContinueCTA({required this.topic, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1035), Color(0xFF0D0820)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.play_arrow_rounded, color: _kAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kaldığın Yerden Devam Et',
                      style: TextStyle(
                          color: _kText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(topic,
                      style: const TextStyle(
                          color: _kAccent, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _kMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int streakDays;
  final int solvedCount;
  final int weeklyMinutes;
  final String? targetExam;

  const _StatsRow({
    required this.streakDays,
    required this.solvedCount,
    required this.weeklyMinutes,
    this.targetExam,
  });

  @override
  Widget build(BuildContext context) {
    final hours = weeklyMinutes ~/ 60;
    final mins = weeklyMinutes % 60;
    final timeLabel = hours > 0 ? '${hours}s ${mins}dk' : '${mins}dk';

    return Row(
      children: [
        Expanded(
            child: _StatCard(
          icon: Icons.local_fire_department_rounded,
          iconColor: _kYellow,
          value: '$streakDays',
          label: 'Günlük Seri',
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.check_circle_outline_rounded,
          iconColor: _kAccent2,
          value: '$solvedCount',
          label: 'Soru Çözüldü',
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.schedule_rounded,
          iconColor: _kAccent,
          value: timeLabel,
          label: 'Bu Hafta',
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: _kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Weekly chart ──────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<int> minutes;
  final List<String> dayLabels;

  const _WeeklyChart({required this.minutes, required this.dayLabels});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(minutes.length, (i) {
                final m = minutes[i];
                final isToday = i == minutes.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _Bar(
                      minutes: m,
                      maxMinutes:
                          minutes.reduce((a, b) => a > b ? a : b).clamp(1, 9999),
                      isToday: isToday,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(dayLabels.length, (i) {
              final isToday = i == dayLabels.length - 1;
              return Expanded(
                child: Text(
                  dayLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isToday ? _kAccent : _kMuted,
                    fontSize: 9,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int minutes;
  final int maxMinutes;
  final bool isToday;

  const _Bar(
      {required this.minutes,
      required this.maxMinutes,
      required this.isToday});

  @override
  Widget build(BuildContext context) {
    final frac = maxMinutes > 0 ? (minutes / maxMinutes).clamp(0.0, 1.0) : 0.0;
    final color = isToday ? _kAccent : const Color(0xFF2A2550);
    final minH = 4.0;
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxH = constraints.maxHeight;
        final barH = math.max(minH, frac * maxH);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: barH,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Exam readiness ─────────────────────────────────────────────────────────────

class _ExamReadinessBar extends StatelessWidget {
  final double readiness; // 0.0–1.0

  const _ExamReadinessBar({required this.readiness});

  Color get _color {
    if (readiness >= 0.75) return _kAccent2;
    if (readiness >= 0.50) return _kAccent;
    if (readiness >= 0.30) return _kYellow;
    return _kRed;
  }

  String get _label {
    if (readiness >= 0.80) return 'Hazır';
    if (readiness >= 0.60) return 'İyi';
    if (readiness >= 0.40) return 'Gelişiyor';
    if (readiness >= 0.20) return 'Başlangıç';
    return 'Çok Erken';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_label,
                  style: TextStyle(
                      color: _color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text('${(readiness * 100).round()}%',
                  style: const TextStyle(color: _kMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: readiness,
              minHeight: 8,
              backgroundColor: const Color(0xFF1A1A30),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subject mastery cards ──────────────────────────────────────────────────────

class _MasteryCard extends StatelessWidget {
  final SubjectMastery mastery;

  const _MasteryCard({required this.mastery});

  Color get _barColor {
    if (mastery.score >= 0.75) return _kAccent2;
    if (mastery.score >= 0.50) return _kAccent;
    if (mastery.score >= 0.30) return _kYellow;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(mastery.subject,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Text(mastery.strengthLabel,
                        style: TextStyle(
                            color: _barColor, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: mastery.score,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1A1A30),
                    valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${mastery.sessionCount} ders',
              style: const TextStyle(color: _kMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Weak topics panel ─────────────────────────────────────────────────────────

class _WeakTopicsPanel extends StatelessWidget {
  final List<String> topics;

  const _WeakTopicsPanel({required this.topics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kRed.withValues(alpha: 0.25)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: topics.take(8).map((t) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _kRed, size: 12),
                const SizedBox(width: 4),
                Text(t,
                    style:
                        const TextStyle(color: _kRed, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── AI disclaimer card ────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _kMuted, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bu uygulama eğitim amaçlı AI asistanıdır. '
              'Yanıtlar kontrol edilmelidir. '
              'Tüm veriler yalnızca cihazınızda saklanır.',
              style: TextStyle(color: _kMuted, fontSize: 10, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: _kMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
