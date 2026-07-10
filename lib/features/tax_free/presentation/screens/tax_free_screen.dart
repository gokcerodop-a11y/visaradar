import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/tax_free_data.dart';

/// Tax-Free shopping guide: searchable country list with expandable
/// step-by-step VAT refund instructions.
class TaxFreeScreen extends ConsumerStatefulWidget {
  const TaxFreeScreen({super.key});

  @override
  ConsumerState<TaxFreeScreen> createState() => _TaxFreeScreenState();
}

class _TaxFreeScreenState extends ConsumerState<TaxFreeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Country code of the currently expanded card, or null.
  String? _expanded;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TaxFreeCountryInfo> _filtered(bool isTr) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kTaxFreeCountries;
    return kTaxFreeCountries.where((c) {
      return c.nameEn.toLowerCase().contains(q) ||
          c.nameTr.toLowerCase().contains(q) ||
          c.countryCode.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);
    final countries = _filtered(isTr);

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        title: Text(
          isTr ? 'Tax-Free Rehberi' : 'Tax-Free Guide',
          style: AppTextStyles.headlineMedium,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _InfoBanner(isTr: isTr),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: AppTextStyles.bodyMedium,
                cursorColor: AppColors.brandTeal,
                decoration: InputDecoration(
                  hintText: isTr ? 'Ülke ara...' : 'Search country...',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textSecondary, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.brandTeal, width: 1),
                  ),
                ),
              ),
            ),
            Expanded(
              child: countries.isEmpty
                  ? Center(
                      child: Text(
                        isTr ? 'Sonuç bulunamadı' : 'No results found',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final info = countries[index];
                        return _CountryCard(
                          info: info,
                          isTr: isTr,
                          expanded: _expanded == info.countryCode,
                          onTap: () {
                            setState(() {
                              _expanded = _expanded == info.countryCode
                                  ? null
                                  : info.countryCode;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top banner explaining what tax-free shopping is.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.isTr});

  final bool isTr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandTeal.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shopping_bag_outlined,
              color: AppColors.brandTeal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isTr
                  ? 'Tax-free alışveriş: AB dışında yaşıyorsanız, '
                      'Avrupa\'daki alışverişlerinizin KDV\'sini geri '
                      'alabilirsiniz. Ülkeye dokunarak adım adım rehberi açın.'
                  : 'Tax-free shopping: if you live outside the EU, you can '
                      'reclaim the VAT on your European purchases. Tap a '
                      'country to open the step-by-step guide.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One expandable country card.
class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.info,
    required this.isTr,
    required this.expanded,
    required this.onTap,
  });

  final TaxFreeCountryInfo info;
  final bool isTr;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = isTr ? info.nameTr : info.nameEn;
    final refundRange = isTr ? info.refundRangeTr : info.refundRangeEn;
    final notes = isTr ? info.notesTr : info.notesEn;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded
              ? AppColors.brandTeal.withValues(alpha: 0.5)
              : AppColors.divider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: flag + name + chevron
                Row(
                  children: [
                    Text(info.flag, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTextStyles.titleLarge),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _Chip(
                                icon: Icons.payments_outlined,
                                label: isTr
                                    ? 'Min ${info.minimumLabel}'
                                    : 'Min ${info.minimumLabel}',
                              ),
                              const SizedBox(width: 8),
                              _Chip(
                                icon: Icons.undo,
                                label: refundRange,
                                accent: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Expanded content
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          height: 1,
                          color: AppColors.divider,
                        ),
                      ),

                      // Refund companies
                      Text(
                        isTr ? 'İADE ŞİRKETLERİ' : 'REFUND COMPANIES',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.brandTeal),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final company in info.companyList)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.brandNavyLight,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppColors.divider),
                              ),
                              child: Text(
                                company,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Step-by-step guide
                      Text(
                        isTr ? 'ADIM ADIM' : 'STEP BY STEP',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.brandTeal),
                      ),
                      const SizedBox(height: 8),
                      for (final entry
                          in info.stepList(isTr).asMap().entries)
                        _StepRow(
                          index: entry.key + 1,
                          text: _stripLeadingNumber(entry.value),
                        ),

                      // Notes
                      if (notes != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  AppColors.info.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  color: AppColors.info, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  notes,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Steps in the data already start with '1.', '2.'… — strip that so the
  /// numbered badge is the single source of numbering.
  static String _stripLeadingNumber(String step) {
    final match = RegExp(r'^\d+\.\s*').firstMatch(step);
    return match == null ? step : step.substring(match.end);
  }
}

/// Small metadata chip (minimum purchase / refund range).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.brandTeal : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: color,
            fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// One numbered step in the expanded guide.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.brandTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
