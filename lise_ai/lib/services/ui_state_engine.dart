import '../models/cognitive_profile.dart';
import '../models/lesson_mode.dart';

// ── UI mode ───────────────────────────────────────────────────────────────────

enum UIMode {
  ogretmen,      // Teacher explanation
  sesliDers,     // Voice lesson (text + voice hybrid)
  soruCoz,       // Socratic problem solving
  hizliCevap,    // Quick answers
  tahta,         // Whiteboard
  pdfAnaliz,     // PDF analysis
  canliKonusma,  // Full realtime voice conversation
}

extension UIModeExt on UIMode {
  String get label => switch (this) {
        UIMode.ogretmen     => 'Öğretmen',
        UIMode.sesliDers    => 'Sesli Ders',
        UIMode.soruCoz      => 'Soru Çöz',
        UIMode.hizliCevap   => 'Hızlı Cevap',
        UIMode.tahta        => 'Tahta',
        UIMode.pdfAnaliz    => 'PDF Analiz',
        UIMode.canliKonusma => 'Canlı Konuşma',
      };

  String get shortLabel => switch (this) {
        UIMode.ogretmen     => 'Öğretmen',
        UIMode.sesliDers    => 'Sesli',
        UIMode.soruCoz      => 'Soru',
        UIMode.hizliCevap   => 'Hızlı',
        UIMode.tahta        => 'Tahta',
        UIMode.pdfAnaliz    => 'PDF',
        UIMode.canliKonusma => 'Canlı',
      };

  LessonMode get lessonMode => switch (this) {
        UIMode.ogretmen     => LessonMode.ogretmenGibi,
        UIMode.sesliDers    => LessonMode.sesliDers,
        UIMode.soruCoz      => LessonMode.soruSorarak,
        UIMode.hizliCevap   => LessonMode.hizliCevap,
        UIMode.tahta        => LessonMode.tahtadaCoz,
        UIMode.pdfAnaliz    => LessonMode.ogretmenGibi,
        UIMode.canliKonusma => LessonMode.sesliDers,
      };

  bool get isVoiceMode =>
      this == UIMode.sesliDers || this == UIMode.canliKonusma;

  bool get needsPdf => this == UIMode.pdfAnaliz;
}

// ── Orb visual state ──────────────────────────────────────────────────────────

enum OrbVisualState {
  idle,
  listening,
  thinking,
  speaking,
  teaching,  // teacher-mode explanation
  solving,   // problem-solving focus
  interrupted,
  paused,
}

// ── UIStateEngine ─────────────────────────────────────────────────────────────
//
// Centralises all UI-facing state: mode, orb, motivation, amplitude.
// Pure data class — no ChangeNotifier; caller calls setState after mutations.

class UIStateEngine {
  UIMode mode = UIMode.ogretmen;
  OrbVisualState orbState = OrbVisualState.idle;
  double speechAmplitude = 0.0;   // 0-1 reactive to TTS/STT
  MotivationState motivation = MotivationState.normal;

  // ── LessonMode mapping ─────────────────────────────────────────────────────
  LessonMode get lessonMode => mode.lessonMode;

  // ── Colors ─────────────────────────────────────────────────────────────────

  static const _modeGradients = <UIMode, List<int>>{
    UIMode.ogretmen    : [0xFF060420, 0xFF0E0830],
    UIMode.sesliDers   : [0xFF041510, 0xFF082518],
    UIMode.soruCoz     : [0xFF041220, 0xFF071C30],
    UIMode.hizliCevap  : [0xFF180705, 0xFF260D07],
    UIMode.tahta       : [0xFF060608, 0xFF0A0A0E],
    UIMode.pdfAnaliz   : [0xFF050818, 0xFF090E28],
    UIMode.canliKonusma: [0xFF041510, 0xFF081E26],
  };

  static const _modeOrbColors = <UIMode, int>{
    UIMode.ogretmen    : 0xFF7C6BF8,
    UIMode.sesliDers   : 0xFF4ADE80,
    UIMode.soruCoz     : 0xFF38BDF8,
    UIMode.hizliCevap  : 0xFFF97316,
    UIMode.tahta       : 0xFFD1D5DB,
    UIMode.pdfAnaliz   : 0xFF818CF8,
    UIMode.canliKonusma: 0xFF34D399,
  };

  List<int> get _baseGradientInts =>
      _modeGradients[mode] ?? [0xFF060420, 0xFF0E0830];

  int get orbColorInt => _modeOrbColors[mode] ?? 0xFF7C6BF8;

  // Motivation shifts: additive adjustment to base gradient components
  List<int> get gradientInts {
    final base = _baseGradientInts;
    return switch (motivation) {
      MotivationState.frustrated => _lerpInts(base, [0xFF020820, 0xFF040B30], 0.35),
      MotivationState.anxious    => _lerpInts(base, [0xFF010101, 0xFF020202], 0.45),
      MotivationState.confident  => _lerpInts(base, [0xFF140840, 0xFF1C0C50], 0.20),
      MotivationState.bored      => _lerpInts(base, [0xFF180040, 0xFF220050], 0.25),
      _                          => base,
    };
  }

  static List<int> _lerpInts(List<int> a, List<int> b, double t) {
    return List.generate(a.length, (i) {
      final ac = _toARGB(a[i]);
      final bc = _toARGB(b[i]);
      return _fromARGB(
        255,
        (ac[0] + (bc[0] - ac[0]) * t).round(),
        (ac[1] + (bc[1] - ac[1]) * t).round(),
        (ac[2] + (bc[2] - ac[2]) * t).round(),
      );
    });
  }

  static List<int> _toARGB(int v) => [
        (v >> 16) & 0xFF, // R
        (v >> 8) & 0xFF,  // G
        v & 0xFF,          // B
      ];

  static int _fromARGB(int a, int r, int g, int b) =>
      (a << 24) | (r << 16) | (g << 8) | b;

  // ── Ambient tuning (motivation-adaptive) ──────────────────────────────────

  int get particleCount => switch (motivation) {
        MotivationState.frustrated => 6,
        MotivationState.anxious    => 4,
        MotivationState.confident  => 20,
        MotivationState.bored      => 22,
        _                          => 13,
      };

  double get animSpeed => switch (motivation) {
        MotivationState.frustrated => 0.60,
        MotivationState.anxious    => 0.65,
        MotivationState.confident  => 1.30,
        MotivationState.bored      => 1.40,
        _                          => 1.00,
      };

  double get orbBreathScale => switch (motivation) {
        MotivationState.frustrated => 0.04,
        MotivationState.anxious    => 0.03,
        MotivationState.confident  => 0.10,
        _                          => 0.07,
      };
}
