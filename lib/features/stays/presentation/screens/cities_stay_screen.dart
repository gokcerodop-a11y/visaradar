import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/countries/domain/country_data.dart';
import '../../domain/stay_record.dart';
import '../stays_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');

// ---------------------------------------------------------------------------
// Grouped city data
// ---------------------------------------------------------------------------

class _CityGroup {
  _CityGroup({
    required this.city,
    required this.countryCode,
    required this.flag,
    required this.totalDays,
    required this.earliestEntry,
    required this.latestExit,
    required this.ids,
  });

  final String city;
  final String countryCode;
  final String flag;
  final int totalDays;
  final DateTime earliestEntry;
  final DateTime? latestExit; // null if any stay is ongoing
  final List<String> ids;
}

List<_CityGroup> _buildGroups(List<StayRecord> stays) {
  // Only include stays that have a city set.
  final withCity = stays.where((r) => r.city != null && r.city!.isNotEmpty);

  final map = <String, List<StayRecord>>{};
  for (final s in withCity) {
    // Key by city + countryCode to avoid collision (e.g., same city name in
    // different countries).
    final key = '${s.city}|${s.countryCode}';
    map.putIfAbsent(key, () => []).add(s);
  }

  final groups = <_CityGroup>[];
  for (final entry in map.entries) {
    final records = entry.value;
    final code = records.first.countryCode;
    final vc = visaCountryByCode(code);

    final totalDays =
        records.fold<int>(0, (sum, r) => sum + r.daysSpent);
    final earliestEntry = records
        .map((r) => r.entryDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final hasOngoing = records.any((r) => r.isOngoing);
    final DateTime? latestExit = hasOngoing
        ? null
        : records
            .map((r) => r.exitDate!)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    groups.add(
      _CityGroup(
        city: records.first.city!,
        countryCode: code,
        flag: vc?.flag ?? '🏳',
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

class CitiesStayScreen extends ConsumerWidget {
  const CitiesStayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stays = ref.watch(staysProvider);
    final isTr = ref.watch(isTurkishProvider);
    final groups = _buildGroups(stays);

    final title = isTr ? 'Şehir Kalışları' : 'City Stays';

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
              itemBuilder: (ctx, i) => _CityCard(
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
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.danger),
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
      _CityGroup group, bool isTr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          isTr
              ? '${group.city} kayıtları silinsin mi?'
              : 'Delete ${group.city} records?',
          style: AppTextStyles.titleLarge,
        ),
        content: Text(
          isTr
              ? 'Bu şehre ait tüm kalış kayıtları silinecek.'
              : 'All stay records for this city will be removed.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isTr ? 'İptal' : 'Cancel',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.danger),
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
// City card
// ---------------------------------------------------------------------------

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.group,
    required this.isTr,
    required this.onDelete,
  });

  final _CityGroup group;
  final bool isTr;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${_dateFmt.format(group.earliestEntry)} – ${group.latestExit != null ? _dateFmt.format(group.latestExit!) : (isTr ? 'Devam ediyor' : 'Ongoing')}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: flag + city + country + delete
          Row(
            children: [
              Text(group.flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.city, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      group.countryCode,
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

          // Date range
          _InfoRow(
            label: isTr ? 'Tarih aralığı:' : 'Date range:',
            value: dateRange,
            valueColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 6),

          // Days spent
          _InfoRow(
            label: isTr ? 'Toplam gün:' : 'Total days:',
            value: '${group.totalDays}',
            valueColor: AppColors.brandTeal,
          ),
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
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.labelLarge
                .copyWith(color: valueColor ?? AppColors.textPrimary),
            textAlign: TextAlign.end,
          ),
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
            const Icon(Icons.location_city_rounded,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              isTr ? 'Henüz şehir kaydı yok' : 'No city records yet',
              style: AppTextStyles.titleLarge
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTr
                  ? 'Şehir bilgisiyle kaydedilen kalışlar burada görünür.'
                  : 'Stays recorded with a city will appear here.',
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
