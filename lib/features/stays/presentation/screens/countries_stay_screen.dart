import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/countries/domain/country_data.dart';
import '../../domain/stay_record.dart';
import '../stays_provider.dart';

// ---------------------------------------------------------------------------
// Visa-free day limits for countries where we know the cap.
// Schengen countries are handled separately (90/180 rule).
// ---------------------------------------------------------------------------

const _visaFreeDays = <String, int>{
  'GE': 365, // Georgia — 1 year
  'AZ': 90,
  'ME': 90,
  'RS': 90,
  'BA': 90,
  'MK': 90,
  'XK': 90,
  'MD': 90,
  'UA': 90,
  'AL': 90,
  'AE': 30,
  'TH': 30,
  'ID': 30,
};

final _dateFmt = DateFormat('d MMM yyyy');

// ---------------------------------------------------------------------------
// Grouped country data
// ---------------------------------------------------------------------------

class _CountryGroup {
  _CountryGroup({
    required this.countryCode,
    required this.countryNameEn,
    required this.countryNameTr,
    required this.flag,
    required this.isSchengen,
    required this.totalDays,
    required this.earliestEntry,
    required this.latestExit,
    required this.ids,
  });

  final String countryCode;
  final String countryNameEn;
  final String countryNameTr;
  final String flag;
  final bool isSchengen;
  final int totalDays;
  final DateTime earliestEntry;
  final DateTime? latestExit; // null if any stay is ongoing
  final List<String> ids; // stay record ids
}

List<_CountryGroup> _buildGroups(List<StayRecord> stays) {
  final map = <String, List<StayRecord>>{};
  for (final s in stays) {
    map.putIfAbsent(s.countryCode, () => []).add(s);
  }

  final groups = <_CountryGroup>[];
  for (final entry in map.entries) {
    final code = entry.key;
    final records = entry.value;
    final vc = visaCountryByCode(code);

    final totalDays =
        records.fold<int>(0, (sum, r) => sum + r.daysSpent);
    final earliestEntry =
        records.map((r) => r.entryDate).reduce((a, b) => a.isBefore(b) ? a : b);
    final hasOngoing = records.any((r) => r.isOngoing);
    final DateTime? latestExit = hasOngoing
        ? null
        : records
            .map((r) => r.exitDate!)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    groups.add(
      _CountryGroup(
        countryCode: code,
        countryNameEn: records.first.countryNameEn,
        countryNameTr: records.first.countryNameTr,
        flag: vc?.flag ?? '🏳',
        isSchengen: vc?.isSchengen ?? false,
        totalDays: totalDays,
        earliestEntry: earliestEntry,
        latestExit: latestExit,
        ids: records.map((r) => r.id).toList(),
      ),
    );
  }

  // Sort by most recent entry date descending.
  groups.sort((a, b) => b.earliestEntry.compareTo(a.earliestEntry));
  return groups;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CountriesStayScreen extends ConsumerWidget {
  const CountriesStayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stays = ref.watch(staysProvider);
    final isTr = ref.watch(isTurkishProvider);
    final groups = _buildGroups(stays);

    final title =
        isTr ? 'Ülke Kalışları' : 'Country Stays';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        title: Text(
          groups.isEmpty ? title : '$title (${groups.length})',
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          if (stays.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.danger),
              tooltip: isTr ? 'Tümünü sil' : 'Delete all',
              onPressed: () => _confirmDeleteAll(context, ref, isTr),
            ),
        ],
      ),
      body: groups.isEmpty
          ? _EmptyState(isTr: isTr)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: groups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _CountryCard(
                group: groups[i],
                isTr: isTr,
                onDelete: () =>
                    _confirmDeleteGroup(context, ref, groups[i], isTr),
              ),
            ),
    );
  }

  Future<void> _confirmDeleteAll(
      BuildContext context, WidgetRef ref, bool isTr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          isTr ? 'Tüm kayıtlar silinsin mi?' : 'Delete all records?',
          style: AppTextStyles.titleLarge,
        ),
        content: Text(
          isTr
              ? 'Bu işlem geri alınamaz.'
              : 'This action cannot be undone.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isTr ? 'İptal' : 'Cancel',
              style:
                  AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style:
                  AppTextStyles.labelLarge.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(staysProvider.notifier).deleteAll();
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref,
      _CountryGroup group, bool isTr) async {
    final countryName =
        isTr ? group.countryNameTr : group.countryNameEn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          isTr
              ? '$countryName kayıtları silinsin mi?'
              : 'Delete $countryName records?',
          style: AppTextStyles.titleLarge,
        ),
        content: Text(
          isTr
              ? 'Bu ülkeye ait tüm kalış kayıtları silinecek.'
              : 'All stay records for this country will be removed.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isTr ? 'İptal' : 'Cancel',
              style:
                  AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style:
                  AppTextStyles.labelLarge.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final id in group.ids) {
        await ref.read(staysProvider.notifier).delete(id);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Country card
// ---------------------------------------------------------------------------

class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.group,
    required this.isTr,
    required this.onDelete,
  });

  final _CountryGroup group;
  final bool isTr;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final countryName =
        isTr ? group.countryNameTr : group.countryNameEn;
    final dateRange =
        '${_dateFmt.format(group.earliestEntry)} – ${group.latestExit != null ? _dateFmt.format(group.latestExit!) : (isTr ? 'Devam ediyor' : 'Ongoing')}';

    final visaLimit = _visaFreeDays[group.countryCode.toUpperCase()];
    final remaining =
        visaLimit != null ? visaLimit - group.totalDays : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: flag + name + delete
          Row(
            children: [
              Text(group.flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(countryName, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.textMuted,
                splashRadius: 20,
                onPressed: onDelete,
                tooltip: isTr ? 'Sil' : 'Delete',
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),

          // Days spent
          _InfoRow(
            label: isTr ? 'Toplam gün:' : 'Total days:',
            value: '${group.totalDays}',
            valueColor: AppColors.brandTeal,
          ),

          // Visa-free limit row
          if (group.isSchengen) ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: isTr ? 'Kural:' : 'Rule:',
              value: isTr
                  ? 'Schengen 90/180 kuralı geçerlidir'
                  : 'Schengen 90/180 rule applies',
              valueColor: AppColors.warning,
            ),
          ] else if (visaLimit != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: isTr ? 'Geçerli vize süresi:' : 'Visa-free limit:',
              value: isTr
                  ? '$visaLimit gün'
                  : '$visaLimit days',
              valueColor: AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            _InfoRow(
              label: isTr ? 'Kalan hak:' : 'Days remaining:',
              value: remaining != null && remaining > 0
                  ? isTr
                      ? '$remaining gün'
                      : '$remaining days'
                  : isTr
                      ? 'Süre doldu'
                      : 'Limit reached',
              valueColor: (remaining != null && remaining > 0)
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.labelLarge
              .copyWith(color: valueColor ?? AppColors.textPrimary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isTr});

  final bool isTr;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight_land_rounded,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              isTr ? 'Henüz kalış kaydı yok' : 'No stay records yet',
              style: AppTextStyles.titleLarge
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTr
                  ? 'Konum izni verdiğinizde ülke kalışlarınız otomatik izlenir.'
                  : 'Grant location permission and country stays will be tracked automatically.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
