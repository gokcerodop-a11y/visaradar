import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/domain/models/user_profile.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../domain/visa_country.dart';

class CountryDetailScreen extends ConsumerWidget {
  const CountryDetailScreen({super.key, required this.country});
  final VisaCountry country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);
    final c = country;
    final travelMode = ref.watch(profileProvider).travelMode;

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
          _smartTips(c, travelMode, isTr),
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
    final schengen = c.isSchengen;
    final color = schengen ? AppColors.info : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(schengen ? Icons.public : Icons.flight_takeoff, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              schengen
                  ? (isTr
                      ? 'Schengen bölgesi — günler 90/180 hesabına sayılır.'
                      : 'Schengen area — days count toward your 90/180.')
                  : (isTr
                      ? 'Schengen dışı — günler 90/180 hesabına sayılmaz.'
                      : 'Outside Schengen — days don\'t count toward 90/180.'),
              style: AppTextStyles.bodyMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
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
