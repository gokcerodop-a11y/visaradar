import 'dart:async';

import 'package:flutter/material.dart';

import '../models/speech_tag.dart';

// ── LiveSubtitleEngine ────────────────────────────────────────────────────────
//
// Replaces SubtitleOverlay with a live, animated subtitle display.
// Features:
//   • Word-by-word karaoke reveal on active sentence
//   • Emphasis flash for [important] / [exam_warning] tagged sentences
//   • Past sentences float up and fade (same mechanics as SubtitleOverlay)
//   • Tag hint badges (★ Kritik, ⚠️ Sınav Notu)
//   • Phrase chunking: sentences > 80 chars split at natural commas

class LiveSubtitleItem {
  final String text;
  final bool isUser;
  final SpeechTag tag;
  final bool isActive; // currently being spoken
  final int id;

  static int _nextId = 0;

  LiveSubtitleItem({
    required this.text,
    required this.isUser,
    this.tag = SpeechTag.normal,
    this.isActive = false,
  }) : id = _nextId++;

  LiveSubtitleItem copyWith({bool? isActive}) => LiveSubtitleItem(
        text: text,
        isUser: isUser,
        tag: tag,
        isActive: isActive ?? this.isActive,
      );
}

// ── LiveSubtitleEngine widget ─────────────────────────────────────────────────

class LiveSubtitleEngine extends StatelessWidget {
  final List<LiveSubtitleItem> items; // index 0 = newest
  final int activeWordIndex;          // karaoke: how many words revealed

  const LiveSubtitleEngine({
    super.key,
    required this.items,
    this.activeWordIndex = 999,
  });

  static const double _lineHeight = 60.0;
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
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              bottom: i * _lineHeight,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _opacity(i),
                duration: const Duration(milliseconds: 400),
                child: i == 0 && visible[i].isActive
                    ? _ActiveSubtitleLine(
                        item: visible[i],
                        scale: _scale(i),
                        wordIndex: activeWordIndex,
                      )
                    : _StaticSubtitleLine(
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
    if (idx == 1) return 0.55;
    if (idx == 2) return 0.25;
    return 0.0;
  }

  double _scale(int idx) {
    if (idx == 0) return 1.00;
    if (idx == 1) return 0.93;
    return 0.86;
  }
}

// ── Active sentence (karaoke word reveal) ─────────────────────────────────────

class _ActiveSubtitleLine extends StatefulWidget {
  final LiveSubtitleItem item;
  final double scale;
  final int wordIndex;

  const _ActiveSubtitleLine({
    required this.item,
    required this.scale,
    required this.wordIndex,
  });

  @override
  State<_ActiveSubtitleLine> createState() => _ActiveSubtitleLineState();
}

class _ActiveSubtitleLineState extends State<_ActiveSubtitleLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _emphasisCtrl;

  @override
  void initState() {
    super.initState();
    _emphasisCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    if (widget.item.tag.emphasisLevel > 0) {
      _emphasisCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _emphasisCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.item.tag;
    final emphasisColor = _emphasisColorForTag(tag);
    final words = widget.item.text.split(' ');

    return Align(
      alignment: Alignment.center,
      child: Transform.scale(
        scale: widget.scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tag hint badge
            if (tag.displayHint.isNotEmpty) _TagBadge(tag: tag),

            // Sentence with karaoke words
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: widget.item.isUser
                  ? BoxDecoration(
                      color: const Color(0xFF7C6BF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFF7C6BF8).withValues(alpha: 0.25)),
                    )
                  : tag.emphasisLevel > 0
                      ? BoxDecoration(
                          color:
                              emphasisColor?.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: emphasisColor?.withValues(alpha: 0.30) ??
                                  Colors.transparent),
                        )
                      : null,
              child: AnimatedBuilder(
                animation: _emphasisCtrl,
                builder: (_, __) {
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      for (int w = 0; w < words.length; w++)
                        _WordSpan(
                          word: words[w],
                          isRevealed: w <= widget.wordIndex,
                          isHighlighted: w == widget.wordIndex,
                          baseColor: widget.item.isUser
                              ? const Color(0xFFD1D5DB)
                              : Colors.white,
                          emphasisPulse: tag.emphasisLevel > 0
                              ? _emphasisCtrl.value
                              : 0.0,
                          emphasisColor: emphasisColor,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color? _emphasisColorForTag(SpeechTag tag) => switch (tag) {
        SpeechTag.important   => const Color(0xFFFBBF24),
        SpeechTag.examWarning => const Color(0xFFF87171),
        SpeechTag.excited     => const Color(0xFF4ADE80),
        SpeechTag.gentle      => const Color(0xFF93C5FD),
        _                     => null,
      };
}

// ── Static past sentence ──────────────────────────────────────────────────────

class _StaticSubtitleLine extends StatelessWidget {
  final LiveSubtitleItem item;
  final double scale;

  const _StaticSubtitleLine({required this.item, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Transform.scale(
        scale: scale,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: item.isUser
              ? BoxDecoration(
                  color: const Color(0xFF7C6BF8).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF7C6BF8).withValues(alpha: 0.20),
                      width: 0.5),
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
                  : Colors.white.withValues(alpha: 0.85),
              fontSize: item.isUser ? 12 : 14,
              fontWeight: item.isUser ? FontWeight.w400 : FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated word span ────────────────────────────────────────────────────────

class _WordSpan extends StatelessWidget {
  final String word;
  final bool isRevealed;
  final bool isHighlighted;
  final Color baseColor;
  final double emphasisPulse; // 0–1
  final Color? emphasisColor;

  const _WordSpan({
    required this.word,
    required this.isRevealed,
    required this.isHighlighted,
    required this.baseColor,
    required this.emphasisPulse,
    this.emphasisColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (!isRevealed) {
      color = baseColor.withValues(alpha: 0.18);
    } else if (isHighlighted && emphasisColor != null) {
      // Pulsing emphasis
      color = Color.lerp(
            baseColor,
            emphasisColor!,
            emphasisPulse * 0.7,
          ) ??
          baseColor;
    } else if (isHighlighted) {
      color = Colors.white;
    } else {
      color = baseColor.withValues(alpha: 0.88);
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 80),
      style: TextStyle(
        color: color,
        fontSize: isHighlighted ? 16.0 : 15.0,
        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
        height: 1.4,
      ),
      child: Text(word),
    );
  }
}

// ── Tag badge ─────────────────────────────────────────────────────────────────

class _TagBadge extends StatelessWidget {
  final SpeechTag tag;
  const _TagBadge({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = switch (tag) {
      SpeechTag.examWarning => const Color(0xFFF87171),
      SpeechTag.important   => const Color(0xFFFBBF24),
      _                     => const Color(0xFF7C6BF8),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        tag.displayHint,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── LiveSubtitleController ────────────────────────────────────────────────────
//
// Manages word-reveal timing for the karaoke effect.
// Call advanceWord() periodically (tied to estimated speech duration).

class LiveSubtitleController {
  int _wordIndex = 0;
  Timer? _wordTimer;
  final VoidCallback onWordAdvanced;

  LiveSubtitleController({required this.onWordAdvanced});

  int get wordIndex => _wordIndex;

  /// Start karaoke reveal for [sentence], finishing in [duration].
  void startReveal(TaggedSentence sentence, Duration duration) {
    _wordTimer?.cancel();
    _wordIndex = 0;
    final words = sentence.displayText.split(' ');
    if (words.isEmpty) return;

    final msPerWord = (duration.inMilliseconds / words.length).round();
    _wordTimer = Timer.periodic(
      Duration(milliseconds: msPerWord.clamp(80, 600)),
      (timer) {
        if (_wordIndex >= words.length - 1) {
          timer.cancel();
          return;
        }
        _wordIndex++;
        onWordAdvanced();
      },
    );
  }

  /// Immediately reveal all words (sentence completed).
  void revealAll() {
    _wordTimer?.cancel();
    _wordIndex = 999;
    onWordAdvanced();
  }

  void dispose() {
    _wordTimer?.cancel();
  }
}
