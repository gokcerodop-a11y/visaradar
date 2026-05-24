import 'dart:convert';
import 'dart:math' as math;

import '../models/learning_journal.dart';
import '../models/teacher_identity.dart';
import 'storage_service.dart';

// ── Session continuity data ───────────────────────────────────────────────────

class SessionContinuityData {
  List<String> lastTopics;                // recent topics discussed
  String? unfinishedTopic;               // lesson that was cut short
  Map<String, int> repeatedMistakes;     // topic → error count
  int frustrationStreak;                 // consecutive frustrated turns
  List<double> confidenceTrend;          // last N success estimates
  List<String> previousExamples;         // examples already used (avoid repeating)
  DateTime? lastSessionDate;
  String? lastSessionSummary;            // brief AI-written recap
  Map<String, String> usedAnalogies;     // topic → analogy already explained

  SessionContinuityData({
    List<String>? lastTopics,
    this.unfinishedTopic,
    Map<String, int>? repeatedMistakes,
    this.frustrationStreak = 0,
    List<double>? confidenceTrend,
    List<String>? previousExamples,
    this.lastSessionDate,
    this.lastSessionSummary,
    Map<String, String>? usedAnalogies,
  })  : lastTopics = lastTopics ?? [],
        repeatedMistakes = repeatedMistakes ?? {},
        confidenceTrend = confidenceTrend ?? [],
        previousExamples = previousExamples ?? [],
        usedAnalogies = usedAnalogies ?? {};

  // ── Computed properties ───────────────────────────────────────────────────

  double get avgConfidence {
    if (confidenceTrend.isEmpty) return 0.5;
    return confidenceTrend.reduce((a, b) => a + b) / confidenceTrend.length;
  }

  bool get hasReturnContent =>
      lastSessionDate != null && lastTopics.isNotEmpty;

  bool get isReturningToday {
    if (lastSessionDate == null) return false;
    final diff = DateTime.now().difference(lastSessionDate!);
    return diff.inHours < 6;
  }

  String get mostProblematicTopic {
    if (repeatedMistakes.isEmpty) return '';
    return repeatedMistakes.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'lastTopics': lastTopics,
        'unfinishedTopic': unfinishedTopic,
        'repeatedMistakes': repeatedMistakes,
        'frustrationStreak': frustrationStreak,
        'confidenceTrend': confidenceTrend,
        'previousExamples': previousExamples,
        'lastSessionDate': lastSessionDate?.millisecondsSinceEpoch,
        'lastSessionSummary': lastSessionSummary,
        'usedAnalogies': usedAnalogies,
      };

  factory SessionContinuityData.fromJson(Map<String, dynamic> j) =>
      SessionContinuityData(
        lastTopics:
            (j['lastTopics'] as List? ?? []).map((e) => e.toString()).toList(),
        unfinishedTopic: j['unfinishedTopic'] as String?,
        repeatedMistakes: Map<String, int>.from(
            (j['repeatedMistakes'] as Map? ?? {}).map(
                (k, v) => MapEntry(k as String, (v as num).toInt()))),
        frustrationStreak: j['frustrationStreak'] as int? ?? 0,
        confidenceTrend: (j['confidenceTrend'] as List? ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
        previousExamples: (j['previousExamples'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        lastSessionDate: j['lastSessionDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                j['lastSessionDate'] as int)
            : null,
        lastSessionSummary: j['lastSessionSummary'] as String?,
        usedAnalogies: Map<String, String>.from(
            (j['usedAnalogies'] as Map? ?? {}).map(
                (k, v) => MapEntry(k as String, v.toString()))),
      );
}

// ── Session continuity service ────────────────────────────────────────────────

class SessionContinuityService {
  static const _key = 'session_continuity_v1';
  static const _maxTopics = 10;
  static const _maxTrend = 15;

  SessionContinuityData _data = SessionContinuityData();
  late StorageService _storage;

  SessionContinuityData get data => _data;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      try {
        _data = SessionContinuityData.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save() =>
      _storage.saveSetting(_key, jsonEncode(_data.toJson()));

  // ── Session events ─────────────────────────────────────────────────────────

  /// Record interaction outcome. Call after each AI response.
  Future<void> recordInteraction({
    String? topic,
    double successEstimate = 0.5,
    bool hadFrustration = false,
    String? exampleUsed,
    String? analogyUsed,
  }) async {
    if (topic != null && topic.isNotEmpty && topic != 'Genel') {
      if (!_data.lastTopics.contains(topic)) {
        _data.lastTopics.insert(0, topic);
        if (_data.lastTopics.length > _maxTopics) {
          _data.lastTopics.removeLast();
        }
      }
    }

    // Confidence trend
    _data.confidenceTrend.add(successEstimate);
    if (_data.confidenceTrend.length > _maxTrend) {
      _data.confidenceTrend.removeAt(0);
    }

    // Frustration streak
    if (hadFrustration) {
      _data.frustrationStreak++;
    } else if (successEstimate > 0.6) {
      _data.frustrationStreak = math.max(0, _data.frustrationStreak - 1);
    }

    if (exampleUsed != null && !_data.previousExamples.contains(exampleUsed)) {
      _data.previousExamples.add(exampleUsed);
      if (_data.previousExamples.length > 20) _data.previousExamples.removeAt(0);
    }

    if (analogyUsed != null && topic != null) {
      _data.usedAnalogies[topic] = analogyUsed;
    }

    _data.lastSessionDate = DateTime.now();
    await _save();
  }

  /// Mark a topic as having repeated mistakes.
  Future<void> recordMistake(String topic) async {
    _data.repeatedMistakes[topic] =
        (_data.repeatedMistakes[topic] ?? 0) + 1;
    await _save();
  }

  /// Mark a topic as unfinished (lesson cut short).
  Future<void> markUnfinished(String topic) async {
    _data.unfinishedTopic = topic;
    await _save();
  }

  /// Clear unfinished topic when lesson completes.
  Future<void> clearUnfinished() async {
    _data.unfinishedTopic = null;
    await _save();
  }

  /// Save a brief summary of today's session.
  Future<void> saveSessionSummary(String summary) async {
    _data.lastSessionSummary = summary;
    await _save();
  }

  // ── Journal integration ────────────────────────────────────────────────────

  /// Extract and save homework from AI reply.
  /// Looks for `[ÖDEV: description]` or `[HOMEWORK: description]` markers.
  HomeworkItem? extractHomework(String aiReply, String currentTopic) {
    final pattern = RegExp(r'\[ÖDEV:\s*(.+?)\]|\[HOMEWORK:\s*(.+?)\]');
    final match = pattern.firstMatch(aiReply);
    if (match == null) return null;

    final desc = (match.group(1) ?? match.group(2) ?? '').trim();
    if (desc.isEmpty) return null;

    return HomeworkItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: currentTopic,
      description: desc,
      assignedAt: DateTime.now(),
    );
  }

  // ── Greetings & context ────────────────────────────────────────────────────

  /// Returns the return greeting for the teacher to use.
  String? getReturnGreeting(TeacherIdentity teacher) {
    if (!_data.hasReturnContent) return null;

    final diff = DateTime.now().difference(_data.lastSessionDate!);
    final timeStr = diff.inMinutes < 60
        ? 'az önce'
        : diff.inHours < 24
            ? '${diff.inHours} saat önce'
            : '${diff.inDays} gün önce';

    final lastTopic =
        _data.lastTopics.isNotEmpty ? _data.lastTopics.first : null;
    final unfinished = _data.unfinishedTopic;

    if (unfinished != null) {
      return '${teacher.teacherName}: $timeStr "$unfinished" konusunda kalmıştık. '
          'Devam edelim mi?';
    }
    if (lastTopic != null) {
      return '${teacher.teacherName}: Geçen seferden devam ediyoruz. '
          'En son "$lastTopic" üzerinde çalışmıştık.';
    }
    return null;
  }

  // ── Prompt block ───────────────────────────────────────────────────────────

  /// Full continuity context block for Claude system prompt.
  String buildContinuityPrompt() {
    if (!_data.hasReturnContent) return '';

    final sb = StringBuffer();
    sb.writeln('\n[DERS SÜREKLİLİĞİ]');

    if (_data.lastTopics.isNotEmpty) {
      sb.writeln(
          'Son işlenen konular: ${_data.lastTopics.take(5).join(", ")}');
    }

    if (_data.unfinishedTopic != null) {
      sb.writeln(
          'Yarım kalan ders: ${_data.unfinishedTopic} — buradan devam et.');
    }

    final problematic = _data.mostProblematicTopic;
    if (problematic.isNotEmpty) {
      sb.writeln(
          'En çok hata yapılan konu: $problematic (${_data.repeatedMistakes[problematic]} hata) '
          '— bu konuya dikkat et.');
    }

    if (_data.avgConfidence < 0.4) {
      sb.writeln(
          'Güven trendi: düşük. Öğrenci son zamanlarda zorlanıyor — teşvik edici ol.');
    } else if (_data.avgConfidence > 0.75) {
      sb.writeln(
          'Güven trendi: yüksek. Öğrenci iyi gidiyor — zorluk seviyesini artırabilirsin.');
    }

    if (_data.previousExamples.isNotEmpty) {
      sb.writeln(
          'Daha önce verilen örnekler (tekrarlama): '
          '${_data.previousExamples.take(5).join(", ")}');
    }

    if (_data.lastSessionSummary != null) {
      sb.writeln('Son ders özeti: ${_data.lastSessionSummary}');
    }

    sb.writeln(
        'ÖNEMLİ: Öğrenci geri döndüğünde doğal olarak devam et — '
        '"Geçen seferden devam ediyoruz" ile konuya bağlan. '
        'Bitmemiş konuları önce tamamla.');

    return sb.toString();
  }
}
