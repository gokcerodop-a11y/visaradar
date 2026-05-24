import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/lesson_mode.dart';
import '../models/speech_tag.dart';
import '../models/teacher_identity.dart';
import 'anthropic_service.dart';
import 'human_pacing_engine.dart';
import 'teacher_voice_service.dart';
import 'voice_command_detector.dart';

// ── Teaching live states ──────────────────────────────────────────────────────

enum TeacherLiveState {
  idle,
  listening,
  thinking,
  explaining,  // active speech delivery
  drawing,     // board sync moment
  waiting,     // after question, expecting response
  encouraging, // lifting student up
  correcting,  // gentle error mode
}

// ── Session events ────────────────────────────────────────────────────────────

sealed class TeacherSessionEvent {}

class TeacherStateChanged extends TeacherSessionEvent {
  final TeacherLiveState state;
  TeacherStateChanged(this.state);
}

class SentenceStarted extends TeacherSessionEvent {
  final TaggedSentence sentence;
  SentenceStarted(this.sentence);
}

class SentenceCompleted extends TeacherSessionEvent {
  final TaggedSentence sentence;
  SentenceCompleted(this.sentence);
}

class BoardSyncTriggered extends TeacherSessionEvent {
  BoardSyncTriggered();
}

class SessionInterrupted extends TeacherSessionEvent {
  final VoiceCommand? reason;
  final String contextualReply; // what teacher says after interrupt
  SessionInterrupted({this.reason, required this.contextualReply});
}

class VoiceCommandApplied extends TeacherSessionEvent {
  final VoiceCommand command;
  VoiceCommandApplied(this.command);
}

class SessionCompleted extends TeacherSessionEvent {
  SessionCompleted();
}

// ── StreamingTeacherSession ───────────────────────────────────────────────────
//
// Orchestrates one complete teacher response:
//   1. Claude SSE streaming → sentence accumulation
//   2. Per-sentence: SpeechTag parsing → HumanPacing → TTS enqueue
//   3. Emits events for UI (state machine, subtitles, board sync)
//   4. Handles interruptions and voice commands at any point
//
// Future hooks:
//   - ElevenLabs realtime WebSocket: swap TeacherVoiceService with ElevenLabsStream
//   - Avatar face: consume SentenceStarted events with SSML
//   - Multiplayer: broadcast events to classroom participants

class StreamingTeacherSession {
  final AnthropicService _anthropic;
  final TeacherVoiceService _voice;
  final TeacherIdentity _identity;

  late final HumanPacingEngine _pacing;

  // Event stream (broadcast — multiple listeners OK)
  final _eventCtrl = StreamController<TeacherSessionEvent>.broadcast();
  Stream<TeacherSessionEvent> get events => _eventCtrl.stream;

  // State
  TeacherLiveState _state = TeacherLiveState.idle;
  bool _interrupted = false;
  bool _disposed = false;

  // Accumulated text (for board sync and history)
  final _fullReplyBuffer = StringBuffer();
  String get fullReply => _fullReplyBuffer.toString();

  // Sentence-level streaming
  final _streamBuf = StringBuffer();
  static final _sentenceEnd =
      RegExp(r'(?<=[.!?…])\s+(?=\p{Lu}|\p{L})', unicode: true);

  // Voice state
  bool _voiceAvailable = false;
  int _ttsIdx = 0;
  final _pendingTts = <_TtsItem>[];
  bool _ttsRunning = false;

  StreamingTeacherSession({
    required AnthropicService anthropic,
    required TeacherVoiceService voice,
    required TeacherIdentity identity,
    required LessonMode lessonMode,
    double emotionalSpeedModifier = 1.0,
  })  : _anthropic = anthropic,
        _voice = voice,
        _identity = identity {
    _voiceAvailable = voice.isAvailable;
    _pacing = HumanPacingEngine.fromIdentity(
      identity,
      emotionalModifier: emotionalSpeedModifier,
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  TeacherLiveState get state => _state;

  /// Begin explaining. Streams Claude response sentence by sentence.
  Future<void> explain({
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
    int maxTokens = 2048,
  }) async {
    if (_disposed) return;

    _setState(TeacherLiveState.thinking);

    bool firstToken = true;

    try {
      await for (final token in _anthropic.streamMessage(
        history,
        systemPrompt: systemPrompt + SpeechTagParser.systemPromptBlock,
        maxTokens: maxTokens,
      )) {
        if (_interrupted || _disposed) break;

        if (firstToken) {
          _setState(TeacherLiveState.explaining);
          firstToken = false;
        }

        _fullReplyBuffer.write(token);
        _streamBuf.write(token);
        _flushSentences(isLast: false);
      }
    } catch (e) {
      debugPrint('[Session] Stream error: $e');
    }

    if (!_interrupted && !_disposed) {
      // Flush any remaining text as final sentence
      final rem = _streamBuf.toString().trim();
      if (rem.isNotEmpty) {
        await _deliverSentence(SpeechTagParser.parse(rem), isLast: true);
      }
      _streamBuf.clear();

      // Wait for all TTS to finish
      await _waitForTtsDrain();

      if (!_interrupted) {
        _setState(TeacherLiveState.idle);
        _emit(SessionCompleted());
      }
    }
  }

  /// Interrupt the session (student spoke or tapped orb).
  Future<void> interrupt({VoiceCommand? reason}) async {
    if (_interrupted || _disposed) return;
    _interrupted = true;

    // Stop TTS immediately
    await _voice.stop();
    _pendingTts.clear();
    _ttsRunning = false;

    final reply = reason != null
        ? reason.acknowledgement
        : _identity.phrases.checkIns.first;

    _setState(TeacherLiveState.idle);
    _emit(SessionInterrupted(reason: reason, contextualReply: reply));
  }

  /// Apply a voice command without full interruption.
  void applyVoiceCommand(VoiceCommand command) {
    _emit(VoiceCommandApplied(command));
    debugPrint('[Session] Voice command: ${command.name}');
  }

  Future<void> dispose() async {
    _disposed = true;
    await _voice.stop();
    _eventCtrl.close();
  }

  // ── Sentence delivery pipeline ─────────────────────────────────────────────

  void _flushSentences({required bool isLast}) {
    final text = _streamBuf.toString();
    final parts = text.split(_sentenceEnd);
    if (parts.length < 2 && !isLast) return;

    for (int i = 0; i < parts.length - 1; i++) {
      final raw = parts[i].trim();
      if (raw.isNotEmpty) {
        final tagged = SpeechTagParser.parse(raw);
        _enqueueTts(tagged, isLast: false);
      }
    }
    _streamBuf.clear();
    _streamBuf.write(parts.last);
  }

  Future<void> _deliverSentence(TaggedSentence sentence,
      {required bool isLast}) async {
    _enqueueTts(sentence, isLast: isLast);
  }

  void _enqueueTts(TaggedSentence sentence, {required bool isLast}) {
    if (_interrupted || _disposed || sentence.displayText.isEmpty) return;

    if (sentence.triggersBoardSync) {
      _emit(BoardSyncTriggered());
    }

    final item = _TtsItem(
      sentence: sentence,
      idx: _ttsIdx++,
      isLast: isLast,
      prePause: _pacing.prePause(sentence),
      postPause: _pacing.postPause(sentence, isLast: isLast),
    );

    _pendingTts.add(item);
    _emit(SentenceStarted(sentence));

    if (!_ttsRunning) _drainTts();
  }

  void _drainTts() async {
    _ttsRunning = true;
    while (_pendingTts.isNotEmpty && !_interrupted && !_disposed) {
      final item = _pendingTts.removeAt(0);

      // Pre-pause (before speaking)
      if (item.prePause.inMilliseconds > 0) {
        await Future.delayed(item.prePause);
        if (_interrupted || _disposed) break;
      }

      // Generate + play TTS
      if (_voiceAvailable) {
        final path = await _voice.generate(
          item.sentence.displayText,
          stepIndex: item.idx,
        );
        if (path != null && !_interrupted && !_disposed) {
          final completer = Completer<void>();
          await _voice.play(path, onComplete: completer.complete);
          await completer.future;
        }
      }

      if (_interrupted || _disposed) break;

      _emit(SentenceCompleted(item.sentence));

      // Update state based on tag
      if (item.sentence.primaryTag == SpeechTag.question) {
        _setState(TeacherLiveState.waiting);
      } else if (item.sentence.primaryTag == SpeechTag.gentle) {
        _setState(TeacherLiveState.encouraging);
      } else {
        _setState(TeacherLiveState.explaining);
      }

      // Post-pause (natural breath)
      if (item.postPause.inMilliseconds > 0 && _pendingTts.isNotEmpty) {
        await Future.delayed(item.postPause);
      }
    }
    _ttsRunning = false;
  }

  Future<void> _waitForTtsDrain() async {
    for (int i = 0; i < 200 && (_ttsRunning || _pendingTts.isNotEmpty); i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_interrupted || _disposed) break;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setState(TeacherLiveState s) {
    if (_state == s || _disposed) return;
    _state = s;
    _emit(TeacherStateChanged(s));
  }

  void _emit(TeacherSessionEvent event) {
    if (!_eventCtrl.isClosed) _eventCtrl.add(event);
  }

  // ── Static: build system prompt suffix ────────────────────────────────────

  /// Appends human-pacing instructions to the system prompt.
  static String buildPacingPromptBlock(TeacherIdentity identity) {
    final speed = switch (identity.pacingProfile) {
      PacingProfile.slow   => 'Yavaş tempo: her adımdan sonra dur, kısa cümleler yaz.',
      PacingProfile.normal => 'Normal tempo: dengeli cümleler, doğal akış.',
      PacingProfile.fast   => 'Hızlı tempo: verimli, özlü cümleler. Gereksiz tekrar yok.',
    };
    return '''

[ÖĞRETMEN KONUŞMA TEMPİ]
$speed
Yanıtları konuşma diline yakın yaz — sesli okunduğunda doğal çıkmalı.
Çok uzun cümlelerden kaç. Kritik noktalarda kısa dur.
Soru sorduktan sonra bir satır boşluk bırak.
''';
  }

  // ── Future hooks ───────────────────────────────────────────────────────────
  // TODO(future): ElevenLabs realtime WebSocket
  //   Replace _voice.generate() + _voice.play() with:
  //   Stream<Uint8List> elevenLabsStream = await ElevenLabsClient.stream(
  //     text: sentence.rawText,  // includes SSML/tags
  //     voiceId: identity.elevenLabsVoiceId,
  //   );
  //
  // TODO(future): Avatar face sync
  //   On SentenceStarted: feed phoneme data to avatar controller
  //   avatar.startLipSync(sentence.rawText, duration: estimatedDuration)
  //
  // TODO(future): Multiplayer classroom
  //   Broadcast TeacherSessionEvent to WebSocket room
  //   Other students receive real-time teacher stream
}

// ── Internal TTS queue item ───────────────────────────────────────────────────

class _TtsItem {
  final TaggedSentence sentence;
  final int idx;
  final bool isLast;
  final Duration prePause;
  final Duration postPause;

  const _TtsItem({
    required this.sentence,
    required this.idx,
    required this.isLast,
    required this.prePause,
    required this.postPause,
  });
}
