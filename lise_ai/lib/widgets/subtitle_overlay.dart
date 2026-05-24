import 'package:flutter/material.dart';

// ── Subtitle item ─────────────────────────────────────────────────────────────

class SubtitleItem {
  final String text;
  final bool isUser;
  final int id;

  static int _nextId = 0;

  SubtitleItem({required this.text, required this.isUser})
      : id = _nextId++;
}

// ── SubtitleOverlay ───────────────────────────────────────────────────────────
//
// Displays the most recent 4 subtitle lines.
// Newest at bottom (index 0), older lines float upward + fade.
// Uses AnimatedPositioned + AnimatedOpacity for smooth transitions.

class SubtitleOverlay extends StatelessWidget {
  final List<SubtitleItem> items; // index 0 = newest

  const SubtitleOverlay({super.key, required this.items});

  static const double _lineHeight = 54.0;
  static const int _maxVisible = 4;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(_maxVisible).toList();
    final totalHeight = _lineHeight * _maxVisible;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (int i = 0; i < visible.length; i++)
            AnimatedPositioned(
              key: ValueKey(visible[i].id),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              bottom: i * _lineHeight,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _opacity(i),
                duration: const Duration(milliseconds: 380),
                child: _SubtitleLine(
                  item: visible[i],
                  scale: _scale(i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _opacity(int idx) {
    if (idx == 0) return 1.00;
    if (idx == 1) return 0.60;
    if (idx == 2) return 0.30;
    return 0.0;
  }

  double _scale(int idx) {
    if (idx == 0) return 1.00;
    if (idx == 1) return 0.93;
    return 0.86;
  }
}

// ── Single subtitle line ──────────────────────────────────────────────────────

class _SubtitleLine extends StatelessWidget {
  final SubtitleItem item;
  final double scale;

  const _SubtitleLine({required this.item, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Transform.scale(
        scale: scale,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: item.isUser
              ? BoxDecoration(
                  color: const Color(0xFF7C6BF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF7C6BF8).withValues(alpha: 0.30),
                    width: 0.5,
                  ),
                )
              : null,
          child: Text(
            item.text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: item.isUser
                  ? const Color(0xFFD1D5DB)
                  : Colors.white.withValues(alpha: 0.92),
              fontSize: item.isUser ? 13 : 15,
              fontWeight:
                  item.isUser ? FontWeight.w400 : FontWeight.w500,
              height: 1.4,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}
