import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a synthetic chalk/marker scratch sound on each whiteboard stroke.
/// Generates the WAV programmatically — no asset files required.
class ChalkSoundService {
  static File? _wavFile;
  bool muted = false;

  /// Call once at startup. Safe to call multiple times.
  Future<void> init() async {
    if (_wavFile != null) return;
    try {
      final bytes = _buildChalkWav();
      final f = File('${Directory.systemTemp.path}/lise_ai_chalk.wav');
      await f.writeAsBytes(bytes, flush: true);
      _wavFile = f;
      debugPrint('[Sound] Chalk WAV ready: ${f.path}');
    } catch (e) {
      debugPrint('[Sound] Init failed: $e');
    }
  }

  /// Fire-and-forget: plays one chalk stroke sound if not muted.
  void playStroke() {
    if (muted || _wavFile == null) return;
    unawaited(_playOnce());
  }

  Future<void> _playOnce() async {
    try {
      final player = AudioPlayer();
      await player.play(DeviceFileSource(_wavFile!.path));
      await player.onPlayerComplete.first;
      player.dispose();
    } catch (_) {}
  }

  /// 85ms white-noise burst with exponential decay — sounds like chalk.
  static Uint8List _buildChalkWav() {
    const sr = 22050;
    const n = (sr * 85) ~/ 1000; // ~1875 samples
    final rng = math.Random(1337);

    final buf = ByteData(44 + n * 2);
    _setAscii(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + n * 2, Endian.little);
    _setAscii(buf, 8, 'WAVE');
    _setAscii(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little); // PCM
    buf.setUint16(22, 1, Endian.little); // mono
    buf.setUint32(24, sr, Endian.little);
    buf.setUint32(28, sr * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    _setAscii(buf, 36, 'data');
    buf.setUint32(40, n * 2, Endian.little);

    for (int i = 0; i < n; i++) {
      final t = i / n;
      final attack = (t / 0.07).clamp(0.0, 1.0);
      final decay = math.exp(-t * 11.0);
      final env = attack * decay;
      final noise = rng.nextDouble() * 2.0 - 1.0;
      final s = (noise * env * 26000).clamp(-32768.0, 32767.0).toInt();
      buf.setInt16(44 + i * 2, s, Endian.little);
    }
    return buf.buffer.asUint8List();
  }

  static void _setAscii(ByteData b, int off, String s) {
    for (int i = 0; i < s.length; i++) b.setUint8(off + i, s.codeUnitAt(i));
  }
}
