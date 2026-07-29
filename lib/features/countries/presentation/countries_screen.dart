import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/country_data.dart';
import '../domain/visa_country.dart';
import 'country_detail_screen.dart';

class CountriesScreen extends ConsumerWidget {
  const CountriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isTr ? 'Ülkeler' : 'Countries')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: kVisaCountries.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                isTr
                    ? 'Sınır geçişinde ihtiyacın olan her şey — bir dokunuş uzağında.'
                    : 'Everything you need at a border crossing — one tap away.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return _card(context, kVisaCountries[index - 1], isTr);
        },
      ),
    );
  }

  Widget _card(BuildContext context, VisaCountry c, bool isTr) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CountryDetailScreen(country: c)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name(isTr),
                        style: AppTextStyles.titleLarge,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${c.currencyCode} · ${c.currency}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _schengenChip(c, isTr),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _schengenChip(VisaCountry c, bool isTr) {
    final Color color;
    final String label;
    final IconData icon;
    if (c.isSchengen) {
      color = AppColors.info;
      label = 'Schengen';
      icon = Icons.check_circle_outline;
    } else if (c.requiresVisaForTurkish) {
      color = AppColors.warning;
      label = isTr ? 'Vizeyle' : 'Visa req.';
      icon = Icons.assignment_outlined;
    } else {
      color = AppColors.success;
      label = isTr ? 'Vizesiz' : 'Visa-free';
      icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
