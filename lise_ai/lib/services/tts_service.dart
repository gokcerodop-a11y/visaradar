import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OpenAI TTS wrapper for lesson board voice narration.
/// Generates MP3 audio per step, caches to temp files, plays with speed control.
class TtsService {
  final String apiKey;

  static const _url  = 'https://api.openai.com/v1/audio/speech';
  static const _model = 'tts-1';        // fast, low-latency
  static const _voice = 'nova';         // works well for Turkish

  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  bool _isPlaying = false;
  double _playbackRate = 1.0;

  TtsService(this.apiKey);

  bool get isPlaying => _isPlaying;

  /// Generate TTS audio for [text], save to a temp file keyed by [stepIndex].
  /// Returns the file path on success, null on failure.
  Future<String?> generateAudio(String text, {required int stepIndex}) async {
    try {
      debugPrint('[TTS] Generating step $stepIndex (${text.length} chars)');
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'input': text,
          'voice': _voice,
          'speed': 1.0,
          'response_format': 'mp3',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[TTS] API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final file = File(
          '${Directory.systemTemp.path}/lise_ai_tts_$stepIndex.mp3');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      debugPrint('[TTS] Step $stepIndex ready (${response.bodyBytes.length} bytes)');
      return file.path;
    } catch (e) {
      debugPrint('[TTS] Generate failed: $e');
      return null;
    }
  }

  /// Play audio file at [filePath].
  /// [onComplete] fires when playback ends naturally (not on stop/pause).
  Future<void> play(String filePath, {VoidCallback? onComplete}) async {
    await _stopInternal();

    _player = AudioPlayer();
    _isPlaying = true;

    _completeSub = _player!.onPlayerComplete.listen((_) {
      _isPlaying = false;
      onComplete?.call();
    });

    await _player!.play(DeviceFileSource(filePath));
    // Apply playback rate after starting
    if (_playbackRate != 1.0) {
      await _player!.setPlaybackRate(_playbackRate);
    }
  }

  Future<void> pause() async {
    if (_player == null) return;
    await _player!.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (_player == null) return;
    await _player!.resume();
    _isPlaying = true;
  }

  /// Stop and clear current player without triggering onComplete.
  Future<void> stop() async => _stopInternal();

  Future<void> _stopInternal() async {
    _completeSub?.cancel();
    _completeSub = null;
    final p = _player;
    _player = null;
    _isPlaying = false;
    if (p != null) {
      await p.stop();
      p.dispose();
    }
  }

  /// Change playback rate (0.75 = slow, 1.0 = normal, 1.25 = fast).
  /// Takes effect immediately if audio is playing.
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    await _player?.setPlaybackRate(rate);
  }

  void dispose() {
    _completeSub?.cancel();
    _player?.dispose();
    _player = null;
  }
}
