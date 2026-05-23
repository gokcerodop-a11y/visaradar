import '../models/student_profile.dart';
import 'storage_service.dart';

// ── Profile service ────────────────────────────────────────────────────────────

class ProfileService {
  static const _profileKey = 'student_profile';

  final StorageService _storage;
  StudentProfile _profile = StudentProfile();

  ProfileService(this._storage);

  StudentProfile get profile => _profile;

  Future<void> init() async {
    final raw = _storage.loadSetting(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _profile = StudentProfile.fromJsonString(raw);
      } catch (_) {
        _profile = StudentProfile();
      }
    }
    _updateStreak();
  }

  // ── Interaction recording ─────────────────────────────────────────────────

  Future<void> recordInteraction(InteractionRecord record) async {
    _profile.recentHistory.insert(0, record);
    if (_profile.recentHistory.length > 40) {
      _profile.recentHistory.removeLast();
    }
    _updateStreak();
    await _save();
  }

  // ── Streak logic ──────────────────────────────────────────────────────────

  void _updateStreak() {
    final today = _today();
    final last = _profile.lastActiveDate;
    if (last == null) {
      _profile.lastActiveDate = today;
      return;
    }
    final lastDay = DateTime(last.year, last.month, last.day);
    final diff = today.difference(lastDay).inDays;
    if (diff == 0) {
      // same day — no change
    } else if (diff == 1) {
      // consecutive day
      _profile.streakDays++;
      _profile.lastActiveDate = today;
    } else {
      // streak broken
      _profile.streakDays = 1;
      _profile.lastActiveDate = today;
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Claude memory summary ─────────────────────────────────────────────────

  /// Returns a short Turkish summary to inject into the system prompt.
  String buildMemorySummary() {
    if (_profile.totalInteractions == 0) return '';

    final buf = StringBuffer();
    buf.writeln('\n--- ÖĞRENCİ PROFİLİ (bağlam olarak kullan) ---');

    if (_profile.name != null) {
      buf.writeln('Öğrenci adı: ${_profile.name}');
    }

    if (_profile.streakDays > 1) {
      buf.writeln('${_profile.streakDays} gündür aktif çalışıyor.');
    }

    final weak = _profile.weakTopics;
    if (weak.isNotEmpty) {
      buf.writeln('Güçsüz konular (daha dikkatli anlat): ${weak.take(3).join(', ')}');
    }

    final strong = _profile.strongTopics;
    if (strong.isNotEmpty) {
      buf.writeln('Güçlü konular: ${strong.take(3).join(', ')}');
    }

    // Last 3 interactions
    final recent = _profile.recentHistory.take(3).toList();
    if (recent.isNotEmpty) {
      final topics = recent.map((r) => r.topic).toSet().join(', ');
      buf.writeln('Son çalışılan konular: $topics');
    }

    buf.writeln('Toplam ders etkileşimi: ${_profile.totalInteractions}');
    buf.writeln('--- ÖĞRENCİ PROFİLİ SONU ---');

    return buf.toString();
  }

  // ── Daily greeting ────────────────────────────────────────────────────────

  /// Returns a Turkish greeting string if student has history and hasn't been
  /// greeted today, or null if no greeting is needed.
  String? getDailyGreeting() {
    if (_profile.totalInteractions == 0) return null;

    final last = _profile.lastInteractionTime;
    if (last == null) return null;

    final today = _today();
    final lastDay = DateTime(last.year, last.month, last.day);
    final diff = today.difference(lastDay).inDays;

    // Only greet if last session was yesterday or earlier (not same session)
    if (diff < 1) return null;

    final topic = _profile.lastTopic;
    final streak = _profile.streakDays;

    if (streak >= 3) {
      return '🔥 $streak günlük serindesin! ${topic != null ? '"$topic" konusuna devam edelim mi?' : 'Bugün ne çalışıyoruz?'}';
    }
    if (topic != null) {
      return '👋 Tekrar hoş geldin! "$topic" konusunda kaldığın yerden devam edelim mi?';
    }
    return '👋 Tekrar hoş geldin! Bugün ne öğrenmek istiyorsun?';
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    await _storage.saveSetting(_profileKey, _profile.toJsonString());
  }
}
