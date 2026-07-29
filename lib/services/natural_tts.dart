// natural_tts.dart
// ElevenLabs doğal ses: worker /v1/tts'ten mp3 alır, audioplayers ile çalar.
// Başarısız olursa (anahtar yok / ağ / hata) false döner → çağıran sessiz kalır.
// Aynı metin için statik bellek cache — ElevenLabs'a gereksiz tekrar istek atmaz.

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';

class NaturalTts {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _sub;
  Completer<void>? _completer;
  bool _playing = false;

  /// Generation counter: bumped on every speak()/stop(). If the counter has
  /// moved on by the time the HTTP response arrives, the user cancelled or a
  /// newer request superseded this one — skip playback.
  int _generation = 0;

  /// Session-scoped TTS audio cache keyed by normalised text.
  /// Capped at 5 entries to bound memory; LRU approximated by insert order.
  static final Map<String, Uint8List> _cache = {};
  static const int _cacheMax = 5;

  bool get isPlaying => _playing;

  static String _cacheKey(String text) {
    // Normalise: trim + collapse whitespace; truncate to 1000 chars max.
    final normalised = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalised.length > 1000 ? normalised.substring(0, 1000) : normalised;
  }

  Future<bool> speak(
    String text, {
    required String baseUrl,
    required String token,
  }) async {
    if (token.isEmpty || text.trim().isEmpty) return false;
    _generation++;
    final gen = _generation;

    // ── Check cache first ────────────────────────────────────────────────────
    final key = _cacheKey(text);
    final cached = _cache[key];
    if (cached != null) {
      if (gen != _generation) return false;
      try {
        await stop();
        _completer = Completer<void>();
        _playing = true;
        _sub = _player.onPlayerComplete.listen((_) => _finish());
        await _player.play(BytesSource(cached, mimeType: 'audio/mpeg'));
        await _completer!.future;
        return true;
      } catch (e) {
        debugPrint('[NaturalTts] cache-hit: $e');
        _finish();
        return false;
      }
    }

    // ── Fetch from Worker ────────────────────────────────────────────────────
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/v1/tts'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'text': text, 'context': {'kvkkConsent': AppConstants.kvkkConsentGranted}}),
          )
          .timeout(const Duration(seconds: 30));
      if (gen != _generation) return false; // kullanıcı durdurdu
      if (resp.statusCode != 200) return false;
      final bytes = resp.bodyBytes;
      if (bytes.length < 256) return false;
      if (gen != _generation) return false; // tekrar kontrol

      // Store in cache — evict oldest entry if cap reached.
      if (bytes.length < 5 * 1024 * 1024) { // yalnızca <5 MB dosyaları cache'le
        if (_cache.length >= _cacheMax) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = bytes;
      }

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
    _generation++; // bekleyen speak() yanıtlarını geçersiz kıl
    try {
      await _player.stop();
    } catch (_) {}
    _finish();
  }

  void dispose() {
    _generation++;
    _finish();
    _player.dispose();
  }
}
