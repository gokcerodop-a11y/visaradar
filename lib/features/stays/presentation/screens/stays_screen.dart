import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/countries/domain/country_data.dart';
import '../../../../features/location/presentation/providers/location_provider.dart';
import '../../domain/stay_record.dart';
import '../stays_provider.dart';

// Visa-free day limits for Turkish citizens (Turkish passport holders' home = TR).
const _visaFreeDays = {
  'GE': 365,
  'AZ': 90,
  'ME': 90,
  'RS': 90,
  'BA': 90,
  'MK': 90,
  'XK': 90,
  'MD': 90,
  'UA': 90,
  'AL': 90,
  'AD': 90,
  'AE': 30,
  'TH': 30,
  'ID': 30,
};

// Turkish citizens live in Turkey — no visa limit applies.
const _homeCountry = 'TR';

final _dateFmt = DateFormat('d MMM yyyy');

// ---------------------------------------------------------------------------
// Schengen 90/180 rolling-window calc from stay records
// ---------------------------------------------------------------------------

int _schengenDaysUsedFromStays(List<StayRecord> allStays) {
  final cutoff = DateTime.now().subtract(const Duration(days: 180));
  int total = 0;
  for (final s in allStays) {
    final vc = visaCountryByCode(s.countryCode);
    if (vc?.isSchengen != true) continue;
    final entry = s.entryDate;
    final exit = s.exitDate ?? DateTime.now();
    // Overlap with [cutoff, now]
    final from = entry.isAfter(cutoff) ? entry : cutoff;
    final to = exit;
    if (to.isAfter(from)) {
      total += to.difference(from).inDays;
    }
  }
  return total;
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class StaysScreen extends ConsumerStatefulWidget {
  const StaysScreen({super.key});

  @override
  ConsumerState<StaysScreen> createState() => _StaysScreenState();
}

class _StaysScreenState extends ConsumerState<StaysScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Trigger a fresh GPS detection so the current location is always recorded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).refreshDetection();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Ülke ve Şehir Kalışları' : 'Country & City Stays'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isTr ? 'Ülkeler' : 'Countries'),
            Tab(text: isTr ? 'Şehirler' : 'Cities'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CountriesTab(isTr: isTr),
          _CitiesTab(isTr: isTr),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Countries Tab
// ---------------------------------------------------------------------------

class _CountriesTab extends ConsumerWidget {
  const _CountriesTab({required this.isTr});
  final bool isTr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stays = ref.watch(staysProvider);

    if (stays.isEmpty) {
      return _emptyState(
        icon: Icons.flag_outlined,
        message: isTr
            ? 'Konum algılanıyor…\nGPS izniniz varsa ülkeniz otomatik kaydedilir.'
            : 'Detecting location…\nYour country is saved automatically when GPS resolves.',
      );
    }

    // Schengen days from auto-detected stays (rolling 180-day window)
    final schengenUsed = _schengenDaysUsedFromStays(stays);
    final schengenRemaining = (90 - schengenUsed).clamp(0, 90);

    // Group by countryCode
    final Map<String, List<StayRecord>> grouped = {};
    for (final s in stays) {
      grouped.putIfAbsent(s.countryCode, () => []).add(s);
    }

    // Sort by most recent entry
    final codes = grouped.keys.toList()
      ..sort((a, b) {
        final latA = grouped[a]!
            .map((s) => s.entryDate)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        final latB = grouped[b]!
            .map((s) => s.entryDate)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        return latB.compareTo(latA);
      });

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(locationProvider.notifier).refreshDetection();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: codes.length,
        itemBuilder: (_, i) {
          final code = codes[i];
          final group = grouped[code]!;
          final vc = visaCountryByCode(code);

          final totalDays = group.fold<int>(0, (sum, s) => sum + s.daysSpent);
          final latestEntry = group
              .map((s) => s.entryDate)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final hasOngoing = group.any((s) => s.isOngoing);

          // Remaining days label
          String? remainingLabel;
          Color remainingColor = AppColors.textMuted;

          if (code == _homeCountry) {
            // Home country — no limit
            remainingLabel = isTr ? '🏠 Ana ülke — süre sınırı yok' : '🏠 Home country — no limit';
            remainingColor = AppColors.brandTeal;
          } else if (vc?.isSchengen == true) {
            remainingLabel = isTr
                ? 'Schengen 90/180 — $schengenRemaining gün kaldı'
                : 'Schengen 90/180 — $schengenRemaining days left';
            remainingColor = schengenRemaining > 30
                ? AppColors.success
                : schengenRemaining > 10
                    ? AppColors.warning
                    : AppColors.danger;
          } else if (_visaFreeDays.containsKey(code)) {
            final max = _visaFreeDays[code]!;
            final rem = (max - totalDays).clamp(0, max);
            remainingLabel = isTr
                ? '$max günlük vize serbestisi — $rem gün kaldı'
                : '$max-day visa-free — $rem days remaining';
            remainingColor = rem > 30
                ? AppColors.success
                : rem > 7
                    ? AppColors.warning
                    : AppColors.danger;
          } else if (vc?.requiresVisaForTurkish == true) {
            remainingLabel = isTr ? 'Vize gerekli — süre vizende yazıyor' : 'Visa required — check your visa';
            remainingColor = AppColors.textMuted;
          }
          // else: unknown country — no label shown

          return _StayCard(
            key: ValueKey(code),
            leading: Text(
              vc?.flag ?? '🏳️',
              style: const TextStyle(fontSize: 32),
            ),
            title: isTr
                ? (vc?.nameTr ?? group.first.countryNameTr)
                : (vc?.nameEn ?? group.first.countryNameEn),
            subtitle: isTr
                ? 'Toplam $totalDays gün · Son giriş: ${_dateFmt.format(latestEntry)}'
                : 'Total $totalDays days · Last entry: ${_dateFmt.format(latestEntry)}',
            badge: hasOngoing ? (isTr ? 'Şu an burada' : 'Currently here') : null,
            remainingLabel: remainingLabel,
            remainingColor: remainingColor,
            onDelete: () => _confirmDelete(context, ref, isTr, group),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    bool isTr,
    List<StayRecord> group,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isTr ? 'Kaydı Sil' : 'Delete Record'),
        content: Text(
          isTr
              ? 'Bu ülkeye ait tüm kalış kayıtları silinecek. Bu işlem geri alınamaz.'
              : 'All stay records for this country will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isTr ? 'Vazgeç' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isTr ? 'Sil' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final notifier = ref.read(staysProvider.notifier);
      for (final s in group) {
        notifier.delete(s.id);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Cities Tab
// ---------------------------------------------------------------------------

class _CitiesTab extends ConsumerWidget {
  const _CitiesTab({required this.isTr});
  final bool isTr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stays = ref.watch(staysProvider);
    final cityStays = stays.where((s) => s.city != null && s.city!.isNotEmpty).toList();

    if (cityStays.isEmpty) {
      return _emptyState(
        icon: Icons.location_city_outlined,
        message: isTr
            ? 'Henüz şehir kaydı yok.\nGPS ile şehir algılandığında otomatik kaydedilir.'
            : 'No city records yet.\nDetected automatically when GPS resolves a city.',
      );
    }

    final Map<String, List<StayRecord>> grouped = {};
    for (final s in cityStays) {
      final key = '${s.city}|${s.countryCode}';
      grouped.putIfAbsent(key, () => []).add(s);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final latA = grouped[a]!
            .map((s) => s.entryDate)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        final latB = grouped[b]!
            .map((s) => s.entryDate)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        return latB.compareTo(latA);
      });

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(locationProvider.notifier).refreshDetection();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: keys.length,
        itemBuilder: (_, i) {
          final key = keys[i];
          final group = grouped[key]!;
          final first = group.first;
          final vc = visaCountryByCode(first.countryCode);

          final totalDays = group.fold<int>(0, (sum, s) => sum + s.daysSpent);
          final latestEntry = group
              .map((s) => s.entryDate)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final hasOngoing = group.any((s) => s.isOngoing);
          final countryName = isTr
              ? (vc?.nameTr ?? first.countryNameTr)
              : (vc?.nameEn ?? first.countryNameEn);

          return _StayCard(
            key: ValueKey(key),
            leading: Text(
              vc?.flag ?? '🏳️',
              style: const TextStyle(fontSize: 32),
            ),
            title: first.city!,
            subtitle: '$countryName · $totalDays ${isTr ? 'gün' : 'days'} · ${_dateFmt.format(latestEntry)}',
            badge: hasOngoing ? (isTr ? 'Şu an burada' : 'Currently here') : null,
            onDelete: () => _confirmDelete(context, ref, isTr, group),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    bool isTr,
    List<StayRecord> group,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isTr ? 'Kaydı Sil' : 'Delete Record'),
        content: Text(
          isTr
              ? 'Bu şehre ait tüm kalış kayıtları silinecek. Bu işlem geri alınamaz.'
              : 'All stay records for this city will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isTr ? 'Vazgeç' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isTr ? 'Sil' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final notifier = ref.read(staysProvider.notifier);
      for (final s in group) {
        notifier.delete(s.id);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared card widget
// ---------------------------------------------------------------------------

class _StayCard extends StatelessWidget {
  const _StayCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.badge,
    this.remainingLabel,
    this.remainingColor,
    required this.onDelete,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? badge;
  final String? remainingLabel;
  final Color? remainingColor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                if (remainingLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    remainingLabel!,
                    style: AppTextStyles.caption.copyWith(
                      color: remainingColor ?? AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty state
// ---------------------------------------------------------------------------

Widget _emptyState({required IconData icon, required String message}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}
