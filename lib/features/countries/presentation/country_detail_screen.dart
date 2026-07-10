import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/domain/models/user_profile.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../domain/visa_country.dart';
import '../domain/country_enrichment.dart';

class CountryDetailScreen extends ConsumerWidget {
  const CountryDetailScreen({super.key, required this.country});
  final VisaCountry country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);
    final c = country;
    final travelMode = ref.watch(profileProvider).travelMode;
    final enrichment = enrichmentFor(c.code);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(c.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(c.name(isTr)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _visaBanner(c, isTr),
          const SizedBox(height: 16),
          _section(
            isTr ? 'Vize bilgisi' : 'Visa info',
            Icons.assignment_outlined,
            [Text(c.visa(isTr), style: AppTextStyles.bodyMedium)],
          ),
          _section(
            isTr ? 'Hız limitleri (km/s)' : 'Speed limits (km/h)',
            Icons.speed,
            [
              _statRow(isTr ? 'Şehir içi' : 'Urban', '${c.speedUrban}'),
              _statRow(isTr ? 'Şehir dışı' : 'Rural', '${c.speedRural}'),
              _statRow(
                  isTr ? 'Otoyol' : 'Highway',
                  c.speedHighway < 0
                      ? (isTr ? 'Limit yok' : 'No limit')
                      : '${c.speedHighway}'),
            ],
          ),
          _section(
            isTr ? 'Alkol & sürüş' : 'Alcohol & driving',
            Icons.no_drinks_outlined,
            [
              _statRow(isTr ? 'Yasal alkol sınırı' : 'Legal alcohol limit',
                  '${c.alcoholBac.toStringAsFixed(2)} g/L'),
              const SizedBox(height: 8),
              Text(c.drive(isTr), style: AppTextStyles.bodyMedium),
              if (c.vignette) ...[
                const SizedBox(height: 8),
                _pill(
                    isTr
                        ? 'Otoyol için vinyet gerekli'
                        : 'Motorway vignette required',
                    AppColors.warning),
              ],
            ],
          ),
          _section(
            isTr ? 'Acil numaralar' : 'Emergency numbers',
            Icons.emergency_outlined,
            [
              _callRow(context, isTr ? 'Acil (genel)' : 'Emergency (general)',
                  c.emergencyGeneral),
              if (c.emergencyPolice != null)
                _callRow(context, isTr ? 'Polis' : 'Police', c.emergencyPolice!),
              if (c.emergencyAmbulance != null)
                _callRow(context, isTr ? 'Ambulans' : 'Ambulance',
                    c.emergencyAmbulance!),
            ],
          ),
          if (enrichment != null)
            _enrichmentSection(enrichment, isTr),
          _smartTips(c, travelMode, isTr),
          if (c.cultural(isTr) != null)
            _section(
              isTr ? 'Kültür & Tarih' : 'Culture & History',
              Icons.museum_outlined,
              [Text(c.cultural(isTr)!, style: AppTextStyles.bodyMedium)],
            ),
          if (c.practical(isTr) != null)
            _section(
              isTr ? 'Pratik Bilgiler' : 'Practical Tips',
              Icons.tips_and_updates_outlined,
              [Text(c.practical(isTr)!, style: AppTextStyles.bodyMedium)],
            ),
          if (c.bestTime(isTr) != null)
            _section(
              isTr ? 'En İyi Zaman' : 'Best Time to Visit',
              Icons.wb_sunny_outlined,
              [Text(c.bestTime(isTr)!, style: AppTextStyles.bodyMedium)],
            ),
          if (enrichment?.foodHighlightsEn != null)
            _section(
              isTr ? 'Yemek ve Lezzetler' : 'Food and Cuisine',
              Icons.restaurant_outlined,
              [Text(isTr ? enrichment!.foodHighlightsTr ?? enrichment.foodHighlightsEn! : enrichment!.foodHighlightsEn!, style: AppTextStyles.bodyMedium)],
            ),
          if (enrichment?.streetFoodEn != null)
            _section(
              isTr ? 'Sokak Lezzetleri' : 'Street Food',
              Icons.storefront_outlined,
              [Text(isTr ? enrichment!.streetFoodTr ?? enrichment.streetFoodEn! : enrichment!.streetFoodEn!, style: AppTextStyles.bodyMedium)],
            ),
          if (enrichment?.cityGuideEn != null)
            _section(
              isTr ? 'Konaklama ve Mahalleler' : 'Accommodation and Neighbourhoods',
              Icons.hotel_outlined,
              [Text(isTr ? enrichment!.cityGuideTr ?? enrichment.cityGuideEn! : enrichment!.cityGuideEn!, style: AppTextStyles.bodyMedium)],
            ),
          const SizedBox(height: 16),
          Text(
            isTr
                ? '* Bilgiler genel rehberlik içindir; seyahatten önce resmî '
                    'konsolosluk/sınır kaynaklarından doğrulayın.'
                : '* Information is general guidance; verify with official '
                    'consulate/border sources before travelling.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _visaBanner(VisaCountry c, bool isTr) {
    final Color color;
    final IconData icon;
    final String statusLine;
    if (c.isSchengen) {
      color = AppColors.info;
      icon = Icons.public;
      statusLine = isTr
          ? 'Schengen bölgesi — günler 90/180 hesabına sayılır.'
          : 'Schengen area — days count toward your 90/180.';
    } else if (c.requiresVisaForTurkish) {
      color = AppColors.warning;
      icon = Icons.assignment_outlined;
      statusLine = isTr
          ? 'Schengen dışı — Türk vatandaşları için vize gereklidir.'
          : 'Outside Schengen — visa required for Turkish citizens.';
    } else {
      color = AppColors.success;
      icon = Icons.flight_takeoff;
      statusLine = isTr
          ? 'Schengen dışı — Türk vatandaşları vizesiz girebilir.'
          : 'Outside Schengen — Turkish citizens may enter visa-free.';
    }

    final capital = isTr ? c.capitalTr : c.capitalEn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(statusLine,
                    style: AppTextStyles.bodyMedium.copyWith(color: color)),
              ),
            ],
          ),
          if (capital != null || c.officialLanguage != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (capital != null)
                  _infoChip(Icons.location_city_outlined, capital),
                if (c.officialLanguage != null)
                  _infoChip(Icons.translate, c.officialLanguage!),
                _infoChip(Icons.attach_money,
                    '${c.currencyCode} ${c.currency}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _smartTips(VisaCountry c, TravelMode mode, bool isTr) {
    final tips = <String>[];
    if (mode == TravelMode.car || mode == TravelMode.camperCaravan) {
      if (c.vignette) {
        tips.add(isTr
            ? 'Sınırda veya online vinyet almayı unutma.'
            : 'Remember to buy a vignette at the border or online.');
      }
      tips.add(isTr
          ? 'Yeşil Kart (uluslararası araç sigortası) bulundur.'
          : 'Carry a Green Card (international vehicle insurance).');
    }
    if (mode == TravelMode.camperCaravan) {
      tips.add(isTr
          ? 'Karavan park/kamp alanlarını önceden ayarla.'
          : 'Plan campsite/parking stops in advance.');
    }
    if (tips.isEmpty) return const SizedBox.shrink();
    return _section(
      isTr ? 'Sana özel ipuçları' : 'Tips for you',
      Icons.lightbulb_outline,
      [for (final t in tips) _bullet(t)],
    );
  }

  // ── Building blocks ─────────────────────────────────────────────────

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandTeal),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _callRow(BuildContext context, String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse('tel:$number')),
            icon: const Icon(Icons.call, size: 16),
            label: Text(number),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandTeal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6, color: AppColors.brandTeal),
          ),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _enrichmentSection(CountryEnrichment e, bool isTr) {
    final rows = <Widget>[];
    rows.add(_statRow(
      isTr ? 'Gunduz Fari (DRL)' : 'Daytime Running Lights',
      e.daytimeRunningLights
          ? (isTr ? 'Zorunlu' : 'Required')
          : (isTr ? 'Zorunlu degil' : 'Not required'),
    ));
    rows.add(_statRow(
      isTr ? 'Guvenlik Yelegi' : 'Safety Vest',
      e.safetyVestRequired
          ? (isTr ? 'Aracta bulundurulmali' : 'Must carry in vehicle')
          : (isTr ? 'Zorunlu degil' : 'Not required'),
    ));
    if (e.winterTiresEn != null) {
      rows.add(const SizedBox(height: 8));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.ac_unit, size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isTr ? e.winterTiresTr ?? e.winterTiresEn! : e.winterTiresEn!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ));
    }
    if (e.taxFreeMinEur != null) {
      rows.add(const SizedBox(height: 8));
      rows.add(_statRow(
        isTr ? 'Tax-Free minimum' : 'Tax-Free minimum',
        'EUR ' + e.taxFreeMinEur!.toStringAsFixed(0) + (e.taxFreeCompanies != null ? ' - ' + e.taxFreeCompanies! : ''),
      ));
    }
    return _section(
      isTr ? 'Surus Kurallari (Ek)' : 'Driving Rules (Extra)',
      Icons.car_repair,
      rows,
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: AppTextStyles.bodySmall
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
