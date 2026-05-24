import 'dart:async';

import 'package:flutter/foundation.dart';

import 'teacher_voice_service.dart';

// ── Voice backend abstraction (ElevenLabs-ready) ──────────────────────────────

enum VoiceBackend { none, localTts, elevenLabs }

// ── Queue item ────────────────────────────────────────────────────────────────

class _QueueItem {
  final String text;
  String? filePath;
  bool generated = false;
  bool failed = false;
  _QueueItem(this.text);
}

// ── VoicePlaybackQueue ────────────────────────────────────────────────────────
//
// Accepts text sentences, pre-generates TTS audio (pipeline), and plays them
// sequentially with configurable natural inter-sentence pauses.
// Backend-agnostic — currently wraps TeacherVoiceService (macOS say).

class VoicePlaybackQueue {
  final TeacherVoiceService _voice;
  final Duration interSentencePause;

  final _pending = <_QueueItem>[];
  bool _draining = false;
  bool _stopped = false;
  int _genIdx = 0;

  // Fired when the queue has drained completely (all sentences played).
  final _doneCtrl = StreamController<void>.broadcast();
  Stream<void> get onDrained => _doneCtrl.stream;

  VoicePlaybackQueue({
    required TeacherVoiceService voice,
    this.interSentencePause = const Duration(milliseconds: 300),
  }) : _voice = voice;

  VoiceBackend get backend =>
      _voice.isAvailable ? VoiceBackend.localTts : VoiceBackend.none;

  bool get isAvailable => _voice.isAvailable;
  bool get isActive => _draining || _pending.isNotEmpty;

  /// Enqueue a sentence for TTS generation + playback.
  void enqueue(String sentence) {
    if (_stopped || sentence.trim().isEmpty) return;
    final item = _QueueItem(sentence);
    _pending.add(item);
    _startGeneration(item);
    if (!_draining) _drain();
  }

  /// Stop playback immediately and clear the queue.
  Future<void> stop() async {
    _stopped = true;
    _pending.clear();
    _draining = false;
    await _voice.stop();
  }

  /// Reset to ready state (after stop, before reuse).
  void reset() {
    _stopped = false;
    _pending.clear();
    _draining = false;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _startGeneration(_QueueItem item) async {
    if (_stopped) return;
    final idx = _genIdx++;
    debugPrint('[Queue] Generating idx=$idx "${item.text.substring(0, item.text.length.clamp(0, 40))}…"');
    item.filePath = await _voice.generate(item.text, stepIndex: idx);
    item.generated = true;
    if (item.filePath == null) item.failed = true;
  }

  void _drain() async {
    _draining = true;

    while (_pending.isNotEmpty && !_stopped) {
      final item = _pending.first;

      // Wait for generation (poll, max ~8s)
      for (int i = 0; i < 80 && !item.generated && !_stopped; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (_stopped) break;

      _pending.removeAt(0);

      if (item.failed || item.filePath == null) {
        // Generation failed — skip and continue
        debugPrint('[Queue] Skipping failed item: ${item.text}');
        continue;
      }

      // Play the sentence
      final completer = Completer<void>();
      await _voice.play(item.filePath!, onComplete: completer.complete);
      await completer.future;

      if (_stopped) break;

      // Natural inter-sentence pause
      if (_pending.isNotEmpty && !_stopped) {
        await Future.delayed(interSentencePause);
      }
    }

    _draining = false;
    if (!_stopped && !_doneCtrl.isClosed) {
      _doneCtrl.add(null);
    }
  }

  Future<void> pause() => _voice.pause();
  Future<void> resume() => _voice.resume();

  void dispose() {
    _stopped = true;
    _doneCtrl.close();
    _voice.dispose();
  }
}
