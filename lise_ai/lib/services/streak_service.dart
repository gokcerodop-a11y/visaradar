import 'dart:convert';
import '../services/storage_service.dart';

// ── StreakRecord ───────────────────────────────────────────────────────────────

class StreakRecord {
  final int currentStreak;      // consecutive days with activity
  final int longestStreak;      // all-time best
  final int weeklyDays;         // active days this week (0-7)
  final DateTime? lastActiveDate;
  final bool isComebackStreak;  // missed ≥2 days, then returned

  const StreakRecord({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.weeklyDays = 0,
    this.lastActiveDate,
    this.isComebackStreak = false,
  });

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'weeklyDays': weeklyDays,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'isComebackStreak': isComebackStreak,
      };

  factory StreakRecord.fromJson(Map<String, dynamic> j) => StreakRecord(
        currentStreak: j['currentStreak'] as int? ?? 0,
        longestStreak: j['longestStreak'] as int? ?? 0,
        weeklyDays: j['weeklyDays'] as int? ?? 0,
        lastActiveDate: j['lastActiveDate'] != null
            ? DateTime.tryParse(j['lastActiveDate'] as String)
            : null,
        isComebackStreak: j['isComebackStreak'] as bool? ?? false,
      );
}

// ── StreakService ──────────────────────────────────────────────────────────────

class StreakService {
  static const _kKey = 'streak_record';

  StreakRecord _record = const StreakRecord();
  StreakRecord get record => _record;

  int get currentStreak => _record.currentStreak;
  int get longestStreak => _record.longestStreak;
  int get weeklyDays => _record.weeklyDays;
  bool get isComebackStreak => _record.isComebackStreak;

  /// Weekly consistency score 0.0–1.0 (active days / 7)
  double get weeklyConsistency => _record.weeklyDays / 7;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _record = StreakRecord.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _record = const StreakRecord();
      }
    }
  }

  // ── Daily check-in ──────────────────────────────────────────────────────────

  /// Call on every app launch / first interaction of the day.
  /// Returns true if the streak was extended (new day).
  Future<bool> checkIn(StorageService storage) async {
    final today = _dateOnly(DateTime.now());
    final last = _record.lastActiveDate != null
        ? _dateOnly(_record.lastActiveDate!)
        : null;

    if (last == today) return false; // already checked in today

    final daysSinceLast = last != null ? today.difference(last).inDays : null;
    final isMissed = daysSinceLast != null && daysSinceLast >= 2;
    final isComeback = isMissed;

    final newStreak = (daysSinceLast == 1)
        ? _record.currentStreak + 1
        : 1; // reset on gap

    final newWeekly = _calcWeeklyDays(_record, today);
    final newLongest =
        newStreak > _record.longestStreak ? newStreak : _record.longestStreak;

    _record = StreakRecord(
      currentStreak: newStreak,
      longestStreak: newLongest,
      weeklyDays: newWeekly,
      lastActiveDate: today,
      isComebackStreak: isComeback,
    );
    await _save(storage);
    return true;
  }

  // ── Motivational message ─────────────────────────────────────────────────────

  String motivationalMessage() {
    if (_record.isComebackStreak) {
      return 'Geri döndün! Her şey yeniden başlayabilir. 💪';
    }
    return switch (_record.currentStreak) {
      0     => 'Bugün ilk adımını at!',
      1     => 'İlk gün — harika bir başlangıç!',
      2     => '2 gün üst üste — ritim tutuyorsun!',
      3     => '3 günlük seri — devam et!',
      7     => '7 gün! Bir hafta boyunca hiç vazgeçmedin! 🔥',
      14    => '2 hafta! Disiplin bir alışkanlık hâline geliyor! ⭐',
      30    => '30 gün! Efsane bir seri! 🏆',
      _     when _record.currentStreak >= 30 =>
        '${_record.currentStreak} günlük seri! Muhteşem! 🔥',
      _     when _record.currentStreak >= 7  =>
        '${_record.currentStreak} gün üst üste — harikasın!',
      _     => '${_record.currentStreak} günlük seri — devam et!',
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int _calcWeeklyDays(StreakRecord old, DateTime today) {
    // Start of the current week (Monday)
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final last = old.lastActiveDate;
    // If last active was before this week, reset weekly count
    if (last == null || last.isBefore(weekStart)) return 1;
    return (old.weeklyDays + 1).clamp(0, 7);
  }

  Future<void> _save(StorageService storage) async {
    await storage.saveSetting(_kKey, jsonEncode(_record.toJson()));
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
