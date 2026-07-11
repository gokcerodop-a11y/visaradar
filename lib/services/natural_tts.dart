// natural_tts.dart
// ElevenLabs doğal ses: worker /v1/tts'ten mp3 alır, audioplayers ile çalar.
// Başarısız olursa (anahtar yok / ağ / hata) false döner → çağıran sessiz kalır.

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NaturalTts {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _sub;
  Completer<void>? _completer;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<bool> speak(
    String text, {
    required String baseUrl,
    required String token,
  }) async {
    if (token.isEmpty || text.trim().isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/v1/tts'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return false;
      final bytes = resp.bodyBytes;
      if (bytes.length < 256) return false;

      await stop();
      _completer = Completer<void>();
      _playing = true;
      _sub = _player.onPlayerComplete.listen((_) => _finish());
      await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      await _completer!.future;
      return true;
    } catch (e) {
      debugPrint('[NaturalTts] $e');
      _finish();
      return false;
    }
  }

  void _finish() {
    _playing = false;
    _sub?.cancel();
    _sub = null;
    if (_completer != null && !_completer!.isCompleted) _completer!.complete();
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _finish();
  }

  void dispose() {
    _sub?.cancel();
    _player.dispose();
  }
}
