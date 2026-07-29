import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../sos/presentation/widgets/sos_fab.dart';
import '../../../border/border_mode_widgets.dart';
import '../../../location/presentation/screens/location_detail_screen.dart';
import '../../../border_crossing/presentation/providers/border_crossing_provider.dart';
import '../../../border_crossing/presentation/widgets/crossing_suggestion_card.dart';
import '../../../location/domain/models/location_state.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location_proof/data/services/location_proof_service.dart';
import '../../../travel_calendar/data/services/travel_log_service.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../countries/domain/country_data.dart';
import '../../../travel/domain/usecases/schengen_calculator.dart';
import '../../../travel/presentation/providers/trips_provider.dart';

DateFormat _dateFmt() => DateFormat('d MMM yyyy');
DateFormat _dayFmt() => DateFormat('EEEE, d MMM');

// ---------------------------------------------------------------------------
// Automatic capture — location proof chain (Derin Bilgi) + travel calendar
// ---------------------------------------------------------------------------

/// Records the freshly detected GPS fix in the tamper-evident location-proof
/// chain and in the travel calendar. Fire-and-forget; never throws.
Future<void> _recordAutomaticCapture(DetectedCountry country) async {
  final Position pos;
  try {
    pos = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
  } catch (e) {
    debugPrint('[AutoCapture] position error: $e');
    return;
  }

  // K-2 — append the fix to the SHA-256 location proof chain.
  try {
    await LocationProofService().recordCurrentLocation(
      pos,
      city: country.city,
      country: country.name,
      countryCode: country.isoCode,
    );
  } catch (e) {
    debugPrint('[LocationProof] $e');
  }

  // Y-3 — travel calendar. updateFromPosition() persists the previous fix
  // itself and adds the km delta (with a 50 m jitter filter), so a separate
  // addKm() call is not needed — it would double-count the distance.
  try {
    await TravelLogService()
        .updateFromPosition(pos, country.city, country.name);
  } catch (e) {
    debugPrint('[TravelLog] $e');
  }
}

/// Records a GPS-only proof entry when reverse-geocoding fails (e.g. offline).
/// Country/city remain null; the SHA-256 chain still links correctly.
Future<void> _recordGpsOnlyCapture() async {
  final Position pos;
  try {
    pos = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
  } catch (e) {
    debugPrint('[AutoCapture] offline GPS error: $e');
    return;
  }
  try {
    await LocationProofService().recordCurrentLocation(pos);
  } catch (e) {
    debugPrint('[LocationProof] offline: $e');
  }
  try {
    await TravelLogService().updateFromPosition(pos, null, null);
  } catch (e) {
    debugPrint('[TravelLog] offline: $e');
  }
}

/// Shows a one-time contextual notification-permission dialog right after the
/// user saves their first travel entry. Guarded by the
/// 'notification_permission_asked' SharedPreferences flag.
Future<void> _maybeAskNotificationPermission(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('notification_permission_asked') == true) return;

  final status = await Permission.notification.status;
  if (status.isGranted) return;

  await prefs.setBool('notification_permission_asked', true);
  if (!context.mounted) return;

  final wantsAlerts = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        L.isTr ? 'Schengen Uyarıları' : 'Schengen Alerts',
        style: AppTextStyles.headlineMedium,
      ),
      content: Text(
        L.isTr
            ? 'Schengen limitinize yaklaşınca 30, 15, 7 ve 3 gün öncesinde '
                'uyarı almak ister misiniz?'
            : 'Would you like to receive alerts 30, 15, 7, and 3 days before '
                'your Schengen limit?',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(
            L.isTr ? 'Hayır, teşekkürler' : 'No thanks',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(
            L.isTr ? 'Evet, uyar beni' : 'Yes, alert me',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.brandTeal,
            ),
          ),
        ),
      ],
    ),
  );

  if (wantsAlerts == true) {
    await Permission.notification.request();
  }
}

class RadarScreen extends ConsumerWidget {
  const RadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final showSchengen = profile.passportType != PassportType.euEeaSwiss ||
        profile.residenceStatus == ResidenceStatus.none;

    // Watch borderCrossingProvider — keeps it alive and rebuilds this widget
    // whenever suggestion state changes.
    final suggestion = ref.watch(borderCrossingProvider);
    final hasSuggestion = suggestion != null;

    // Every successful GPS detection feeds the location-proof chain (K-2)
    // and the travel calendar (Y-3). A new DetectedCountry instance is
    // created per successful detection, so `identical` gates duplicates.
    // When reverse-geocoding fails offline (phase → failed), GPS coordinates
    // are still recorded in the proof chain without country/city metadata.
    ref.listen<LocationState>(locationProvider, (prev, next) {
      final country = next.detectedCountry;
      if (country != null && !identical(prev?.detectedCountry, country)) {
        _recordAutomaticCapture(country);
      } else if (next.phase == LocationDetectionPhase.failed &&
          prev?.phase == LocationDetectionPhase.detecting) {
        _recordGpsOnlyCapture();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SosFab(onPressed: () => context.push(AppRoutes.sos)),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_trip_fab',
            onPressed: () async {
              final tripsBefore = ref.read(tripsProvider).length;
              await context.push(AppRoutes.addTrip);
              if (!context.mounted) return;
              // A travel was actually saved → contextual notification ask.
              if (ref.read(tripsProvider).length > tripsBefore) {
                await _maybeAskNotificationPermission(context);
              }
            },
            backgroundColor: AppColors.brandTeal,
            foregroundColor: AppColors.brandNavy,
            icon: const Icon(Icons.add),
            label: Text(
                ref.watch(isTurkishProvider) ? 'Seyahat Ekle' : 'Add Trip'),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _RadarHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Schengen 90/180 is the most critical information → always
                  // the FIRST card.
                  if (showSchengen) ...[
                    const _SchengenCard(),
                    const SizedBox(height: 12),
                  ],
                  // One-time EES/ETIAS info banner (second position). The
                  // banner renders SizedBox.shrink() once dismissed.
                  const _EesEtiasBanner(),
                  const _LocationCard(),
                  const SizedBox(height: 12),
                  const BorderModeCard(),
                  if (hasSuggestion) ...[
                    const CrossingSuggestionCard(),
                    const SizedBox(height: 12),
                  ],
                  // Strict UX rule: if a pending suggestion exists, do NOT
                  // show the "All clear" alerts card — it would falsely imply
                  // no action is needed while a crossing needs confirmation.
                  if (!hasSuggestion) ...[
                    const _AlertsCard(),
                    const SizedBox(height: 12),
                  ],
                  const _TravelSummaryCard(),
                  const SizedBox(height: 12),
                  const _OtherCountriesSummaryCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _RadarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dateStr = _dayFmt().format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Radar', style: AppTextStyles.displayMedium),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: L.isTr ? 'Kolaylıklar' : 'Quick Access',
            onPressed: () => _showFeatures(context),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            icon: const Icon(
              Icons.language,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: L.isTr ? 'Kalışlar' : 'Country Stays',
            onPressed: () => context.push(AppRoutes.stays),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: L.isTr ? 'Bildirim Ayarları' : 'Notification Settings',
            onPressed: () => context.push(AppRoutes.notificationSettings),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  void _showFeatures(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeaturesSheet(isTr: isTr),
    );
  }
}

// ---------------------------------------------------------------------------
// Features showcase sheet
// ---------------------------------------------------------------------------

class _FeaturesSheet extends StatelessWidget {
  const _FeaturesSheet({required this.isTr});
  final bool isTr;

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(
        emoji: '🌍',
        en: 'Auto Country Detection',
        tr: 'Otomatik Ülke Algılama',
        descEn: 'GPS detects which country you\'re in — auto-detection when app is open.',
        descTr: 'GPS ile hangi ülkede olduğunuzu tespit eder — uygulama açıkken otomatik algılama.',
      ),
      _FeatureItem(
        emoji: '🛡️',
        en: 'Auto Schengen Tracker',
        tr: 'Otomatik Schengen Takip',
        descEn: '90/180-day rolling window tracker — auto-detection when app is open. Stay informed and avoid overstays.',
        descTr: '90/180 günlük pencere hesabı — uygulama açıkken otomatik algılama. Güncel bilgiyle sınır aşımlarının önüne geçin.',
      ),
      _FeatureItem(
        emoji: '⏰',
        en: 'Smart Expiry Alerts',
        tr: 'Süreniz Dolmadan Otomatik Uyarı',
        descEn: 'Get notified before your Schengen allowance or visa-free period runs out.',
        descTr: 'Schengen hakkınız veya vize serbestiniz dolmadan önce otomatik bildirim alırsınız.',
      ),
      _FeatureItem(
        emoji: '🚗',
        en: 'Border Intelligence',
        tr: 'Sınır Geçiş Rehberi',
        descEn: 'Speed limits, vignettes, alcohol limits, emergency numbers — for every country.',
        descTr: 'Her ülke için hız limitleri, vinyet, alkol sınırı ve acil numaralar.',
      ),
      _FeatureItem(
        emoji: '✈️',
        en: 'Visa Guide',
        tr: 'Vize Rehberi',
        descEn: 'Exact visa status for Turkish passport holders in 23+ countries.',
        descTr: 'Türk pasaportu için 23\'ten fazla ülkede vize durumu, kapıda vize, e-vize bilgisi.',
      ),
      _FeatureItem(
        emoji: '📍',
        en: 'Stay History',
        tr: 'Kalış Geçmişi',
        descEn: 'Log of every country and city you visit — auto-detection when app is open. Your travel journal.',
        descTr: 'Ziyaret ettiğiniz her ülke ve şehrin kaydı — uygulama açıkken otomatik algılama. Seyahat günlüğünüz.',
      ),
      _FeatureItem(
        emoji: '🗓️',
        en: 'Go Back Anytime',
        tr: 'İstediğin Zaman Aynı Yere Dönüş',
        descEn: 'Return to that exact street with a single tap.',
        descTr: 'Sevdiğin o sokağa nokta atışı tekrar git.',
      ),
      _FeatureItem(
        emoji: '👥',
        en: 'Locals & Events Nearby (Premium)',
        tr: 'Bulunduğun Yerde Seni Bekleyenler (Premium)',
        descEn: 'Discover expat communities, local events, nearby travellers and hidden gems at your destination. (Premium)',
        descTr: 'Bulunduğun şehirdeki expat toplulukları, yerel etkinlikler, yakındaki gezginler ve gizli köşeleri keşfet. (Premium)',
      ),
      _FeatureItem(
        emoji: '🌤️',
        en: 'Live Weather + Air Quality',
        tr: 'Canlı Hava + Hava Kalitesi',
        descEn: 'Current weather, UV, humidity and PM2.5 at your exact location.',
        descTr: 'Tam konumunuzda anlık hava, UV, nem ve PM2.5 kalite verisi.',
      ),
      _FeatureItem(
        emoji: '🤖',
        en: 'AI Travel Assistant (Premium)',
        tr: 'Yapay Zekâ Asistanı (Premium)',
        descEn: 'Ask anything about visas, Schengen, borders, and your destination. Get instant expert answers powered by AI. (Premium)',
        descTr: 'Vize, Schengen, sınır ve gideceğiniz ülke hakkında her şeyi sorun. Yapay zekâ destekli anında uzman yanıtı. (Premium)',
      ),
      _FeatureItem(
        emoji: '📄',
        en: 'Document Scanner (Premium)',
        tr: 'Belge Tarayıcı (Premium)',
        descEn: 'Photograph your passport or visa stamp — travel dates are read automatically and added to your history. (Premium)',
        descTr: 'Pasaport veya vize damganızı fotoğraflayın — seyahat tarihleri otomatik okunur ve geçmişinize eklenir. (Premium)',
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTr ? 'VisaRadar Kolaylıkları' : 'What VisaRadar Does',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTr
                        ? 'Her şey bir arada — seyahatin tüm zor kısımlarını halleder.'
                        : 'Everything in one place — handles every hard part of travel.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: features.length,
                itemBuilder: (_, i) => _featureTile(features[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureTile(_FeatureItem f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTr ? f.tr : f.en,
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  isTr ? f.descTr : f.descEn,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.emoji,
    required this.en,
    required this.tr,
    required this.descEn,
    required this.descTr,
  });
  final String emoji;
  final String en;
  final String tr;
  final String descEn;
  final String descTr;
}

// ---------------------------------------------------------------------------
// Location card — reacts to permission + detection state
// ---------------------------------------------------------------------------

class _LocationCard extends ConsumerStatefulWidget {
  const _LocationCard();

  @override
  ConsumerState<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends ConsumerState<_LocationCard> {
  /// True while location permission is still undetermined / first-time
  /// denied — we then show a soft explanation card BEFORE the system dialog.
  bool _showLocationPrePermission = false;

  @override
  void initState() {
    super.initState();
    _checkPrePermissionState();
  }

  Future<void> _checkPrePermissionState() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    setState(() {
      // `denied` (NOT permanently denied) = undetermined / first-time denied.
      _showLocationPrePermission = status == PermissionStatus.denied;
    });
  }

  Future<void> _requestLocationPermission() async {
    // Actual system permission dialog.
    await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() => _showLocationPrePermission = false);
    // Sync the location provider with the new permission state and start
    // detection if the user granted access.
    ref.read(locationProvider.notifier).requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationProvider);
    final notifier = ref.read(locationProvider.notifier);
    final isTr = ref.watch(isTurkishProvider);

    // ── No permission ───────────────────────────────────────────────────────
    if (!locState.hasPermission) {
      // Soft pre-permission explanation card (before the system dialog).
      if (!locState.permissionDeniedForever && _showLocationPrePermission) {
        return _LocationPrePermissionCard(
          isTr: isTr,
          onAllow: _requestLocationPermission,
          onLater: () =>
              setState(() => _showLocationPrePermission = false),
        );
      }

      final ctaLabel = locState.permissionDeniedForever
          ? (isTr ? 'Ayarları Aç' : 'Open Settings')
          : (isTr ? 'Aç' : 'Enable');
      return _LocationRow(
        iconData: Icons.location_off_outlined,
        iconColor: AppColors.textMuted,
        iconBg: AppColors.textMuted.withAlpha(28),
        label: isTr ? 'KONUM' : 'LOCATION',
        title: isTr ? 'Algılanmıyor' : 'Not detecting',
        subtitle: locState.permissionDeniedForever
            ? (isTr
                ? "Uygulama açıkken otomatik algılama için Ayarlar'dan konuma izin verin"
                : 'Allow location in Settings for auto-detection when app is open')
            : (isTr
                ? 'Uygulama açıkken otomatik algılama için açın'
                : 'Enable auto-detection when app is open'),
        action: _LocationAction(
          label: ctaLabel,
          color: AppColors.brandTeal,
          onTap: locState.permissionDeniedForever
              ? notifier.openSettings
              : notifier.requestPermission,
        ),
      );
    }

    // ── Detecting ───────────────────────────────────────────────────────────
    if (locState.isDetecting) {
      return _LocationRow(
        iconData: Icons.my_location,
        iconColor: AppColors.brandTeal,
        iconBg: AppColors.brandTeal.withAlpha(20),
        label: isTr ? 'KONUM' : 'LOCATION',
        title: isTr ? 'Algılanıyor…' : 'Detecting…',
        subtitle: isTr
            ? 'Bulunduğunuz ülke aranıyor'
            : 'Looking for your current country',
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.brandTeal),
          ),
        ),
      );
    }

    // ── Country detected ────────────────────────────────────────────────────
    if (locState.hasCountry) {
      final country = locState.detectedCountry!;
      final vc = visaCountryByCode(country.isoCode);
      final flag = vc?.flag ?? '';
      final cityPart = country.city != null ? ' · ${country.city}' : '';
      return _LocationRow(
        iconData: Icons.location_on,
        iconColor: AppColors.brandTeal,
        iconBg: AppColors.brandTeal.withAlpha(20),
        label: isTr ? 'GÜNCEL KONUM' : 'CURRENT LOCATION',
        title: '$flag ${country.name ?? country.isoCode}$cityPart'.trim(),
        subtitle: isTr
            ? 'Hava durumu ve detaylar için dokun'
            : 'Tap for weather & details',
        subtitleColor: AppColors.brandTeal,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LocationDetailScreen()),
        ),
        action: _LocationAction(
          label: isTr ? 'Yenile' : 'Refresh',
          color: AppColors.textSecondary,
          onTap: notifier.refreshDetection,
        ),
      );
    }

    // ── Failed (GPS or geocoding error — typically offline) ─────────────────
    if (locState.phase == LocationDetectionPhase.failed) {
      return _LocationRow(
        iconData: Icons.location_searching,
        iconColor: AppColors.warning,
        iconBg: AppColors.warning.withAlpha(28),
        label: isTr ? 'KONUM' : 'LOCATION',
        title: isTr ? 'Konum algılanamadı' : 'Location unavailable',
        subtitle: isTr
            ? 'İnternet veya GPS bağlantısını kontrol edin'
            : 'Check your internet or GPS connection',
        subtitleColor: AppColors.warning,
        action: _LocationAction(
          label: isTr ? 'Tekrar Dene' : 'Retry',
          color: AppColors.warning,
          onTap: notifier.refreshDetection,
        ),
      );
    }

    // ── Granted but idle ─────────────────────────────────────────────────────
    return _LocationRow(
      iconData: Icons.gps_not_fixed,
      iconColor: AppColors.brandTeal,
      iconBg: AppColors.brandTeal.withAlpha(20),
      label: isTr ? 'KONUM' : 'LOCATION',
      title: isTr ? 'Konum aktif' : 'Location active',
      subtitle: isTr
          ? 'Algılamak için dokunun'
          : 'Tap Detect to find your country',
      action: _LocationAction(
        label: isTr ? 'Algıla' : 'Detect',
        color: AppColors.brandTeal,
        onTap: notifier.refreshDetection,
      ),
    );
  }
}

// ── Location pre-permission explanation card ────────────────────────────────

class _LocationPrePermissionCard extends StatelessWidget {
  const _LocationPrePermissionCard({
    required this.isTr,
    required this.onAllow,
    required this.onLater,
  });

  final bool isTr;
  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.brandTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isTr ? 'Konum İzni Gerekiyor' : 'Location Permission Needed',
                  style: AppTextStyles.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isTr
                ? 'Schengen günlerinizi otomatik takip etmek ve ülke '
                    'geçişlerini kaydetmek için konum erişimi gerekiyor.'
                : 'Location access is needed to automatically track your '
                    'Schengen days and record country crossings.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onAllow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isTr ? 'İzin Ver' : 'Allow',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.brandNavy,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onLater,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  child: Text(
                    isTr ? 'Sonra' : 'Later',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── EES/ETIAS one-time info banner ──────────────────────────────────────────

class _EesEtiasBanner extends StatefulWidget {
  const _EesEtiasBanner();

  @override
  State<_EesEtiasBanner> createState() => _EesEtiasBannerState();
}

class _EesEtiasBannerState extends State<_EesEtiasBanner> {
  static const _prefKey = 'ees_etias_banner_dismissed';

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadDismissedState();
  }

  Future<void> _loadDismissedState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_prefKey) ?? false;
    if (!mounted) return;
    setState(() => _visible = !dismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandTeal),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              L.isTr
                  ? '🔷 EES/ETIAS Yeni Kural: EES biyometrik kaydı ve '
                      'ETIAS seyahat izni yakında Schengen girişlerinde '
                      'zorunlu olacak. Seyahat öncesi resmi kaynaklardan '
                      'takip edin.'
                  : '🔷 EES/ETIAS New Rule: Biometric EES registration '
                      'and ETIAS travel authorisation will be required '
                      'for Schengen entry. Check official sources before '
                      'travel.',
              style: AppTextStyles.bodySmall,
            ),
          ),
          IconButton(
            onPressed: _dismiss,
            icon: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: L.isTr ? 'Kapat' : 'Dismiss',
          ),
        ],
      ),
    );
  }
}

// ── Shared layout atom ──────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.iconData,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.action,
    this.trailing,
    this.onTap,
  });

  final IconData iconData;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final _LocationAction? action;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = _DashCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: subtitleColor ?? AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ?trailing,
          ?action,
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

class _LocationAction extends StatelessWidget {
  const _LocationAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTeal = color == AppColors.brandTeal;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isTeal
                    ? AppColors.brandTeal.withAlpha(25)
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(8),
                border: isTeal
                    ? Border.all(color: AppColors.brandTeal.withAlpha(80))
                    : null,
              ),
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schengen card — hero numbers
// ---------------------------------------------------------------------------

class _SchengenCard extends ConsumerWidget {
  const _SchengenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(schengenResultProvider);
    final isTr = ref.watch(isTurkishProvider);

    final usedDays = result.daysUsed;
    final remainingDays = result.daysRemaining;
    final progress = (usedDays / 90).clamp(0.0, 1.0);

    final (riskColor, riskLabel) = _riskStyle(result.riskLevel, isTr);

    // 90/180 is a ROLLING window — there is no fixed reset date. Days simply
    // drop out of the window 180 days after each stay. Keep the date, but
    // describe it honestly.
    String resetText = isTr ? 'Kayan pencere' : 'Rolling window';
    if (result.nextResetDate != null) {
      final d = _dateFmt().format(result.nextResetDate!.toLocal());
      resetText = isTr ? 'Kayan pencere · $d' : 'Rolling window · $d';
    } else if (usedDays > 0) {
      resetText = isTr
          ? '$remainingDays gün kaldı'
          : '${remainingDays}d remaining';
    }

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTr ? 'SCHENGEN DURUMU' : 'SCHENGEN STATUS',
                style: AppTextStyles.caption.copyWith(
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              _RiskBadge(label: riskLabel, color: riskColor),
            ],
          ),
          const SizedBox(height: 20),

          // Hero numbers
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$usedDays',
                        style: AppTextStyles.displayMedium.copyWith(
                          letterSpacing: -1.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTr ? 'gün kullanıldı' : 'days used',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  color: AppColors.divider,
                  thickness: 1,
                  width: 40,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$remainingDays',
                        style: AppTextStyles.displayMedium.copyWith(
                          color: riskColor,
                          letterSpacing: -1.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTr ? 'gün kaldı' : 'days left',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(riskColor),
            ),
          ),
          const SizedBox(height: 8),

          // Footer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isTr
                      ? 'Son 180 günlük pencerede kullanılan Schengen günleri'
                      : 'Schengen days used in the rolling 180-day window',
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  resetText,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isTr
                ? 'Hesaplama referans amaçlıdır; resmi kayıtlar esas alınır.'
                : 'Calculation is for reference only; official records prevail.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            link: true,
            label: isTr
                ? 'Ülke kalış sürelerini görüntüle'
                : 'View country stay durations',
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.trips),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  isTr
                      ? 'Ülke kalış süreleri için tıklayın'
                      : 'Tap to see country stay durations',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brandTeal,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.brandTeal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _riskStyle(SchengenRisk risk, bool isTr) {
    switch (risk) {
      case SchengenRisk.safe:
        return (AppColors.riskSafe, isTr ? 'Güvenli' : 'Safe');
      case SchengenRisk.warning:
        return (AppColors.riskWarning, isTr ? 'Uyarı' : 'Warning');
      case SchengenRisk.critical:
        return (AppColors.riskCritical, isTr ? 'Kritik' : 'Critical');
      case SchengenRisk.over:
        return (AppColors.riskCritical, isTr ? 'Limit aşıldı' : 'Over limit');
    }
  }
}

// ---------------------------------------------------------------------------
// Alerts card — polished all-clear + active alert states
// ---------------------------------------------------------------------------

class _AlertsCard extends ConsumerWidget {
  const _AlertsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(schengenResultProvider);
    final isTr = ref.watch(isTurkishProvider);

    final IconData icon;
    final String title;
    final String subtitle;
    final Color iconColor;

    if (result.riskLevel == SchengenRisk.over) {
      icon = Icons.warning_rounded;
      title = isTr ? 'Schengen limiti aşıldı' : 'Schengen limit exceeded';
      subtitle = isTr
          ? 'Pencerede 90 günden fazla kullandınız.'
          : 'You have used more than 90 days in the rolling window.';
      iconColor = AppColors.danger;
    } else if (result.riskLevel == SchengenRisk.critical) {
      icon = Icons.warning_amber_rounded;
      title = isTr ? 'Çıkışınızı planlayın' : 'Plan your exit soon';
      subtitle = isTr
          ? 'Yalnızca ${result.daysRemaining} Schengen günü kaldı — şimdi harekete geçin.'
          : 'Only ${result.daysRemaining} Schengen days remaining — act now.';
      iconColor = AppColors.danger;
    } else if (result.riskLevel == SchengenRisk.warning) {
      icon = Icons.info_outline_rounded;
      title = isTr ? 'Schengen günleri azalıyor' : 'Schengen days running low';
      subtitle = isTr
          ? '${result.daysRemaining} gün kaldı — dikkatli olun.'
          : '${result.daysRemaining} days remaining — stay aware.';
      iconColor = AppColors.warning;
    } else {
      icon = Icons.check_circle_outline_rounded;
      title = isTr ? 'Sorun yok' : 'All clear';
      subtitle = isTr ? 'Aktif seyahat uyarısı yok' : 'No active travel alerts';
      iconColor = AppColors.riskSafe;
    }

    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Travel summary card — replaces Quick Info
// ---------------------------------------------------------------------------

class _TravelSummaryCard extends ConsumerWidget {
  const _TravelSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongoing = ref.watch(ongoingTripProvider);
    final latest = ref.watch(latestTripProvider);
    final schengenCount = ref.watch(schengenCountriesVisitedProvider);
    final hasTrips = ref.watch(tripsProvider).isNotEmpty;
    final isTr = ref.watch(isTurkishProvider);

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'SCHENGEN ÜLKELERİ SEYAHAT ÖZETİ' : 'SCHENGEN COUNTRIES TRAVEL SUMMARY',
            style: AppTextStyles.caption.copyWith(
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasTrips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.flight_takeoff_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isTr
                          ? 'İstatistiklerinizi görmek için seyahat ekleyin'
                          : 'Add a trip to see your travel stats',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _SummaryRow(
              icon: Icons.calendar_today_outlined,
              label: isTr ? 'Şu anki kalış' : 'Current stay',
              value: ongoing != null
                  ? (isTr ? '${ongoing.daysSpent}g' : '${ongoing.daysSpent}d')
                  : '—',
              valueColor:
                  ongoing != null ? AppColors.brandTeal : AppColors.textMuted,
            ),
            const _RowDivider(),
            _SummaryRow(
              icon: Icons.flight_land_outlined,
              label: isTr ? 'Son giriş' : 'Last entry',
              value: latest != null
                  ? _dateFmt().format(latest.entryDate.toLocal())
                  : '—',
            ),
            const _RowDivider(),
            _SummaryRow(
              icon: Icons.flag_outlined,
              label: isTr ? 'Schengen ülkeleri' : 'Schengen countries',
              value: '$schengenCount',
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Other Countries summary card — non-Schengen trips
// ---------------------------------------------------------------------------

class _OtherCountriesSummaryCard extends ConsumerWidget {
  const _OtherCountriesSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final isTr = ref.watch(isTurkishProvider);

    final nonSchengenTrips = trips.where((t) => !t.isSchengen).toList();
    final countrys = nonSchengenTrips.map((t) => t.country).toSet();
    final count = countrys.length;

    int totalDays = 0;
    for (final t in nonSchengenTrips) {
      totalDays += t.daysSpent;
    }

    String latestName = '—';
    if (nonSchengenTrips.isNotEmpty) {
      final latest = nonSchengenTrips
          .reduce((a, b) => a.entryDate.isAfter(b.entryDate) ? a : b);
      final vc = visaCountryByCode(latest.country);
      latestName = vc?.name(isTr) ?? latest.country;
    }

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'DİĞER ÜLKELER SEYAHAT ÖZETİ' : 'OTHER COUNTRIES TRAVEL SUMMARY',
            style: AppTextStyles.caption.copyWith(
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (nonSchengenTrips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.flight_takeoff_outlined,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isTr
                          ? 'Henüz Schengen dışı seyahat eklenmedi'
                          : 'No non-Schengen trips added yet',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _SummaryRow(
              icon: Icons.flag_outlined,
              label: isTr ? 'Ziyaret edilen ülkeler' : 'Countries visited',
              value: '$count',
              valueColor: AppColors.brandTeal,
            ),
            const _RowDivider(),
            _SummaryRow(
              icon: Icons.calendar_today_outlined,
              label: isTr ? 'Toplam gün' : 'Total days',
              value: isTr ? '${totalDays}g' : '${totalDays}d',
            ),
            const _RowDivider(),
            _SummaryRow(
              icon: Icons.flight_land_outlined,
              label: isTr ? 'Son ziyaret' : 'Latest visit',
              value: latestName,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandTeal.withAlpha(160)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        color: AppColors.divider,
        height: 1,
        thickness: 1,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared atoms
// ---------------------------------------------------------------------------

class _DashCard extends StatelessWidget {
  const _DashCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
