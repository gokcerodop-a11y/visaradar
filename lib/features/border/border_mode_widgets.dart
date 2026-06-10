import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/premium_providers.dart';
import '../countries/domain/country_data.dart';
import '../countries/domain/visa_country.dart';
import '../paywall/paywall_screen.dart';
import 'border_data.dart';
import 'border_provider.dart';

/// Card shown on the Radar screen when the user is within 50 km of a supported
/// land border. Border mode is a Premium feature: free users see a teaser.
class BorderModeCard extends ConsumerWidget {
  const BorderModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nb = ref.watch(borderModeProvider);
    if (nb == null) return const SizedBox.shrink();

    final isTr = ref.watch(isTurkishProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final dest = visaCountryByCode(nb.post.toCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withValues(alpha: 0.25),
            AppColors.brandTeal.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: AppColors.brandTeal),
              const SizedBox(width: 8),
              Text(isTr ? 'Sınır Modu' : 'Border Mode',
                  style: AppTextStyles.labelLarge),
              const Spacer(),
              Text('${nb.km.round()} km',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTr
                ? '${nb.post.name} sınır kapısına yaklaşıyorsun → ${nb.post.toName(true)}'
                : 'Approaching ${nb.post.name} border → ${nb.post.toName(false)}',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 12),
          if (isPremium && dest != null)
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BorderModeScreen(border: nb.post, dest: dest),
                ),
              ),
              icon: const Icon(Icons.checklist),
              label: Text(isTr ? 'Sınır kontrol listesi' : 'Border checklist'),
            )
          else
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              ),
              icon: const Icon(Icons.lock_open),
              label: Text(
                  isTr ? 'Premium ile sınır modu' : 'Border mode with Premium'),
            ),
        ],
      ),
    );
  }
}

class BorderModeScreen extends ConsumerWidget {
  const BorderModeScreen({super.key, required this.border, required this.dest});
  final BorderPost border;
  final VisaCountry dest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);

    final docs = isTr
        ? const [
            'Pasaport (geçerlilik 6+ ay)',
            'Vize / Schengen vizesi (gerekiyorsa)',
            'Araç ruhsatı ve ehliyet',
            'Yeşil Kart (uluslararası araç sigortası)',
            'Yeterli nakit / kart',
          ]
        : const [
            'Passport (6+ months validity)',
            'Visa / Schengen visa (if required)',
            'Vehicle registration & licence',
            'Green Card (international car insurance)',
            'Sufficient cash / card',
          ];

    return Scaffold(
      appBar: AppBar(title: Text(border.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _info(
            isTr ? 'Geçilen ülke' : 'Destination',
            '${dest.flag}  ${dest.name(isTr)}',
            Icons.flag_outlined,
          ),
          _info(
            isTr ? 'Para birimi' : 'Currency',
            '${dest.currencyCode} (${dest.currency})',
            Icons.payments_outlined,
          ),
          _info(
            isTr ? 'Tahmini bekleme' : 'Typical wait',
            isTr
                ? 'Yoğun saatlerde 30–90 dk değişebilir'
                : '30–90 min during busy hours',
            Icons.schedule,
          ),
          _info(
            dest.isSchengen
                ? (isTr ? 'Schengen' : 'Schengen')
                : (isTr ? 'Schengen dışı' : 'Non-Schengen'),
            dest.isSchengen
                ? (isTr
                    ? 'Günler 90/180 hesabına sayılır'
                    : 'Days count toward 90/180')
                : (isTr ? 'Sayılmaz' : 'Does not count'),
            Icons.public,
          ),
          const SizedBox(height: 20),
          Text(isTr ? 'Gerekli belgeler' : 'Required documents',
              style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          ...docs.map((d) => _DocItem(label: d)),
          const SizedBox(height: 16),
          Text(
            isTr
                ? 'Bekleme ve belge bilgileri genel tahmindir; resmî sınır '
                    'otoritesinden doğrulayın.'
                : 'Wait and document info are general estimates; verify with the '
                    'official border authority.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandTeal),
          const SizedBox(width: 12),
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DocItem extends StatefulWidget {
  const _DocItem({required this.label});
  final String label;
  @override
  State<_DocItem> createState() => _DocItemState();
}

class _DocItemState extends State<_DocItem> {
  bool _checked = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _checked = !_checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              _checked ? Icons.check_box : Icons.check_box_outline_blank,
              color: _checked ? AppColors.brandTeal : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color:
                      _checked ? AppColors.textSecondary : AppColors.textPrimary,
                  decoration: _checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
