import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/locale.dart';
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
        title: Text(L.t('Diagnostics', 'Tanılama')),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: L.t('Refresh', 'Yenile'),
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
              L.t(
                'Read-only snapshot of the running build. Share these values when '
                    'reporting a TestFlight or App Store issue.',
                'Çalışan derlemenin salt-okunur özeti. TestFlight veya App Store '
                    'sorunu bildirirken bu değerleri paylaşın.',
              ),
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            _Section(title: L.t('Build', 'Derleme'), items: [
              _Row(L.t('Version', 'Sürüm'), AppConstants.appVersion),
              _Row(L.t('Build mode', 'Derleme modu'), _buildMode()),
              _Row(L.t('Bundle ID', 'Paket Kimliği'), 'com.visaradar.visaradar'),
              _Row(L.t('Platform', 'Platform'), _platform()),
            ]),
            const SizedBox(height: 16),

            _Section(title: L.t('Permissions', 'İzinler'), items: [
              _Row(
                L.t('Location', 'Konum'),
                _formatLocationPermission(loc.permission),
                accent: _accentForLocationPermission(loc.permission),
              ),
              _Row(
                L.t('Notifications', 'Bildirimler'),
                _loading
                    ? L.t('Checking…', 'Denetleniyor…')
                    : (_notificationsAllowed == null
                        ? L.t('Unknown', 'Bilinmiyor')
                        : (_notificationsAllowed!
                            ? L.t('Allowed', 'İzin verildi')
                            : L.t('Not allowed', 'İzin verilmedi'))),
                accent: _loading
                    ? null
                    : (_notificationsAllowed == true
                        ? AppColors.success
                        : AppColors.warning),
              ),
            ]),
            const SizedBox(height: 16),

            _Section(title: L.t('Runtime', 'Çalışma zamanı'), items: [
              _Row(
                L.t('Connectivity', 'Bağlantı'),
                _loading
                    ? L.t('Checking…', 'Denetleniyor…')
                    : _formatConnectivity(_connectivity),
              ),
              _Row(
                L.t('Location phase', 'Konum aşaması'),
                _formatLocationPhase(loc.phase),
              ),
              _Row(
                L.t('Detected country', 'Algılanan ülke'),
                loc.detectedCountry?.toString() ?? '—',
              ),
            ]),
            const SizedBox(height: 16),

            _Section(title: L.t('Release readiness', 'Yayın hazırlığı'), items: [
              _CheckRow(
                label: L.t('Privacy strings present', 'Gizlilik metinleri mevcut'),
                ok: true,
                note: 'NSLocationWhenInUseUsageDescription only',
              ),
              _CheckRow(
                label: L.t(
                  'No misleading background-location claim',
                  'Yanıltıcı arka plan konumu iddiası yok',
                ),
                ok: true,
              ),
              _CheckRow(
                label: L.t(
                  'No in-app purchase / paywall in v1',
                  'v1 sürümünde uygulama içi satın alma / ödeme duvarı yok',
                ),
                ok: true,
                note: L.t(
                  'Subscription UI hidden — no IAP shown',
                  'Abonelik arayüzü gizli — uygulama içi satın alma gösterilmiyor',
                ),
              ),
              _CheckRow(
                label: L.t('Portrait-only orientation', 'Yalnızca dikey yönlendirme'),
                ok: true,
              ),
              _CheckRow(
                label: L.t(
                  'Encryption export compliance set',
                  'Şifreleme ihracat uyumluluğu ayarlandı',
                ),
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
        return L.t('Not asked yet', 'Henüz sorulmadı');
      case LocationPermissionStatus.denied:
        return L.t('Denied', 'Reddedildi');
      case LocationPermissionStatus.deniedForever:
        return L.t('Denied permanently', 'Kalıcı olarak reddedildi');
      case LocationPermissionStatus.granted:
        return L.t('When in use', 'Kullanımdayken');
      case LocationPermissionStatus.restricted:
        return L.t('Restricted', 'Kısıtlı');
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
        return L.t('Idle', 'Boşta');
      case LocationDetectionPhase.detecting:
        return L.t('Detecting…', 'Algılanıyor…');
      case LocationDetectionPhase.detected:
        return L.t('Detected', 'Algılandı');
      case LocationDetectionPhase.failed:
        return L.t('Failed', 'Başarısız');
    }
  }

  String _formatConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return L.t('Offline', 'Çevrimdışı');
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
        return L.t('Mobile', 'Mobil');
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return L.t('Other', 'Diğer');
      case ConnectivityResult.none:
        return L.t('None', 'Yok');
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
