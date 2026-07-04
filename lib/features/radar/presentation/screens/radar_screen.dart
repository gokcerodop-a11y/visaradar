import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../border/border_mode_widgets.dart';
import '../../../location/presentation/screens/location_detail_screen.dart';
import '../../../border_crossing/presentation/providers/border_crossing_provider.dart';
import '../../../border_crossing/presentation/widgets/crossing_suggestion_card.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../countries/domain/country_data.dart';
import '../../../travel/domain/usecases/schengen_calculator.dart';
import '../../../travel/presentation/providers/trips_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _dayFmt = DateFormat('EEEE, d MMM');

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

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addTrip),
        backgroundColor: AppColors.brandTeal,
        foregroundColor: AppColors.brandNavy,
        icon: const Icon(Icons.add),
        label: Text(ref.watch(isTurkishProvider) ? 'Seyahat Ekle' : 'Add Trip'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _RadarHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _LocationCard(),
                  const SizedBox(height: 12),
                  const BorderModeCard(),
                  if (hasSuggestion) ...[
                    const CrossingSuggestionCard(),
                    const SizedBox(height: 12),
                  ],
                  if (showSchengen) ...[
                    const _SchengenCard(),
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
    final dateStr = _dayFmt.format(DateTime.now());

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
            tooltip: 'Kolaylıklar',
            onPressed: () => _showFeatures(context),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(
              Icons.language,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Country Stays',
            onPressed: () => context.push(AppRoutes.stays),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => context.push(AppRoutes.notificationSettings),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
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
        descEn: 'GPS detects which country you\'re in — the moment you cross a border.',
        descTr: 'GPS ile hangi ülkede olduğunuzu anlık olarak tespit eder — sınır geçer geçmez.',
      ),
      _FeatureItem(
        emoji: '🛡️',
        en: 'Auto Schengen Tracker',
        tr: 'Otomatik Schengen Takip',
        descEn: 'Real-time 90/180-day rolling window tracker. Never overstay again.',
        descTr: 'Gerçek zamanlı 90/180 günlük pencere hesabı. Bir daha asla limit aşımı yaşamayın.',
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
        descEn: 'Exact visa status for Turkish passport holders in 50+ countries.',
        descTr: 'Türk pasaportu için 50\'den fazla ülkede vize durumu, kapıda vize, e-vize bilgisi.',
      ),
      _FeatureItem(
        emoji: '📍',
        en: 'Stay History',
        tr: 'Kalış Geçmişi',
        descEn: 'Automatic log of every country and city you visit. Your travel journal.',
        descTr: 'Ziyaret ettiğiniz her ülke ve şehrin otomatik kaydı. Seyahat günlüğünüz.',
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
        descEn: 'Real-time weather, UV, humidity and PM2.5 at your exact location.',
        descTr: 'Tam konumunuzda gerçek zamanlı hava, UV, nem ve PM2.5 kalite verisi.',
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

class _LocationCard extends ConsumerWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locState = ref.watch(locationProvider);
    final notifier = ref.read(locationProvider.notifier);
    final isTr = ref.watch(isTurkishProvider);

    // ── No permission ───────────────────────────────────────────────────────
    if (!locState.hasPermission) {
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
                ? "Otomatik algılama için Ayarlar'dan konuma izin verin"
                : 'Allow location in Settings to auto-detect')
            : (isTr
                ? 'Ülkenizi otomatik algılamak için açın'
                : 'Enable to auto-detect your country'),
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

    // ── Granted but idle / failed ────────────────────────────────────────────
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isTeal ? AppColors.brandTeal.withAlpha(25) : AppColors.divider,
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

    String resetText = isTr ? 'Yaklaşan sıfırlama yok' : 'No upcoming reset';
    if (result.nextResetDate != null) {
      final d = _dateFmt.format(result.nextResetDate!.toLocal());
      resetText = isTr ? '$d tarihinde sıfırlanır' : 'Resets $d';
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
                  isTr ? '90/180 günlük pencere' : '90/180-day window',
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
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push(AppRoutes.trips),
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
                  ? _dateFmt.format(latest.entryDate.toLocal())
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
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(
            color: valueColor ?? AppColors.textPrimary,
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
