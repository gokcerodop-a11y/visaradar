import 'package:flutter/material.dart';

import '../models/learning_journal.dart';
import '../models/teacher_identity.dart';
import '../services/session_continuity_service.dart';

// ── SessionRecapCard ──────────────────────────────────────────────────────────
//
// "Bugün devam ediyoruz" card shown on return to app.
// Shows: last topic, teacher mood, pending homework, readiness.

class SessionRecapCard extends StatefulWidget {
  final TeacherIdentity teacher;
  final TeacherEmotionalState teacherState;
  final SessionContinuityData continuity;
  final LearningJournal journal;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  const SessionRecapCard({
    super.key,
    required this.teacher,
    required this.teacherState,
    required this.continuity,
    required this.journal,
    required this.onContinue,
    required this.onDismiss,
  });

  @override
  State<SessionRecapCard> createState() => _SessionRecapCardState();
}

class _SessionRecapCardState extends State<SessionRecapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    final stateColor = Color(widget.teacherState.orbColorHex);
    final pending = widget.journal.pendingHomework;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080812),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stateColor.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: stateColor.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: teacher + state ──────────────────────────────────────
          _buildHeader(stateColor),
          const Divider(color: Color(0xFF111122), height: 1),

          // ── Last topic ───────────────────────────────────────────────────
          if (widget.continuity.lastTopics.isNotEmpty)
            _buildLastTopic(stateColor),

          // ── Unfinished lesson ────────────────────────────────────────────
          if (widget.continuity.unfinishedTopic != null)
            _buildUnfinished(stateColor),

          // ── Homework ─────────────────────────────────────────────────────
          if (pending.isNotEmpty) _buildHomeworkRow(pending, stateColor),

          // ── Readiness + topic timeline ───────────────────────────────────
          _buildTimeline(stateColor),

          // ── Actions ──────────────────────────────────────────────────────
          _buildActions(stateColor),
        ],
      ),
    );
  }

  Widget _buildHeader(Color stateColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // Teacher mood indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stateColor.withValues(alpha: 0.12),
              border:
                  Border.all(color: stateColor.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Text(
                widget.teacherState.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacher.teacherName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  '${widget.teacherState.label} • ${widget.teacher.personalityType.label}',
                  style: TextStyle(
                      color: stateColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Dismiss
          GestureDetector(
            onTap: widget.onDismiss,
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF4B5563), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildLastTopic(Color stateColor) {
    final topic = widget.continuity.lastTopics.first;
    final hasUnfinished = widget.continuity.unfinishedTopic != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(
            hasUnfinished
                ? Icons.play_circle_outline_rounded
                : Icons.history_rounded,
            color: stateColor,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasUnfinished
                  ? 'Geçen ders şurada kalmıştık: $topic'
                  : 'Son konu: $topic',
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnfinished(Color stateColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: stateColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stateColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward_rounded, color: stateColor, size: 13),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bugün devam ediyoruz: ${widget.continuity.unfinishedTopic}',
              style: TextStyle(
                  color: stateColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkRow(List<HomeworkItem> pending, Color stateColor) {
    final overdue = pending.where((h) => h.isOverdue).length;
    final hwColor = overdue > 0
        ? const Color(0xFFF87171)
        : const Color(0xFFFBBF24);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined, color: hwColor, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              overdue > 0
                  ? '$overdue ödev gecikmiş — ${pending.first.description}'
                  : '${pending.length} bekleyen ödev: ${pending.first.description}',
              style: TextStyle(color: hwColor, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Color stateColor) {
    final topics = widget.continuity.lastTopics.take(6).toList();
    if (topics.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Son konular',
              style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (int i = 0; i < topics.length; i++) ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? stateColor.withValues(alpha: 0.15)
                          : const Color(0xFF0F0F1A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: i == 0
                            ? stateColor.withValues(alpha: 0.40)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    child: Text(
                      topics[i],
                      style: TextStyle(
                          color: i == 0
                              ? stateColor
                              : const Color(0xFF4B5563),
                          fontSize: 9,
                          fontWeight: i == 0
                              ? FontWeight.w600
                              : FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (i < topics.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF1F2937), size: 10),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Color stateColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: const Center(
                  child: Text('Yeni Başla',
                      style: TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: widget.onContinue,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: stateColor.withValues(alpha: 0.40)),
                ),
                child: Center(
                  child: Text(
                    widget.continuity.unfinishedTopic != null
                        ? 'Devam Et →'
                        : 'Derse Başla →',
                    style: TextStyle(
                        color: stateColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TeacherMoodIndicator ──────────────────────────────────────────────────────
//
// Compact mood chip for the top bar.

class TeacherMoodIndicator extends StatelessWidget {
  final TeacherIdentity teacher;
  final TeacherEmotionalState state;
  final VoidCallback? onTap;

  const TeacherMoodIndicator({
    super.key,
    required this.teacher,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(state.orbColorHex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              teacher.teacherName,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PersonalityPickerSheet ────────────────────────────────────────────────────

class PersonalityPickerSheet extends StatelessWidget {
  final TeacherPersonalityType current;
  final ValueChanged<TeacherPersonalityType> onSelected;

  const PersonalityPickerSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required TeacherPersonalityType current,
    required ValueChanged<TeacherPersonalityType> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PersonalityPickerSheet(
          current: current, onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080812),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF1F2937))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Öğretmen Kişiliği',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'AI\'nın nasıl bir öğretmen gibi davranacağını seç',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(height: 16),
          ...TeacherPersonalityType.values.map((type) {
            final identity = TeacherIdentity.forPersonality(type);
            final isSelected = type == current;
            return _PersonalityTile(
              identity: identity,
              isSelected: isSelected,
              onTap: () {
                onSelected(type);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _PersonalityTile extends StatelessWidget {
  final TeacherIdentity identity;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonalityTile({
    required this.identity,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFF7C6BF8)
        : const Color(0xFF374151);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C6BF8).withValues(alpha: 0.08)
              : const Color(0xFF0A0A12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF7C6BF8).withValues(alpha: 0.40)
                  : const Color(0xFF1F2937)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.teacherName,
                    style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    identity.personalityType.label,
                    style: TextStyle(
                        color: color, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    identity.teachingPhilosophy,
                    style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF7C6BF8), size: 18),
          ],
        ),
      ),
    );
  }
}
