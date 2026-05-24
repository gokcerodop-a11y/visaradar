import 'dart:async';

import 'package:flutter/material.dart';

import '../services/exam_camp_service.dart';

// ── ExamCampOverlay ───────────────────────────────────────────────────────────
//
// Compact overlay shown when "Sınav Kampı" is active.
// Shows:
//   - Countdown timer (with urgency color shift)
//   - Question tally
//   - Grade label
//   - Confidence hint
//   - Pause / End buttons

class ExamCampOverlay extends StatefulWidget {
  final ExamCampService service;
  final VoidCallback onEnd;
  final VoidCallback onCorrect;
  final VoidCallback onIncorrect;

  const ExamCampOverlay({
    super.key,
    required this.service,
    required this.onEnd,
    required this.onCorrect,
    required this.onIncorrect,
  });

  @override
  State<ExamCampOverlay> createState() => _ExamCampOverlayState();
}

class _ExamCampOverlayState extends State<ExamCampOverlay> {
  late final StreamSubscription<int> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.countdownStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final urgency = svc.urgencyLevel;
    final timerColor = Color.lerp(
      const Color(0xFF4ADE80),
      const Color(0xFFF87171),
      urgency,
    )!;
    final stats = svc.stats;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFF0A0A20),
            const Color(0xFF1A0808),
            urgency * 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: timerColor.withValues(alpha: 0.30 + urgency * 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                children: [
                  // Sınav kampı label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: const Color(0xFFF87171).withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      'SINAV KAMPI',
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    svc.topic,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                  const Spacer(),
                  // Pause / Resume
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (svc.isPaused) {
                          svc.resumeSession();
                        } else {
                          svc.pauseSession();
                        }
                      });
                    },
                    child: Icon(
                      svc.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: const Color(0xFF6B7280),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // End
                  GestureDetector(
                    onTap: widget.onEnd,
                    child: const Icon(Icons.stop_rounded,
                        color: Color(0xFF4B5563), size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Main row: timer + tally
              Row(
                children: [
                  // Countdown
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(
                      color: timerColor,
                      fontSize: urgency > 0.5 ? 28 : 24,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: Text(svc.formattedRemaining),
                  ),
                  const SizedBox(width: 16),
                  // Divider
                  Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFF1F2937)),
                  const SizedBox(width: 16),

                  // Question tally
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF4ADE80), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.correct}',
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.cancel_rounded,
                              color: Color(0xFFF87171), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.incorrectOrSkipped}',
                            style: const TextStyle(
                              color: Color(0xFFF87171),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (stats.totalQuestions > 0)
                        Text(
                          '${(stats.accuracy * 100).round()}% · ${stats.grade}',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Answer buttons
                  _AnswerButton(
                    icon: Icons.check_rounded,
                    color: const Color(0xFF4ADE80),
                    onTap: () {
                      widget.onCorrect();
                      setState(() {});
                    },
                    tooltip: 'Doğru',
                  ),
                  const SizedBox(width: 8),
                  _AnswerButton(
                    icon: Icons.close_rounded,
                    color: const Color(0xFFF87171),
                    onTap: () {
                      widget.onIncorrect();
                      setState(() {});
                    },
                    tooltip: 'Yanlış',
                  ),
                ],
              ),

              // Confidence hint
              if (svc.confidenceHint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  svc.confidenceHint,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontStyle: FontStyle.italic),
                ),
              ],

              // Urgency bar
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: svc.totalSeconds > 0
                      ? svc.remainingSeconds / svc.totalSeconds
                      : 0.0,
                  backgroundColor: const Color(0xFF111122),
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _AnswerButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ── ExamCampStartDialog ───────────────────────────────────────────────────────

class ExamCampStartDialog extends StatefulWidget {
  final String defaultTopic;
  const ExamCampStartDialog({super.key, this.defaultTopic = ''});

  @override
  State<ExamCampStartDialog> createState() => _ExamCampStartDialogState();
}

class _ExamCampStartDialogState extends State<ExamCampStartDialog> {
  int _minutes = 20;
  late final TextEditingController _topicCtrl;

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: widget.defaultTopic);
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0C0C18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer_rounded, color: Color(0xFFF87171), size: 18),
                SizedBox(width: 8),
                Text(
                  'Sınav Kampı',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Topic input
            TextField(
              controller: _topicCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Konu (örn: Türev, Newton Yasaları)',
                hintStyle: const TextStyle(color: Color(0xFF374151)),
                filled: true,
                fillColor: const Color(0xFF111122),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF7C6BF8), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Duration picker
            Row(
              children: [
                const Text('Süre:',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                const SizedBox(width: 12),
                ...[10, 20, 30, 45].map((m) {
                  final sel = m == _minutes;
                  return GestureDetector(
                    onTap: () => setState(() => _minutes = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFF87171).withValues(alpha: 0.14)
                            : const Color(0xFF111122),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFFF87171).withValues(alpha: 0.45)
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      child: Text(
                        '$m dk',
                        style: TextStyle(
                          color: sel
                              ? const Color(0xFFF87171)
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal',
                      style: TextStyle(color: Color(0xFF4B5563))),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, (
                    minutes: _minutes,
                    topic: _topicCtrl.text.trim(),
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF87171),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Başlat',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
