import '../models/speech_tag.dart';
import '../models/teacher_identity.dart';

// ── HumanPacingEngine ─────────────────────────────────────────────────────────
//
// Calculates natural timing for sentence delivery.
// A real teacher doesn't rush — they breathe, slow at hard parts,
// accelerate at obvious points, and wait after questions.
//
// All methods are pure functions — no state, easily testable.

class HumanPacingEngine {
  final PacingProfile profile;
  final double emotionalSpeedModifier; // from TeacherEmotionalState.animSpeedModifier

  const HumanPacingEngine({
    this.profile = PacingProfile.normal,
    this.emotionalSpeedModifier = 1.0,
  });

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Total pause BEFORE delivering [sentence] (pre-delay before TTS starts).
  Duration prePause(TaggedSentence sentence) {
    var ms = sentence.primaryTag.prePauseMs;
    ms = (ms * _profileFactor).round();
    // Add micro-pause for very long sentences (listener needs a breath)
    if (sentence.displayText.length > 120) ms += 150;
    return Duration(milliseconds: ms);
  }

  /// Total pause AFTER [sentence] finishes playing (post-delay before next sentence).
  Duration postPause(TaggedSentence sentence, {bool isLast = false}) {
    // Base: inter-sentence gap
    var ms = _baseInterSentenceMs;

    // Speech tag bonus
    ms += sentence.primaryTag.postPauseMs;

    // Punctuation modifiers
    final text = sentence.displayText;
    if (text.endsWith('?')) ms += 400;       // question → wait for reflection
    if (text.endsWith('!')) ms -= 80;        // exclamation → faster follow-up
    if (text.endsWith('…')) ms += 200;       // ellipsis → trailing thought
    if (text.endsWith(':')) ms += 150;       // colon → about to list

    // Complexity: longer sentence → reader needs more time
    final words = text.split(' ').length;
    if (words > 20) ms += 180;
    if (words > 35) ms += 220;

    // Last sentence → breath before session completes
    if (isLast) ms += 300;

    // Apply profile and emotional modifiers (slower → more pause)
    ms = (ms / (_profileFactor * emotionalSpeedModifier)).round();
    return Duration(milliseconds: ms.clamp(80, 2500));
  }

  /// TTS speech rate for this sentence (passed to future ElevenLabs SSML).
  double speechRate(TaggedSentence sentence) {
    final tagRate = sentence.primaryTag.rateMultiplier;
    final profileRate = switch (profile) {
      PacingProfile.slow   => 0.88,
      PacingProfile.normal => 1.00,
      PacingProfile.fast   => 1.15,
    };
    // Emotional modifier caps TTS rate gently
    final emotionalRate = (emotionalSpeedModifier * 0.15 + 0.85).clamp(0.7, 1.3);
    return (tagRate * profileRate * emotionalRate).clamp(0.65, 1.4);
  }

  /// Estimate spoken duration of [text] in ms (approximate at ~130 WPM Turkish).
  int estimatedDurationMs(String text) {
    const wordsPerMin = 130;
    final words = text.trim().split(RegExp(r'\s+')).length;
    final rate = speechRate(SpeechTagParser.parse(text));
    return ((words / wordsPerMin * 60000) / rate).round().clamp(500, 30000);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  double get _profileFactor => switch (profile) {
        PacingProfile.slow   => 0.70, // slow profile → LONGER pauses
        PacingProfile.normal => 1.00,
        PacingProfile.fast   => 1.45, // fast profile → shorter pauses
      };

  int get _baseInterSentenceMs => switch (profile) {
        PacingProfile.slow   => 480,
        PacingProfile.normal => 300,
        PacingProfile.fast   => 160,
      };

  // ── Factory helpers ────────────────────────────────────────────────────────

  static HumanPacingEngine fromIdentity(TeacherIdentity identity,
      {double emotionalModifier = 1.0}) {
    return HumanPacingEngine(
      profile: identity.pacingProfile,
      emotionalSpeedModifier: emotionalModifier,
    );
  }
}

// ── Sentence complexity classifier ────────────────────────────────────────────

class SentenceComplexity {
  static bool isMath(String text) {
    return text.contains(RegExp(r'[\$\\]|\d+[×÷√∫∂]|frac|sqrt|sum'));
  }

  static bool isDefinition(String text) {
    final lower = text.toLowerCase();
    return lower.contains('denir') ||
        lower.contains('tanımlanır') ||
        lower.contains('olarak bilinir') ||
        lower.contains('demektir');
  }

  static bool isListItem(String text) =>
      text.trimLeft().startsWith(RegExp(r'\d+\.|[-•]'));

  static bool isExamWarning(String text) {
    final lower = text.toLowerCase();
    return lower.contains('ösym') ||
        lower.contains('yks') ||
        lower.contains('tyt') ||
        lower.contains('sınav') ||
        lower.contains('dikkat') ||
        lower.contains('kritik');
  }
}
