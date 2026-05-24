import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/travel_entry.dart';
import '../providers/trips_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final isTr = ref.watch(isTurkishProvider);

    // Sort: most recent entry date first
    final sorted = [...trips]
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

    final tripsLabel = isTr ? 'Seyahatler' : 'Trips';

    return Scaffold(
      appBar: AppBar(
        title: sorted.isEmpty
            ? Text(tripsLabel)
            : Text('$tripsLabel (${sorted.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: isTr ? 'Seyahat ekle' : 'Add trip',
            onPressed: () => context.push('/trips/add'),
          ),
        ],
      ),
      body: sorted.isEmpty
          ? _EmptyState(
              isTr: isTr,
              onAdd: () => context.push('/trips/add'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _TripCard(
                entry: sorted[i],
                isTr: isTr,
                onDelete: () =>
                    ref.read(tripsProvider.notifier).delete(sorted[i].id),
                onEdit: () => context.push('/trips/edit/${sorted[i].id}'),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isTr, required this.onAdd});
  final bool isTr;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandTeal.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flight_outlined,
                  color: AppColors.brandTeal, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              isTr ? 'Henüz seyahat yok' : 'No trips yet',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isTr
                  ? 'Schengen günlerini takip etmek için sınır geçişlerinizi kaydedin.'
                  : 'Log your border crossings to track Schengen days and stay compliant.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                isTr ? 'İlk seyahatinizi ekleyin' : 'Add your first trip',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip card
// ---------------------------------------------------------------------------

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.entry,
    required this.isTr,
    required this.onDelete,
    required this.onEdit,
  });

  final TravelEntry entry;
  final bool isTr;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final entryStr = _dateFmt.format(entry.entryDate.toLocal());
    final exitStr = entry.exitDate != null
        ? _dateFmt.format(entry.exitDate!.toLocal())
        : (isTr ? 'Devam ediyor' : 'Ongoing');
    final days = entry.daysSpent;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Schengen badge / flag area
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.isSchengen
                      ? AppColors.brandTeal.withAlpha(22)
                      : AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: entry.isSchengen
                        ? AppColors.brandTeal.withAlpha(80)
                        : AppColors.divider,
                  ),
                ),
                child: Center(
                  child: Text(
                    _flagEmoji(entry.country),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.countryLabel ?? entry.country,
                            style: AppTextStyles.bodyLarge
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (entry.isOngoing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brandTeal.withAlpha(22),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.brandTeal.withAlpha(60)),
                            ),
                            child: Text(
                              isTr ? 'Devam ediyor' : 'Ongoing',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.brandTeal),
                            ),
                          )
                        else if (entry.isSchengen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brandTeal.withAlpha(22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Schengen',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.brandTeal),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.isOngoing
                          ? (isTr ? '$entryStr tarihinden beri' : 'From $entryStr')
                          : '$entryStr → $exitStr',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.note!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$days',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: entry.isOngoing
                          ? AppColors.brandTeal
                          : entry.isSchengen
                              ? AppColors.brandTeal
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    entry.isOngoing
                        ? (isTr
                            ? (days == 1 ? 'gün şu ana kadar' : 'gün şu ana kadar')
                            : (days == 1 ? 'day so far' : 'days so far'))
                        : (isTr
                            ? (days == 1 ? 'gün' : 'gün')
                            : (days == 1 ? 'day' : 'days')),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(isTr ? 'Seyahati sil?' : 'Delete trip?'),
        content: Text(
          isTr
              ? '${entry.countryLabel ?? entry.country} seyahati silinecek.'
              : 'This will remove the trip to ${entry.countryLabel ?? entry.country}.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isTr ? 'Vazgeç' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// Country code → flag emoji (regional indicator symbols)
String _flagEmoji(String code) {
  if (code.length != 2) return '🌍';
  final base = 0x1F1E6 - 0x41; // 'A' offset
  final chars = code.toUpperCase().codeUnits;
  return String.fromCharCode(base + chars[0]) +
      String.fromCharCode(base + chars[1]);
}
