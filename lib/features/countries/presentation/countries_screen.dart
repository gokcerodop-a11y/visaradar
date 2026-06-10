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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            isTr
                ? 'Sınır geçişinde ihtiyacın olan her şey — bir dokunuş uzağında.'
                : 'Everything you need at a border crossing — one tap away.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final c in kVisaCountries) _card(context, c, isTr),
        ],
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
                      Text(c.name(isTr), style: AppTextStyles.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '${c.currencyCode} · ${c.currency}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _schengenChip(c.isSchengen, isTr),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _schengenChip(bool isSchengen, bool isTr) {
    final color = isSchengen ? AppColors.info : AppColors.success;
    final label = isSchengen
        ? 'Schengen'
        : (isTr ? 'Vizesiz*' : 'Visa-free*');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
