import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../location/domain/models/location_state.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../notifications/services/local_notification_service.dart';

/// Read-only release-readiness diagnostics.
///
/// Surfaces the runtime values testers and reviewers need to confirm a build
/// is healthy: version, build mode, permission grants, connectivity, and the
/// hard-coded compliance checks we apply in code.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _loading = true;
  bool? _notificationsAllowed;
  List<ConnectivityResult> _connectivity = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final notifGranted = await LocalNotificationService.checkPermission();
    final conn = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = notifGranted;
      _connectivity = conn;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        title: const Text('Diagnostics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),
            Text(
              'Read-only snapshot of the running build. Share these values when '
              'reporting a TestFlight or App Store issue.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            _Section(title: 'Build', items: [
              _Row('Version', AppConstants.appVersion),
              _Row('Build mode', _buildMode()),
              _Row('Bundle ID', 'com.visaradar.visaradar'),
              _Row('Platform', _platform()),
            ]),
            const SizedBox(height: 16),

            _Section(title: 'Permissions', items: [
              _Row(
                'Location',
                _formatLocationPermission(loc.permission),
                accent: _accentForLocationPermission(loc.permission),
              ),
              _Row(
                'Notifications',
                _loading
                    ? 'Checking…'
                    : (_notificationsAllowed == null
                        ? 'Unknown'
                        : (_notificationsAllowed! ? 'Allowed' : 'Not allowed')),
                accent: _loading
                    ? null
                    : (_notificationsAllowed == true
                        ? AppColors.success
                        : AppColors.warning),
              ),
            ]),
            const SizedBox(height: 16),

            _Section(title: 'Runtime', items: [
              _Row(
                'Connectivity',
                _loading ? 'Checking…' : _formatConnectivity(_connectivity),
              ),
              _Row(
                'Location phase',
                _formatLocationPhase(loc.phase),
              ),
              _Row(
                'Detected country',
                loc.detectedCountry?.toString() ?? '—',
              ),
            ]),
            const SizedBox(height: 16),

            _Section(title: 'Release readiness', items: const [
              _CheckRow(
                label: 'Privacy strings present',
                ok: true,
                note: 'NSLocationWhenInUseUsageDescription only',
              ),
              _CheckRow(
                label: 'No misleading background-location claim',
                ok: true,
              ),
              _CheckRow(
                label: 'No in-app purchase / paywall in v1',
                ok: true,
                note: 'Subscription UI hidden — no IAP shown',
              ),
              _CheckRow(
                label: 'Portrait-only orientation',
                ok: true,
              ),
              _CheckRow(
                label: 'Encryption export compliance set',
                ok: true,
                note: 'ITSAppUsesNonExemptEncryption = false',
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Formatters ──────────────────────────────────────────────────────────

  String _buildMode() {
    if (kReleaseMode) return 'Release';
    if (kProfileMode) return 'Profile';
    return 'Debug';
  }

  String _platform() {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    return 'Other';
  }

  String _formatLocationPermission(LocationPermissionStatus s) {
    switch (s) {
      case LocationPermissionStatus.notDetermined:
        return 'Not asked yet';
      case LocationPermissionStatus.denied:
        return 'Denied';
      case LocationPermissionStatus.deniedForever:
        return 'Denied permanently';
      case LocationPermissionStatus.granted:
        return 'When in use';
      case LocationPermissionStatus.restricted:
        return 'Restricted';
    }
  }

  Color? _accentForLocationPermission(LocationPermissionStatus s) {
    switch (s) {
      case LocationPermissionStatus.granted:
        return AppColors.success;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.deniedForever:
      case LocationPermissionStatus.restricted:
        return AppColors.warning;
      case LocationPermissionStatus.notDetermined:
        return null;
    }
  }

  String _formatLocationPhase(LocationDetectionPhase p) {
    switch (p) {
      case LocationDetectionPhase.idle:
        return 'Idle';
      case LocationDetectionPhase.detecting:
        return 'Detecting…';
      case LocationDetectionPhase.detected:
        return 'Detected';
      case LocationDetectionPhase.failed:
        return 'Failed';
    }
  }

  String _formatConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return 'Offline';
    }
    return results
        .where((r) => r != ConnectivityResult.none)
        .map(_connectivityLabel)
        .join(', ');
  }

  String _connectivityLabel(ConnectivityResult r) {
    switch (r) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'None';
    }
  }
}

// ---------------------------------------------------------------------------
// Section
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: items.expand((item) sync* {
              yield item;
              if (item != items.last) {
                yield const Divider(height: 1, color: AppColors.divider);
              }
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row — simple key / value
// ---------------------------------------------------------------------------

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                color: accent ?? AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CheckRow — green-check / red-dot status row with optional note
// ---------------------------------------------------------------------------

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.ok, this.note});

  final String label;
  final bool ok;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error,
            size: 18,
            color: ok ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
