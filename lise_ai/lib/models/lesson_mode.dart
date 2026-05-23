import 'package:flutter/material.dart';

// ── Lesson mode ───────────────────────────────────────────────────────────────

enum LessonMode {
  hizliCevap,
  ogretmenGibi,
  sadaceIpucu,
  soruSorarak,
  sinavKocu,
  tahtadaCoz,
  sesliDers,
}

extension LessonModeExt on LessonMode {
  String get label => switch (this) {
        LessonMode.hizliCevap => 'Hızlı Cevap',
        LessonMode.ogretmenGibi => 'Öğretmen Gibi Anlat',
        LessonMode.sadaceIpucu => 'Sadece İpucu Ver',
        LessonMode.soruSorarak => 'Soru Sorarak Öğret',
        LessonMode.sinavKocu => 'Sınav Koçu',
        LessonMode.tahtadaCoz => 'Tahtada Çöz',
        LessonMode.sesliDers => 'Sesli Ders',
      };

  String get shortLabel => switch (this) {
        LessonMode.hizliCevap => 'Hızlı',
        LessonMode.ogretmenGibi => 'Öğretmen',
        LessonMode.sadaceIpucu => 'İpucu',
        LessonMode.soruSorarak => 'Soru Sor',
        LessonMode.sinavKocu => 'Sınav',
        LessonMode.tahtadaCoz => 'Tahta',
        LessonMode.sesliDers => 'Sesli',
      };

  IconData get icon => switch (this) {
        LessonMode.hizliCevap => Icons.flash_on_rounded,
        LessonMode.ogretmenGibi => Icons.school_rounded,
        LessonMode.sadaceIpucu => Icons.lightbulb_outline_rounded,
        LessonMode.soruSorarak => Icons.quiz_rounded,
        LessonMode.sinavKocu => Icons.emoji_events_rounded,
        LessonMode.tahtadaCoz => Icons.draw_rounded,
        LessonMode.sesliDers => Icons.record_voice_over_rounded,
      };

  /// Whether this mode always shows the board button regardless of topic.
  bool get alwaysShowBoard =>
      this == LessonMode.tahtadaCoz || this == LessonMode.sesliDers;

  /// Max tokens for the Claude API call (short modes need fewer).
  int get maxTokens => this == LessonMode.hizliCevap ? 600 : 2048;
}

// ── Student level ─────────────────────────────────────────────────────────────

enum StudentLevel {
  lgs,
  sinif9,
  sinif10,
  sinif11,
  sinif12,
  tyt,
  ayt,
}

extension StudentLevelExt on StudentLevel {
  String get label => switch (this) {
        StudentLevel.lgs => 'LGS',
        StudentLevel.sinif9 => '9. Sınıf',
        StudentLevel.sinif10 => '10. Sınıf',
        StudentLevel.sinif11 => '11. Sınıf',
        StudentLevel.sinif12 => '12. Sınıf',
        StudentLevel.tyt => 'TYT',
        StudentLevel.ayt => 'AYT',
      };
}
