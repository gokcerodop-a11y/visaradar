import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/emergency_contact.dart';

// SOS Morse code timing (ms): ... --- ...
const _dot = 200;
const _dash = 600;
const _symbolGap = 200;
const _letterGap = 600;
const _wordGap = 1400;

class SosService {
  static bool _alarmActive = false;
  static bool _lightActive = false;
  static bool _torchOn = false;

  static bool get alarmActive => _alarmActive;
  static bool get lightActive => _lightActive;

  static Future<bool> isTorchAvailable() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (_) {
      return false;
    }
  }

  static Future<void> startAlarm() async {
    _alarmActive = true;
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (e) {
      debugPrint('[SOS] alarm error: $e');
    }
  }

  static Future<void> stopAlarm() async {
    _alarmActive = false;
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('[SOS] stop alarm error: $e');
    }
  }

  static Future<void> startSosLight() async {
    if (_lightActive) return;
    _lightActive = true;
    _runSosPattern();
  }

  static void stopSosLight() {
    _lightActive = false;
    if (_torchOn) {
      TorchLight.disableTorch().catchError((_) {});
      _torchOn = false;
    }
  }

  static Future<void> stopAll() async {
    await stopAlarm();
    stopSosLight();
  }

  // SOS = ... --- ... (3 dots, 3 dashes, 3 dots)
  static Future<void> _runSosPattern() async {
    // durations for each symbol: dot or dash
    final symbols = [_dot, _dot, _dot, _dash, _dash, _dash, _dot, _dot, _dot];
    // gaps after each symbol (last of each letter gets letterGap, intra-letter symbolGap)
    final gaps = [
      _symbolGap, _symbolGap, _letterGap, // S (...)
      _symbolGap, _symbolGap, _letterGap, // O (---)
      _symbolGap, _symbolGap, _wordGap,   // S (...)
    ];
    while (_lightActive) {
      for (int i = 0; i < symbols.length; i++) {
        if (!_lightActive) break;
        await _setTorch(true);
        await Future.delayed(Duration(milliseconds: symbols[i]));
        await _setTorch(false);
        if (_lightActive) {
          await Future.delayed(Duration(milliseconds: gaps[i]));
        }
      }
    }
  }

  static Future<void> _setTorch(bool on) async {
    try {
      if (on) {
        await TorchLight.enableTorch();
        _torchOn = true;
      } else {
        await TorchLight.disableTorch();
        _torchOn = false;
      }
    } catch (_) {}
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> sendSosMessage(
      EmergencyContact contact, Position? pos) async {
    final String body;
    if (pos != null) {
      final lat = pos.latitude.toStringAsFixed(6);
      final lon = pos.longitude.toStringAsFixed(6);
      body =
          'ACIL YARDIM! Konumum: https://maps.google.com/?q=$lat,$lon  Hemen ara!';
    } else {
      body = 'ACIL YARDIM! Konumum alinamadi. Lutfen hemen ara!';
    }
    final uri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: {'body': body},
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[SOS] SMS error: $e');
    }
  }

  static Future<void> sendOkMessage(EmergencyContact contact) async {
    const body =
        'Guvendeyim, endiselenmeyin. VisaRadar ile bilgi verdim.';
    final uri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: {'body': body},
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[SOS] OK SMS error: $e');
    }
  }
}
