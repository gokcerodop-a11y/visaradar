import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Voice backend modes. Add more as integrations grow.
enum VoiceMode { none, localTts, elevenLabs }

/// Teacher voice narration service.
/// Currently uses macOS system `say` command for local TTS.
/// Future modes: elevenLabs, openAI.
class TeacherVoiceService {
  final VoiceMode mode;

  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  bool _isPlaying = false;
  double _playbackRate = 1.0;

  TeacherVoiceService._(this.mode);

  bool get isPlaying => _isPlaying;
  bool get isAvailable => mode != VoiceMode.none;

  /// Detect the best available TTS backend and return a configured service.
  static Future<TeacherVoiceService> create() async {
    if (Platform.isMacOS) {
      try {
        final result = await Process.run('which', ['say']);
        if (result.exitCode == 0) {
          debugPrint('[Voice] Local TTS available (macOS say)');
          return TeacherVoiceService._(VoiceMode.localTts);
        }
      } catch (_) {}
    }
    debugPrint('[Voice] No TTS backend available');
    return TeacherVoiceService._(VoiceMode.none);
  }

  /// Generate audio for [text], save to a temp file keyed by [stepIndex].
  /// Returns the file path on success, null on failure or if unavailable.
  Future<String?> generate(String text, {required int stepIndex}) async {
    if (mode == VoiceMode.none) return null;
    try {
      debugPrint('[Voice] Generating step $stepIndex (${text.length} chars)');
      final path =
          '${Directory.systemTemp.path}/lise_ai_voice_$stepIndex.aiff';
      final result = await Process.run('say', ['-o', path, text])
          .timeout(const Duration(seconds: 60));
      if (result.exitCode != 0) {
        debugPrint('[Voice] say stderr: ${result.stderr}');
        return null;
      }
      final size = await File(path).length();
      debugPrint('[Voice] Step $stepIndex ready ($size bytes)');
      return path;
    } catch (e) {
      debugPrint('[Voice] Generate failed: $e');
      return null;
    }
  }

  /// Play audio at [filePath]. [onComplete] fires when playback ends naturally.
  Future<void> play(String filePath, {VoidCallback? onComplete}) async {
    await _stopInternal();
    _player = AudioPlayer();
    _isPlaying = true;

    _completeSub = _player!.onPlayerComplete.listen((_) {
      _isPlaying = false;
      onComplete?.call();
    });

    await _player!.play(DeviceFileSource(filePath));
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

  /// Adjust playback speed (0.75 = slow, 1.0 = normal, 1.25 = fast).
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
