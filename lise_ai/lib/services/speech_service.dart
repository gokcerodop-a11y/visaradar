import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// STT backend modes. Add more as integrations grow.
enum SttMode { none, appleSpeech, whisper, elevenLabs }

/// Speech-to-text abstraction for voice input.
/// Currently wraps Apple SFSpeechRecognizer via speech_to_text on macOS.
/// Future modes: whisper, elevenLabs.
class SpeechService {
  final SttMode mode;
  final SpeechToText _stt;

  bool _isListening = false;

  SpeechService._(this.mode, this._stt);

  bool get isAvailable => mode != SttMode.none;
  bool get isListening => _isListening;

  /// Detect the best available STT backend and return a configured service.
  static Future<SpeechService> create() async {
    final stt = SpeechToText();
    try {
      final available = await stt.initialize(
        onError: (e) => debugPrint('[STT] error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('[STT] status: $s'),
      );
      if (available) {
        debugPrint('[STT] Apple Speech available');
        return SpeechService._(SttMode.appleSpeech, stt);
      }
    } catch (e) {
      debugPrint('[STT] init failed: $e');
    }
    debugPrint('[STT] No STT backend available');
    return SpeechService._(SttMode.none, stt);
  }

  /// Start listening. [onResult] fires on every interim and final result.
  /// [onDone] fires when recognition stops (auto-silence or manual stop).
  /// Returns true if listening started successfully.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    String locale = 'tr_TR',
  }) async {
    if (!isAvailable || _isListening) return false;
    _isListening = true;
    try {
      await _stt.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
            onDone();
          }
        },
        localeId: locale,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 60),
        listenMode: ListenMode.dictation,
        partialResults: true,
      );
      return true;
    } catch (e) {
      debugPrint('[STT] startListening failed: $e');
      _isListening = false;
      return false;
    }
  }

  /// Stop listening manually.
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _stt.stop();
  }

  void dispose() {
    _stt.cancel();
  }
}
