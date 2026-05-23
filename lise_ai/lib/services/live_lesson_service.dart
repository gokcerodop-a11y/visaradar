import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/lesson_mode.dart';
import '../models/student_profile.dart';
import '../services/anthropic_service.dart';
import '../services/profile_service.dart';
import '../services/speech_service.dart';
import '../services/teacher_engine.dart';
import '../services/teacher_voice_service.dart';

// ── Teacher state ─────────────────────────────────────────────────────────────

enum LiveTeacherState {
  dinliyor,        // listening to student
  dusunuyor,       // thinking (API call)
  acikliyor,       // explaining (streaming / TTS)
  tahtayaGeciyor,  // transitioning to board
  soruSoruyor,     // asking a question
  bekliyor,        // idle
}

extension LiveTeacherStateExt on LiveTeacherState {
  String get label => switch (this) {
        LiveTeacherState.dinliyor        => 'Dinliyor',
        LiveTeacherState.dusunuyor       => 'Düşünüyor',
        LiveTeacherState.acikliyor       => 'Açıklıyor',
        LiveTeacherState.tahtayaGeciyor  => 'Tahtaya Geçiyor',
        LiveTeacherState.soruSoruyor     => 'Soru Soruyor',
        LiveTeacherState.bekliyor        => 'Bekliyor',
      };
}

// ── Session events ─────────────────────────────────────────────────────────────

sealed class LiveSessionEvent {}

class TeacherStateEvent extends LiveSessionEvent {
  final LiveTeacherState state;
  TeacherStateEvent(this.state);
}

class UserTranscriptEvent extends LiveSessionEvent {
  final String text;
  final bool isFinal;
  UserTranscriptEvent(this.text, this.isFinal);
}

class TeacherChunkEvent extends LiveSessionEvent {
  final String chunk;
  final bool newBubble;
  TeacherChunkEvent(this.chunk, {this.newBubble = false});
}

class TeacherBubbleFinalizedEvent extends LiveSessionEvent {}

class BoardTriggerEvent extends LiveSessionEvent {
  final String question;
  final String reply;
  BoardTriggerEvent(this.question, this.reply);
}

class SessionEndedEvent extends LiveSessionEvent {}

class LiveErrorEvent extends LiveSessionEvent {
  final String message;
  LiveErrorEvent(this.message);
}

// ── Voice backend abstraction (ElevenLabs-ready) ──────────────────────────────

/// Current backend: localTts (macOS say).
/// Future: elevenLabs (real-time streaming synthesis).
enum LiveVoiceBackend { none, localTts, elevenLabs }

// ── Live lesson service ────────────────────────────────────────────────────────

class LiveLessonService {
  final AnthropicService _anthropic;
  final ProfileService _profileSvc;
  final LessonMode _mode;
  final StudentLevel _level;

  late final SpeechService _speech;
  late final TeacherVoiceService _voice;

  // Each live session gets its own engine (no bleed from main chat)
  final _engine = TeacherEngine();

  final _eventCtrl = StreamController<LiveSessionEvent>.broadcast();
  Stream<LiveSessionEvent> get events => _eventCtrl.stream;

  final List<Map<String, dynamic>> _history;
  LiveTeacherState _state = LiveTeacherState.bekliyor;
  bool _active = false;

  // TTS pipeline
  final _ttsQueue = <String>[];
  bool _ttsProcessing = false;
  int _ttsCounter = 0;
  bool _interrupted = false;
  bool _streamCancelled = false;
  final _streamBuf = StringBuffer();

  final LiveVoiceBackend voiceBackend;

  LiveLessonService._({
    required AnthropicService anthropic,
    required ProfileService profileSvc,
    required LessonMode mode,
    required StudentLevel level,
    required List<Map<String, dynamic>> history,
    required this.voiceBackend,
  })  : _anthropic = anthropic,
        _profileSvc = profileSvc,
        _mode = mode,
        _level = level,
        _history = List.from(history);

  static Future<LiveLessonService> create({
    required AnthropicService anthropic,
    required ProfileService profileSvc,
    required LessonMode mode,
    required StudentLevel level,
    required List<Map<String, dynamic>> history,
  }) async {
    final voice = await TeacherVoiceService.create();
    final speech = await SpeechService.create();
    final backend =
        voice.isAvailable ? LiveVoiceBackend.localTts : LiveVoiceBackend.none;

    final svc = LiveLessonService._(
      anthropic: anthropic,
      profileSvc: profileSvc,
      mode: mode,
      level: level,
      history: history,
      voiceBackend: backend,
    );
    svc._voice = voice;
    svc._speech = speech;
    return svc;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
  LiveTeacherState get state => _state;
  bool get isActive => _active;
  bool get hasVoice => voiceBackend != LiveVoiceBackend.none;
  bool get hasSpeech => _speech.isAvailable;

  Future<void> start() async {
    _active = true;
    await _startListening();
  }

  Future<void> sendText(String text) async {
    if (!_active || text.trim().isEmpty) return;
    await _stopListening();
    await _processInput(text.trim(), isVoice: false);
  }

  /// Interrupt teacher mid-explanation; immediately resume listening.
  Future<void> interrupt() async {
    if (!_active) return;
    _interrupted = true;
    _streamCancelled = true;
    await _voice.stop();
    _ttsQueue.clear();
    _ttsProcessing = false;
    _eventCtrl.add(TeacherBubbleFinalizedEvent());
    _setState(LiveTeacherState.dinliyor);
    await _startListening();
  }

  Future<void> endSession() async {
    _active = false;
    await _stopListening();
    await _voice.stop();
    _ttsQueue.clear();
    _eventCtrl.add(SessionEndedEvent());
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_active) return;
    _setState(LiveTeacherState.dinliyor);
    if (!hasSpeech) return;

    final started = await _speech.startListening(
      locale: 'tr_TR',
      onResult: (text, isFinal) {
        if (!_active) return;
        _eventCtrl.add(UserTranscriptEvent(text, isFinal));
        if (isFinal && text.trim().isNotEmpty) {
          _processInput(text.trim(), isVoice: true);
        }
      },
      onDone: () {
        if (_active && _state == LiveTeacherState.dinliyor) {
          _setState(LiveTeacherState.bekliyor);
        }
      },
    );

    if (!started && _active) _setState(LiveTeacherState.bekliyor);
  }

  Future<void> _stopListening() async {
    if (_speech.isListening) await _speech.stopListening();
  }

  // ── Input processing ───────────────────────────────────────────────────────

  Future<void> _processInput(String text, {required bool isVoice}) async {
    if (!_active) return;
    await _stopListening();

    final detectedTopic = TopicDetector.detect(text);
    _engine.analyze(
      history: _history,
      profile: _profileSvc.profile,
      mode: _mode,
      currentTopic: detectedTopic,
    );

    _history.add({'role': 'user', 'content': text});
    _setState(LiveTeacherState.dusunuyor);
    _streamCancelled = false;
    _interrupted = false;
    _streamBuf.clear();

    final accumulator = StringBuffer();
    bool firstChunk = true;
    bool newBubble = true;

    try {
      await for (final token
          in _anthropic.streamMessage(
        _history,
        systemPrompt: _buildLiveSystemPrompt(),
        maxTokens: 420,
      )) {
        if (_streamCancelled || !_active) break;

        if (firstChunk) {
          _setState(_streamBuf.toString().contains('[TAHTA]')
              ? LiveTeacherState.tahtayaGeciyor
              : LiveTeacherState.acikliyor);
          firstChunk = false;
        }

        accumulator.write(token);
        _streamBuf.write(token);

        // Check for structural markers mid-stream
        final buf = _streamBuf.toString();
        if (buf.contains('[TAHTA]') &&
            _state != LiveTeacherState.tahtayaGeciyor) {
          _setState(LiveTeacherState.tahtayaGeciyor);
        }
        if (buf.contains('[SORU]') &&
            _state == LiveTeacherState.acikliyor) {
          _setState(LiveTeacherState.soruSoruyor);
        }

        // Strip markers from display chunk
        final displayToken = token
            .replaceAll('[TAHTA]', '')
            .replaceAll('[SORU]', '');
        if (displayToken.isNotEmpty) {
          _eventCtrl.add(TeacherChunkEvent(displayToken, newBubble: newBubble));
          newBubble = false;
        }

        _flushSentencesToTts();
      }
    } catch (e) {
      if (_active) {
        _history.removeLast();
        _eventCtrl.add(LiveErrorEvent('Bağlantı hatası. Tekrar dene.'));
        _setState(LiveTeacherState.bekliyor);
        return;
      }
    }

    if (_streamCancelled || !_active) return;

    // Flush remaining TTS buffer
    final remaining = _cleanForTts(_streamBuf.toString());
    if (remaining.isNotEmpty) _enqueueTts(remaining);
    _streamBuf.clear();

    final fullReply = accumulator.toString();
    _history.add({'role': 'assistant', 'content': fullReply});
    _engine.onAssistantResponse(fullReply);
    _eventCtrl.add(TeacherBubbleFinalizedEvent());

    // Profile recording
    final topic = detectedTopic ??
        TopicDetector.detect(
            fullReply.substring(0, fullReply.length.clamp(0, 400))) ??
        'Genel';
    final signal = _engine.lastSignal;
    _profileSvc.recordInteraction(InteractionRecord(
      timestamp: DateTime.now(),
      topic: topic,
      mode: 'canliDers',
      usedHints: signal.hasConfusion,
      usedBoard: fullReply.contains('[TAHTA]') || signal.shouldTriggerBoard,
      successEstimate: signal.successEstimate,
    ));

    // Board trigger
    if ((fullReply.contains('[TAHTA]') || signal.shouldTriggerBoard) &&
        _active) {
      _eventCtrl.add(BoardTriggerEvent(text, fullReply));
    }

    // Wait for TTS → then resume listening
    if (!_interrupted && _active) {
      await _waitForTts();
      if (!_interrupted && _active) await _startListening();
    }
  }

  // ── TTS pipeline ───────────────────────────────────────────────────────────

  // Split on sentence boundary (. ! ?) followed by whitespace or end
  static final _sentenceEnd =
      RegExp(r'(?<=[.!?…])\s+(?=\p{L})', unicode: true);

  void _flushSentencesToTts() {
    if (!hasVoice) return;
    final text = _streamBuf.toString();
    final parts = text.split(_sentenceEnd);
    if (parts.length < 2) return;

    for (int i = 0; i < parts.length - 1; i++) {
      final s = _cleanForTts(parts[i].trim());
      if (s.isNotEmpty) _enqueueTts(s);
    }
    _streamBuf.clear();
    _streamBuf.write(parts.last);
  }

  void _enqueueTts(String sentence) {
    if (sentence.isEmpty || !hasVoice || _interrupted) return;
    _ttsQueue.add(sentence);
    if (!_ttsProcessing) _playNextTts();
  }

  void _playNextTts() async {
    if (_ttsQueue.isEmpty || _interrupted) {
      _ttsProcessing = false;
      return;
    }
    _ttsProcessing = true;
    final text = _ttsQueue.removeAt(0);
    final idx = _ttsCounter++;

    final path = await _voice.generate(text, stepIndex: idx);
    if (path == null || _interrupted) {
      _playNextTts();
      return;
    }
    await _voice.play(path, onComplete: () {
      if (!_interrupted) _playNextTts();
    });
  }

  Future<void> _waitForTts() async {
    while ((_ttsProcessing || _voice.isPlaying) &&
        !_interrupted &&
        _active) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  // ── Text utilities ─────────────────────────────────────────────────────────

  String _cleanForTts(String text) => text
      .replaceAll('[TAHTA]', '')
      .replaceAll('[SORU]', '')
      .replaceAll(RegExp(r'\*+'), '')
      .replaceAll(RegExp(r'#+\s*'), '')
      .replaceAll(RegExp(r'`[^`]*`'), '')
      .replaceAll(RegExp(r'\$\$[^\$]*\$\$'), '')
      .replaceAll(RegExp(r'\$[^\$]+\$'), '')
      .trim();

  // ── System prompt ──────────────────────────────────────────────────────────

  static const _liveRules = '''

--- CANLI DERS MODU — Konuşma kuralları (ZORUNLU) ---
Yanıt kısa ve konuşma diline uygun olmalı — sesli okunacak.
Maksimum 3 cümle per yanıt. Uzun liste, tablo, başlık yasak.
Doğal öğretmen geçişleri: "Şimdi bak...", "Dur bir saniye...", "Hım, ilginç...", "Tamam, şöyle düşün:"
Önemli kavram öncesi "—" ile duraklama yap.
Formülleri sesli okunabilir yaz: "x kare artı y kare eşittir r kare"
Tahta gerekiyorsa satıra [TAHTA] yaz. Soru soruyorsan son satır [SORU] olsun.
Önceki açıklamaları tekrar etme — "az önce dediğim gibi..." ile referans ver.
--- CANLI DERS MODU SONU ---
''';

  String _buildLiveSystemPrompt() =>
      AnthropicService.buildSystemPrompt(_mode, _level) +
      _profileSvc.buildMemorySummary() +
      _engine.buildOrchestrationPrompt() +
      _liveRules;

  // ── State helper ───────────────────────────────────────────────────────────

  void _setState(LiveTeacherState s) {
    if (_state == s) return;
    _state = s;
    if (!_eventCtrl.isClosed) _eventCtrl.add(TeacherStateEvent(s));
    debugPrint('[Live] State → ${s.label}');
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _active = false;
    await _stopListening();
    await _voice.stop();
    _voice.dispose();
    _speech.dispose();
    if (!_eventCtrl.isClosed) await _eventCtrl.close();
  }
}
