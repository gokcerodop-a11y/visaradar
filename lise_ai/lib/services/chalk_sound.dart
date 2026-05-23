import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays soft chalk scratch sounds during board drawing.
/// Sound is OFF by default — harsh click sounds are disabled entirely.
/// When enabled, plays a quiet sustained scratch (no per-point clicks).
class ChalkSoundService {
  static final List<File?> _wavFiles = [null, null, null];
  static bool _initialized = false;

  bool muted = true; // Always off by default

  final _rng = math.Random();

  /// Call once at startup. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Three soft sustained scratch variants — different seeds for variety
      const seeds = [1337, 5003, 9871];
      const durationMs = [280, 340, 260]; // longer = more continuous feel
      for (int i = 0; i < 3; i++) {
        final bytes = _buildScratchWav(seed: seeds[i], durationMs: durationMs[i]);
        final f = File('${Directory.systemTemp.path}/lise_ai_chalk_$i.wav');
        await f.writeAsBytes(bytes, flush: true);
        _wavFiles[i] = f;
      }
      debugPrint('[Sound] Chalk WAVs ready (3 variants, muted by default)');
    } catch (e) {
      debugPrint('[Sound] Init failed: $e');
    }
  }

  /// Play a soft chalk scratch sound (only if user explicitly enabled).
  /// Never plays per-point clicks — only soft continuous scratches.
  void playStroke() {
    if (muted) return;
    final i = _rng.nextInt(3);
    final f = _wavFiles[i];
    if (f == null) return;
    unawaited(_playFile(f));
  }

  // No playDot() — per-point click sounds are removed entirely.

  Future<void> _playFile(File f) async {
    try {
      final player = AudioPlayer();
      await player.play(DeviceFileSource(f.path));
      await player.onPlayerComplete.first;
      player.dispose();
    } catch (_) {}
  }

  /// Build a soft chalk scratch WAV.
  /// Uses filtered noise with a trapezoid (no click) envelope.
  static Uint8List _buildScratchWav({
    required int seed,
    int durationMs = 300,
  }) {
    const sr = 22050;
    const amplitude = 0.06; // very soft — ~6% of max
    final n = (sr * durationMs) ~/ 1000;
    final rng = math.Random(seed);

    final buf = ByteData(44 + n * 2);
    _writeWavHeader(buf, sr, n);

    // Simple first-order low-pass filter state
    double prev = 0;
    const lpAlpha = 0.25; // smoothing factor — reduces harshness

    for (int i = 0; i < n; i++) {
      final t = i / n;

      // Trapezoid envelope: 10% rise → 80% flat → 10% fall — NO click
      final rise  = (t / 0.10).clamp(0.0, 1.0);
      final fall  = ((1.0 - t) / 0.10).clamp(0.0, 1.0);
      final env   = math.min(rise, fall);

      // White noise → low-pass filtered → scratch texture
      final noise = rng.nextDouble() * 2.0 - 1.0;
      // Band-limited scratch tone (paper friction frequency range)
      final scratch = math.sin(2 * math.pi * 120 * i / sr) * 0.08
                    + math.sin(2 * math.pi * 240 * i / sr) * 0.04;

      final raw = noise * 0.92 + scratch;
      // Low-pass filter to remove sharp clicks and high-frequency harshness
      prev = lpAlpha * raw + (1.0 - lpAlpha) * prev;

      final sample = prev * env * amplitude;
      final s = (sample * 32767).clamp(-32768.0, 32767.0).toInt();
      buf.setInt16(44 + i * 2, s, Endian.little);
    }
    return buf.buffer.asUint8List();
  }

  static void _writeWavHeader(ByteData buf, int sr, int n) {
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
  }

  static void _setAscii(ByteData b, int off, String s) {
    for (int i = 0; i < s.length; i++) b.setUint8(off + i, s.codeUnitAt(i));
  }
}
