import 'dart:convert';
import '../services/storage_service.dart';

// ── Achievement definition ────────────────────────────────────────────────────

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;   // emoji

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

// ── All achievements ───────────────────────────────────────────────────────────

class Achievements {
  static const firstQuestion = Achievement(
    id: 'first_question',
    title: 'İlk Adım',
    description: 'İlk soruyu sordun — yolculuk başladı!',
    icon: '🌱',
  );
  static const streak3 = Achievement(
    id: 'streak_3',
    title: '3 Günlük Seri',
    description: '3 gün üst üste çalıştın.',
    icon: '🔥',
  );
  static const streak7 = Achievement(
    id: 'streak_7',
    title: 'Haftalık Şampiyon',
    description: '7 gün hiç ara vermeden çalıştın!',
    icon: '⭐',
  );
  static const streak30 = Achievement(
    id: 'streak_30',
    title: 'Demir İrade',
    description: '30 gün kesintisiz! Olağanüstü bir disiplin.',
    icon: '🏆',
  );
  static const questions10 = Achievement(
    id: 'questions_10',
    title: 'Meraklı Zihin',
    description: '10 soru çözdün.',
    icon: '💡',
  );
  static const questions50 = Achievement(
    id: 'questions_50',
    title: 'Azimli Öğrenci',
    description: '50 soru çözdün — gerçek bir çalışma azmi!',
    icon: '📚',
  );
  static const questions100 = Achievement(
    id: 'questions_100',
    title: 'Yüzlük Kulüp',
    description: '100 soru çözdün. Mükemmel!',
    icon: '💯',
  );
  static const geometryMaster = Achievement(
    id: 'geometry_master',
    title: 'Geometri Ustası',
    description: 'Geometri konusunda %80+ başarı oranı yakaladın.',
    icon: '📐',
  );
  static const confidenceRecovery = Achievement(
    id: 'confidence_recovery',
    title: 'Yeniden Doğuş',
    description: 'Zorlu bir seriden sonra başarıyla toparlandın.',
    icon: '🌅',
  );
  static const examCampFinished = Achievement(
    id: 'exam_camp',
    title: 'Kamp Tamamlandı',
    description: 'Bir sınav kampını eksiksiz tamamladın.',
    icon: '⏱',
  );
  static const nightOwl = Achievement(
    id: 'night_owl',
    title: 'Gece Kuşu',
    description: 'Gece 22:00 sonrası bir soru sordun.',
    icon: '🌙',
  );
  static const comeback = Achievement(
    id: 'comeback',
    title: 'Vazgeçmeyen',
    description: 'Aradan sonra geri döndün — bu irade ödüllendirilmeli.',
    icon: '💪',
  );
  static const speedSolver = Achievement(
    id: 'speed_solver',
    title: 'Hız Ustası',
    description: '10 soruyu 10 saniyeden kısa sürede yanıtladın.',
    icon: '⚡',
  );

  static const List<Achievement> all = [
    firstQuestion,
    streak3,
    streak7,
    streak30,
    questions10,
    questions50,
    questions100,
    geometryMaster,
    confidenceRecovery,
    examCampFinished,
    nightOwl,
    comeback,
    speedSolver,
  ];
}

// ── UnlockedAchievement ───────────────────────────────────────────────────────

class UnlockedAchievement {
  final String id;
  final DateTime unlockedAt;

  const UnlockedAchievement({required this.id, required this.unlockedAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory UnlockedAchievement.fromJson(Map<String, dynamic> j) =>
      UnlockedAchievement(
        id: j['id'] as String,
        unlockedAt: DateTime.parse(j['unlockedAt'] as String),
      );
}

// ── AchievementService ────────────────────────────────────────────────────────

class AchievementService {
  static const _kKey = 'achievements_v1';

  final List<UnlockedAchievement> _unlocked = [];

  List<UnlockedAchievement> get unlocked => List.unmodifiable(_unlocked);
  int get unlockedCount => _unlocked.length;

  bool isUnlocked(String id) => _unlocked.any((u) => u.id == id);

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _unlocked.addAll(
          list.map((e) => UnlockedAchievement.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {
        // ignore corrupt data
      }
    }
  }

  // ── Unlock ──────────────────────────────────────────────────────────────────

  /// Unlock an achievement. Returns the Achievement if newly unlocked, null if
  /// already unlocked or not found.
  Achievement? unlock(String id, StorageService storage) {
    if (isUnlocked(id)) return null;
    final achievement = Achievements.all.where((a) => a.id == id).firstOrNull;
    if (achievement == null) return null;
    _unlocked.add(UnlockedAchievement(id: id, unlockedAt: DateTime.now()));
    _save(storage);
    return achievement;
  }

  // ── Context-aware auto-unlock ─────────────────────────────────────────────

  /// Check conditions and unlock all applicable achievements.
  /// Returns list of newly unlocked achievements.
  List<Achievement> checkAndUnlock({
    required int solvedCount,
    required int currentStreak,
    required bool isComebackStreak,
    required bool examCampCompleted,
    required StorageService storage,
  }) {
    final newly = <Achievement>[];

    void try_(String id) {
      final a = unlock(id, storage);
      if (a != null) newly.add(a);
    }

    if (solvedCount >= 1) try_(Achievements.firstQuestion.id);
    if (solvedCount >= 10) try_(Achievements.questions10.id);
    if (solvedCount >= 50) try_(Achievements.questions50.id);
    if (solvedCount >= 100) try_(Achievements.questions100.id);
    if (currentStreak >= 3) try_(Achievements.streak3.id);
    if (currentStreak >= 7) try_(Achievements.streak7.id);
    if (currentStreak >= 30) try_(Achievements.streak30.id);
    if (isComebackStreak) try_(Achievements.comeback.id);
    if (examCampCompleted) try_(Achievements.examCampFinished.id);

    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 4) try_(Achievements.nightOwl.id);

    return newly;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _save(StorageService storage) async {
    final json = jsonEncode(_unlocked.map((u) => u.toJson()).toList());
    await storage.saveSetting(_kKey, json);
  }
}
