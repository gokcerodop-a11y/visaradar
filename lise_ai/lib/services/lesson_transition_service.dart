import 'dart:math' as math;

import '../models/learning_journal.dart';
import '../models/teacher_identity.dart';
import '../services/session_continuity_service.dart';

// ── TransitionType ────────────────────────────────────────────────────────────

enum TransitionType {
  criticalMoment,  // "Şimdi kritik yere geldik"
  confusionPoint,  // "Burayı çok kişi karıştırıyor"
  miniReview,      // "Şimdi mini tekrar yapalım"
  smallBreak,      // "Küçük bir mola verelim"
  encouragement,   // "Harika gidiyorsun"
  contextSwitch,   // "Konuyu değiştirelim"
  examWarning,     // "Bu ÖSYM'de çok çıkıyor"
  deepDive,        // "Bunu derinlemesine inceleyelim"
}

// ── LessonTransitionService ───────────────────────────────────────────────────
//
// Two purposes:
//   1. Natural transition phrases — inserted as teacher behaviors mid-lesson
//   2. Memory-rich continuity — teacher references past sessions, mistakes, victories
//
// All methods return Turkish text strings.

class LessonTransitionService {
  final _rng = math.Random();

  // ── Phrase banks ───────────────────────────────────────────────────────────

  static const _phrases = <TransitionType, List<String>>{
    TransitionType.criticalMoment: [
      'Şimdi kritik yere geldik — dikkat.',
      'Burası çok önemli, not al.',
      'İşte asıl mesele burada.',
      'Dur — bu kısım çok önemli.',
      'Şimdi konunun kalbi geliyor.',
    ],
    TransitionType.confusionPoint: [
      'Burayı çok kişi karıştırıyor — dikkatli ol.',
      'Bu noktada çoğu öğrenci takılıyor.',
      'Klasik hata burada yapılıyor.',
      'Sınıfın büyük çoğunluğu burada yanılıyor.',
    ],
    TransitionType.miniReview: [
      'Şimdi mini tekrar yapalım.',
      'Anlattıklarımı bir toplayalım.',
      'Kafanda oturdu mu? Kısa tekrar:',
      'Hızlı bir özet geçelim.',
    ],
    TransitionType.smallBreak: [
      'Küçük bir mola verelim.',
      'Beynin biraz dinlensin.',
      'İki dakika ara — sonra devam.',
      'Şimdi nefes al. Hemen dönüyoruz.',
    ],
    TransitionType.encouragement: [
      'Harika gidiyorsun!',
      'Çok iyi ilerliyorsun.',
      'Bunu görüyorsun — zekice.',
      'Evet, tam doğru düşünüyorsun.',
      'İşte bu! Devam et.',
    ],
    TransitionType.contextSwitch: [
      'Şimdi farklı bir açıdan bakalım.',
      'Konuyu değiştirelim — taze başlayalım.',
      'Biraz farklı bir örnek deneyelim.',
    ],
    TransitionType.examWarning: [
      'Bu ÖSYM\'de çok çıkıyor — dikkat.',
      'TYT\'de bu tip soru sık geliyor.',
      'Sınavlarda sık çıkan konu — bu kısmı iyi çalış.',
      'Geçen yıl YKS\'de tam bu çıktı.',
    ],
    TransitionType.deepDive: [
      'Bunu derinlemesine inceleyelim.',
      'Teorik kısma girelim — hazır mısın?',
      'Şimdi detaylara inelim.',
    ],
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Pick a random transition phrase for [type].
  String getPhrase(TransitionType type) {
    final list = _phrases[type] ?? ['Devam edelim.'];
    return list[_rng.nextInt(list.length)];
  }

  // ── Memory-rich references ─────────────────────────────────────────────────

  /// Reference a past mistake the student made in this topic.
  String? buildMistakeReference(
    SessionContinuityData data,
    String topic,
    TeacherIdentity teacher,
  ) {
    final count = data.repeatedMistakes[topic];
    if (count == null || count < 2) return null;

    final phrases = [
      '${teacher.teacherName}: "$topic konusunda daha önce de takıldın — bu sefer tam anlayalım."',
      '"$topic\'da $count kez aynı noktada zorlandık. Şimdi kökten çözelim."',
      '"Geçen sefer $topic\'ta zorlanmıştık — şimdi üzerine gidelim."',
    ];
    return phrases[_rng.nextInt(phrases.length)];
  }

  /// Reference a past victory or strong topic.
  String? buildVictoryReference(
    LearningJournal journal,
    String topic,
    TeacherIdentity teacher,
  ) {
    final strongest = journal.strongestSubject;
    if (strongest == null) return null;

    final phrases = [
      '"$strongest\'da çok iyi olduğunu biliyorum — aynı mantıkla bakacağız."',
      '"Hatırlıyor musun $strongest\'daki başarını? Burada da yapabilirsin."',
      '"Sen $strongest\'ı nasıl çözdüysen — aynı yaklaşım burada da işe yarar."',
    ];
    return phrases[_rng.nextInt(phrases.length)];
  }

  /// Reference overdue homework.
  String? buildHomeworkReference(
    LearningJournal journal,
    TeacherIdentity teacher,
  ) {
    final overdue = journal.overdueHomework;
    if (overdue.isEmpty) return null;
    final hw = overdue.first;

    final phrases = [
      '"${hw.topic} ödevi kaldı — bugün onu da bitirelim mi?"',
      '"Geçen verdiğim ${hw.topic} ödevini yapmışın mı?"',
      '"${hw.topic} ödevin var — bir göz atalım."',
    ];
    return phrases[_rng.nextInt(phrases.length)];
  }

  /// Build a full return greeting referencing last session.
  String buildReturnReference(
    SessionContinuityData data,
    TeacherIdentity teacher,
  ) {
    final lastTopic = data.lastTopics.isNotEmpty ? data.lastTopics.last : null;
    final unfinished = data.unfinishedTopic;
    final date = data.lastSessionDate;
    final name = teacher.teacherName;

    if (unfinished != null) {
      return '$name: "Geçen sefer $unfinished\'ta kalmıştık. Devam edelim mi?"';
    }

    if (lastTopic != null && date != null) {
      final dayDiff = DateTime.now().difference(date).inDays;
      final timeAgo = dayDiff == 0
          ? 'bugün daha önce'
          : dayDiff == 1
              ? 'dün'
              : '$dayDiff gün önce';
      return '$name: "$timeAgo $lastTopic üzerinde çalışmıştık. Başlayalım mı?"';
    }

    return '${teacher.phrases.openingHooks.first}! Bugün ne öğrenmek istiyorsun?';
  }

  // ── System prompt block ────────────────────────────────────────────────────

  /// Full memory block injected into Claude system prompt for continuity.
  String buildContinuityReferenceBlock({
    required SessionContinuityData continuity,
    required LearningJournal journal,
    required TeacherIdentity teacher,
  }) {
    final buf = StringBuffer();
    buf.writeln('\n[ÖĞRETMEN HAFIZA SİSTEMİ]');
    buf.writeln('Öğretmen adı: ${teacher.teacherName}');

    // Past mistakes to reference naturally
    final mistakes = continuity.repeatedMistakes.entries
        .where((e) => e.value >= 2)
        .take(3)
        .map((e) => '${e.key} (${e.value}x)')
        .join(', ');
    if (mistakes.isNotEmpty) {
      buf.writeln('Tekrar eden hatalar: $mistakes — bunlara proaktif dön.');
    }

    // Strongest subject to leverage
    final strongest = journal.strongestSubject;
    if (strongest != null) {
      buf.writeln('Güçlü konu: $strongest — bu konuya analoji kur.');
    }

    // Weakest subject
    final weakest = journal.weakestSubject;
    if (weakest != null) {
      buf.writeln('Zayıf konu: $weakest — nazikçe destekle, yargılama.');
    }

    // Overdue homework
    final overdue = journal.overdueHomework;
    if (overdue.isNotEmpty) {
      buf.writeln('Gecikmiş ödev: ${overdue.first.topic} — fırsatçıkta hatırlat.');
    }

    // Analogies already used (don't repeat)
    if (continuity.usedAnalogies.isNotEmpty) {
      final used = continuity.usedAnalogies.entries.take(3).map((e) => '${e.key}:${e.value}').join(', ');
      buf.writeln('Kullanılan analojiler (tekrar etme): $used');
    }

    // Exam readiness
    buf.writeln('Sınav hazırlık skoru: ${(journal.examReadinessScore * 100).round()}%');

    buf.writeln('''
Kurallar:
- Geçmiş dersleri doğal sohbette referans ver
- "Geçen sefer...", "Hatırladın mı...", "Daha önce de..." ile başla
- Başarıları kutla, hataları nazikçe düzelt
- Monoton tekrar etme — her referans taze ve anlamlı olsun
''');
    return buf.toString();
  }

  // ── Auto transition detection ──────────────────────────────────────────────

  /// Given the AI's reply text, detect if a natural transition phrase fits.
  TransitionType? detectTransitionFromReply(String reply) {
    final lower = reply.toLowerCase();
    if (lower.contains('ösym') || lower.contains('yks') || lower.contains('tyt')) {
      return TransitionType.examWarning;
    }
    if (lower.contains('kritik') || lower.contains('önemli') || lower.contains('dikkat')) {
      return TransitionType.criticalMoment;
    }
    if (lower.contains('özet') || lower.contains('tekrar') || lower.contains('toplayalım')) {
      return TransitionType.miniReview;
    }
    if (lower.contains('karıştırıyor') || lower.contains('hata')) {
      return TransitionType.confusionPoint;
    }
    return null;
  }
}
