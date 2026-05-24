import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/lesson_flow.dart';
import '../models/lesson_mode.dart';
import '../models/student_profile.dart';
import '../services/anthropic_service.dart';
import '../services/cognitive_profile_engine.dart';
import '../services/learning_graph_engine.dart';
import '../services/lesson_flow_engine.dart';
import '../services/profile_service.dart';
import '../services/speech_service.dart';
import '../services/teacher_engine.dart';
import '../services/teacher_voice_service.dart';
import '../services/voice_playback_queue.dart';

// ── Conversation state ─────────────────────────────────────────────────────────

enum ConversationState {
  idle,
  listening,
  thinking,
  speaking,
  interrupted,
  paused,
}

extension ConversationStateExt on ConversationState {
  String get label => switch (this) {
        ConversationState.idle        => 'Bekliyor',
        ConversationState.listening   => 'Dinliyor',
        ConversationState.thinking    => 'Düşünüyor',
        ConversationState.speaking    => 'Konuşuyor',
        ConversationState.interrupted => 'Kesildi',
        ConversationState.paused      => 'Duraklatıldı',
      };
}

// ── Events (sealed) ───────────────────────────────────────────────────────────

sealed class RealtimeEvent {}

class StateChangedEvent extends RealtimeEvent {
  final ConversationState state;
  StateChangedEvent(this.state);
}

class TranscriptEvent extends RealtimeEvent {
  final String text;
  final bool isFinal;
  TranscriptEvent(this.text, this.isFinal);
}

class AssistantChunkEvent extends RealtimeEvent {
  final String chunk;
  final bool isNewBubble;
  AssistantChunkEvent(this.chunk, {this.isNewBubble = false});
}

class AssistantFinalizedEvent extends RealtimeEvent {}

class BoardTriggerEvent extends RealtimeEvent {
  final String question;
  final String reply;
  BoardTriggerEvent(this.question, this.reply);
}

class RealtimeErrorEvent extends RealtimeEvent {
  final String message;
  RealtimeErrorEvent(this.message);
}

class SessionEndedEvent extends RealtimeEvent {}

// ── ConversationStateMachine ──────────────────────────────────────────────────

class ConversationStateMachine {
  ConversationState _state = ConversationState.idle;
  final _ctrl = StreamController<ConversationState>.broadcast();

  ConversationState get state => _state;
  Stream<ConversationState> get stream => _ctrl.stream;

  void transition(ConversationState next) {
    if (_state == next) return;
    debugPrint('[CSM] ${_state.label} → ${next.label}');
    _state = next;
    if (!_ctrl.isClosed) _ctrl.add(next);
  }

  void dispose() => _ctrl.close();
}

// ── InterruptionController ────────────────────────────────────────────────────
//
// Monitors the SpeechService during AI speaking.
// Fires onInterrupted when the student begins speaking.

class InterruptionController {
  final SpeechService _speech;
  final VoidCallback onInterrupted;

  bool _active = false;
  bool _fired = false;
  Timer? _cooldownTimer;

  InterruptionController({required SpeechService speech, required this.onInterrupted})
      : _speech = speech;

  /// Begin monitoring. Call shortly after TTS starts.
  void startMonitoring() {
    _active = true;
    _fired = false;
    // Short cooldown so early TTS audio isn't mistaken for student speech.
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(milliseconds: 600), _beginListening);
  }

  void _beginListening() async {
    if (!_active || !_speech.isAvailable) return;
    if (_speech.isListening) return; // already listening

    await _speech.startListening(
      locale: 'tr_TR',
      onResult: (text, isFinal) {
        if (_active && !_fired && text.trim().isNotEmpty) {
          _fired = true;
          _active = false;
          onInterrupted();
        }
      },
      onDone: () {},
    );
  }

  void stopMonitoring() {
    _cooldownTimer?.cancel();
    _active = false;
    if (_speech.isListening) {
      _speech.stopListening();
    }
  }

  void dispose() {
    _cooldownTimer?.cancel();
  }
}

// ── Session context (dependency injection) ────────────────────────────────────

class VoiceSessionContext {
  final AnthropicService anthropic;
  final ProfileService profileSvc;
  final CognitiveProfileEngine cogEngine;
  final StructuredLessonFlowEngine flowEngine;
  final LearningGraphEngine graphEngine;
  final LessonMode mode;
  final StudentLevel level;
  final List<Map<String, dynamic>> history;

  const VoiceSessionContext({
    required this.anthropic,
    required this.profileSvc,
    required this.cogEngine,
    required this.flowEngine,
    required this.graphEngine,
    required this.mode,
    required this.level,
    required this.history,
  });
}

// ── RealtimeVoiceEngine ───────────────────────────────────────────────────────

class RealtimeVoiceEngine {
  final VoiceSessionContext _ctx;

  // Internal components
  late final SpeechService _speech;
  late final VoicePlaybackQueue _queue;
  late final ConversationStateMachine _csm;
  late final InterruptionController _interrupt;
  final _teacherEngine = TeacherEngine();

  // Event bus
  final _eventCtrl = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventCtrl.stream;

  // State
  final List<Map<String, dynamic>> _history;
  bool _active = false;
  bool _streamCancelled = false;
  bool _processingInput = false;
  final _streamBuf = StringBuffer();

  // Pacing
  late final Duration _interSentencePause;

  ConversationState get state => _csm.state;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
  bool get hasVoice => _queue.isAvailable;
  bool get hasSpeech => _speech.isAvailable;
  VoiceBackend get voiceBackend => _queue.backend;

  RealtimeVoiceEngine._(this._ctx)
      : _history = List.from(_ctx.history) {
    _interSentencePause = _pauseForMode(_ctx.mode);
  }

  static Duration _pauseForMode(LessonMode mode) => switch (mode) {
        LessonMode.hizliCevap => const Duration(milliseconds: 80),
        LessonMode.sinavKocu  => const Duration(milliseconds: 100),
        LessonMode.ogretmenGibi => const Duration(milliseconds: 500),
        _ => const Duration(milliseconds: 280),
      };

  // ── Factory ────────────────────────────────────────────────────────────────

  static Future<RealtimeVoiceEngine> create(VoiceSessionContext ctx) async {
    final engine = RealtimeVoiceEngine._(ctx);

    final voice = await TeacherVoiceService.create();
    final speech = await SpeechService.create();

    engine._speech = speech;
    engine._queue = VoicePlaybackQueue(
      voice: voice,
      interSentencePause: engine._interSentencePause,
    );
    engine._csm = ConversationStateMachine();
    engine._interrupt = InterruptionController(
      speech: speech,
      onInterrupted: engine._onInterruptDetected,
    );

    // Queue-drained → resume listening
    engine._queue.onDrained.listen((_) {
      if (engine._active && engine._csm.state == ConversationState.speaking) {
        engine._startListening();
      }
    });

    return engine;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> start() async {
    _active = true;
    await _startListening();
  }

  Future<void> sendText(String text) async {
    if (!_active || text.trim().isEmpty) return;
    await _stopListening();
    _interrupt.stopMonitoring();
    await _processInput(text.trim(), isHighPriority: false);
  }

  /// Hard interrupt: stop TTS + stream, mark interrupted, then re-listen.
  Future<void> interrupt() async {
    if (!_active) return;
    await _doInterrupt();
    await _startListening();
  }

  Future<void> pause() async {
    if (!_active) return;
    _csm.transition(ConversationState.paused);
    await _stopListening();
    await _queue.pause();
  }

  Future<void> resume() async {
    if (_csm.state != ConversationState.paused) return;
    await _queue.resume();
    await _startListening();
  }

  Future<void> endSession() async {
    _active = false;
    _streamCancelled = true;
    await _stopListening();
    _interrupt.stopMonitoring();
    await _queue.stop();
    _csm.transition(ConversationState.idle);
    _emit(SessionEndedEvent());
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_active || _processingInput) return;
    _csm.transition(ConversationState.listening);
    if (!hasSpeech) return;

    await _speech.startListening(
      locale: 'tr_TR',
      onResult: (text, isFinal) {
        if (!_active || _processingInput) return;
        _emit(TranscriptEvent(text, isFinal));
        if (isFinal && text.trim().isNotEmpty) {
          _processInput(text.trim(), isHighPriority: false);
        }
      },
      onDone: () {
        if (_active && _csm.state == ConversationState.listening) {
          _csm.transition(ConversationState.idle);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    if (_speech.isListening) await _speech.stopListening();
  }

  // ── Interruption ───────────────────────────────────────────────────────────

  void _onInterruptDetected() {
    if (!_active) return;
    debugPrint('[Realtime] Interruption detected by InterruptionController');
    _doInterrupt().then((_) => _startListening());
  }

  Future<void> _doInterrupt() async {
    _streamCancelled = true;
    _interrupt.stopMonitoring();
    await _queue.stop();
    _queue.reset();
    _csm.transition(ConversationState.interrupted);
    _emit(AssistantFinalizedEvent());
    // Brief visual flash of interrupted state
    await Future.delayed(const Duration(milliseconds: 350));
  }

  // ── Input processing ───────────────────────────────────────────────────────

  Future<void> _processInput(String text, {required bool isHighPriority}) async {
    if (!_active || _processingInput) return;
    _processingInput = true;

    await _stopListening();
    _streamCancelled = false;

    // Engine analysis
    final detectedTopic = TopicDetector.detect(text);
    _teacherEngine.analyze(
      history: _history,
      profile: _ctx.profileSvc.profile,
      mode: _ctx.mode,
      currentTopic: detectedTopic,
    );

    _history.add({'role': 'user', 'content': text});
    _csm.transition(ConversationState.thinking);

    _streamBuf.clear();
    final accumulated = StringBuffer();
    bool isNewBubble = true;
    bool firstToken = true;

    try {
      await for (final token in _ctx.anthropic.streamMessage(
        _history,
        systemPrompt: _buildSystemPrompt(detectedTopic),
        maxTokens: _ctx.mode == LessonMode.hizliCevap ? 500 : 420,
      )) {
        if (_streamCancelled || !_active) break;

        if (firstToken) {
          _csm.transition(ConversationState.speaking);
          // Start interruption monitoring shortly after first token
          _interrupt.startMonitoring();
          firstToken = false;
        }

        accumulated.write(token);
        _streamBuf.write(token);

        // Strip markers for display
        final display = token
            .replaceAll('[TAHTA]', '')
            .replaceAll('[SORU]', '');
        if (display.isNotEmpty) {
          _emit(AssistantChunkEvent(display, isNewBubble: isNewBubble));
          isNewBubble = false;
        }

        _flushSentencesToQueue();
      }
    } catch (e) {
      if (_active) {
        _history.removeLast();
        _emit(RealtimeErrorEvent('Bağlantı hatası. Tekrar dene.'));
        _processingInput = false;
        await _startListening();
        return;
      }
    }

    if (_streamCancelled || !_active) {
      _processingInput = false;
      return;
    }

    // Flush remaining buffer to TTS
    final remaining = _cleanForTts(_streamBuf.toString());
    if (remaining.isNotEmpty && hasVoice) _queue.enqueue(remaining);
    _streamBuf.clear();

    final fullReply = accumulated.toString();
    _history.add({'role': 'assistant', 'content': fullReply});
    _teacherEngine.onAssistantResponse(fullReply);
    _emit(AssistantFinalizedEvent());

    // Post-processing
    final signal = _teacherEngine.lastSignal;
    final topic = detectedTopic ??
        TopicDetector.detect(fullReply.substring(0, fullReply.length.clamp(0, 400))) ??
        'Genel';

    _ctx.profileSvc.recordInteraction(InteractionRecord(
      timestamp: DateTime.now(),
      topic: topic,
      mode: 'canliDers',
      usedHints: signal.hasConfusion,
      usedBoard: fullReply.contains('[TAHTA]') || signal.shouldTriggerBoard,
      successEstimate: signal.successEstimate,
    ));

    if (topic != 'Genel') {
      _ctx.graphEngine.recordStudy(
        topic: topic,
        successEstimate: signal.successEstimate,
        usedHints: signal.hasConfusion,
      );
    }

    await _ctx.cogEngine.processInteraction(
      userMessage: text,
      assistantReply: fullReply,
      usedBoard: fullReply.contains('[TAHTA]') || signal.shouldTriggerBoard,
      usedHints: signal.hasConfusion,
    );

    await _ctx.flowEngine.advance(
      signal: signal,
      topic: detectedTopic,
      mode: _ctx.mode,
      level: _ctx.level,
      cogProfile: _ctx.cogEngine.profile,
      weakTopics: _ctx.profileSvc.profile.weakTopics,
      graphEngine: _ctx.graphEngine,
    );

    // Board trigger
    if ((fullReply.contains('[TAHTA]') || signal.shouldTriggerBoard) && _active) {
      _emit(BoardTriggerEvent(text, fullReply));
    }

    _processingInput = false;

    // If no voice, resume listening immediately; otherwise wait for queue drain
    if (!hasVoice && _active) {
      await _startListening();
    }
    // Voice path: _queue.onDrained fires → _startListening called automatically
  }

  // ── TTS sentence splitter ──────────────────────────────────────────────────

  static final _sentenceEnd =
      RegExp(r'(?<=[.!?…])\s+(?=\p{L})', unicode: true);

  void _flushSentencesToQueue() {
    if (!hasVoice) return;
    final text = _streamBuf.toString();
    final parts = text.split(_sentenceEnd);
    if (parts.length < 2) return;

    for (int i = 0; i < parts.length - 1; i++) {
      final s = _cleanForTts(parts[i].trim());
      if (s.isNotEmpty) _queue.enqueue(s);
    }
    _streamBuf.clear();
    _streamBuf.write(parts.last);
  }

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

  static const _realtimeRules = '''

--- GERÇEK ZAMANLI KONUŞMA MODU (ZORUNLU) ---
Yanıtlar kısa ve konuşma diline uygun — sesli okunacak.
Maksimum 3 cümle per yanıt. Liste, tablo, başlık yasak.
Formülleri sesli yaz: "x kare artı y kare".
Doğal öğretmen geçişleri kullan.
Tahta gerekiyorsa [TAHTA], soru soruyorsan [SORU] yaz.
--- GERÇEK ZAMANLI MOD SONU ---
''';

  String _buildSystemPrompt(String? topic) =>
      AnthropicService.buildSystemPrompt(_ctx.mode, _ctx.level) +
      _ctx.profileSvc.buildMemorySummary() +
      _teacherEngine.buildOrchestrationPrompt() +
      _ctx.graphEngine.buildContextPrompt(
          currentTopic: topic, mode: _ctx.mode, level: _ctx.level) +
      _ctx.cogEngine.buildProfilePrompt() +
      _ctx.flowEngine.buildFlowPrompt() +
      _realtimeRules;

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _emit(RealtimeEvent event) {
    if (!_eventCtrl.isClosed) _eventCtrl.add(event);
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _active = false;
    _streamCancelled = true;
    _interrupt.dispose();
    await _stopListening();
    await _queue.stop();
    _queue.dispose();
    _csm.dispose();
    _speech.dispose();
    if (!_eventCtrl.isClosed) await _eventCtrl.close();
  }
}
