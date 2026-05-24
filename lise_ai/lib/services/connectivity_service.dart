import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

// ── ConnectivityService ───────────────────────────────────────────────────────
//
// Checks internet connectivity by attempting a DNS lookup.
// Uses dart:io — no extra packages required.
//
// Future hook: replace with connectivity_plus + VPN-aware checks.

class ConnectivityService extends ChangeNotifier {
  static const _checkInterval = Duration(seconds: 15);
  static const _testHost = 'api.anthropic.com';

  bool _isOnline = true;
  bool _initialized = false;
  Timer? _timer;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Start periodic connectivity checks.
  Future<void> start() async {
    await _check();
    _initialized = true;
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup(_testHost)
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      _update(online);
    } on SocketException {
      _update(false);
    } on TimeoutException {
      _update(false);
    } catch (e) {
      debugPrint('[Connectivity] check error: $e');
      // Don't mark offline on unexpected errors — could be a DNS quirk
    }
  }

  void _update(bool online) {
    if (online != _isOnline || !_initialized) {
      _isOnline = online;
      notifyListeners();
      debugPrint('[Connectivity] ${online ? "online" : "offline"}');
    }
  }

  /// One-shot check — returns current online state.
  Future<bool> checkNow() async {
    await _check();
    return _isOnline;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
