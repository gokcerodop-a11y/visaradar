import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/location_proof_service.dart';
import '../../domain/models/location_proof_entry.dart';

/// "Derin Bilgi" (Location Proof) screen — [AppRoutes.locationProof].
///
/// Read-only view of the SHA-256 location proof chain: explains the feature,
/// lists recorded locations grouped by day, and offers export / verify
/// actions. Recording itself is done elsewhere by a background service; this
/// screen never triggers a capture.
class LocationProofScreen extends ConsumerStatefulWidget {
  const LocationProofScreen({super.key});

  @override
  ConsumerState<LocationProofScreen> createState() =>
      _LocationProofScreenState();
}

class _LocationProofScreenState extends ConsumerState<LocationProofScreen> {
  static const _monoStyle = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: ['Courier New', 'monospace'],
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.brandTeal,
    letterSpacing: 0.6,
  );

  List<LocationProofEntry>? _entries;
  bool? _chainValid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(locationProofServiceProvider);
    final entries = await service.getEntries();
    final valid = await service.verifyChain();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _chainValid = valid;
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() => _busy = true);
    final valid = await ref.read(locationProofServiceProvider).verifyChain();
    if (!mounted) return;
    setState(() {
      _chainValid = valid;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: valid ? AppColors.success : AppColors.danger,
        content: Text(
          valid
              ? L.t(
                  'Chain verified: all records are intact.',
                  'Zincir doğrulandı: tüm kayıtlar sağlam.',
                )
              : L.t(
                  'Chain broken: records have been tampered with.',
                  'Zincir bozuk: kayıtlarda oynama tespit edildi.',
                ),
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _export() async {
    final entries = _entries ?? const <LocationProofEntry>[];
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceCard,
          content: Text(
            L.t('No records to export yet.',
                'Henüz dışa aktarılacak kayıt yok.'),
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
      return;
    }
    final text =
        ref.read(locationProofServiceProvider).exportAsText(entries);
    await Share.share(
      text,
      subject: L.t(
        'VisaRadar Location Proof Report',
        'VisaRadar Konum Kanıtı Raporu',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on locale change so L.t strings refresh.
    ref.watch(isTurkishProvider);
    final entries = _entries;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        title: Text(
          L.t('Deep Record', 'Derin Bilgi'),
          style: AppTextStyles.headlineMedium,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        bottom: false,
        child: entries == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brandTeal),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildHeader(entries),
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  if (entries.isEmpty)
                    _buildEmptyState()
                  else
                    ..._buildTimeline(entries),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(List<LocationProofEntry> entries) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L.t('Location Proof', 'Konum Kanıtı'),
                style: AppTextStyles.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                L.t(
                  '${entries.length} records · SHA-256 chain',
                  '${entries.length} kayıt · SHA-256 zinciri',
                ),
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        if (_chainValid != null) _buildChainBadge(_chainValid!),
      ],
    );
  }

  Widget _buildChainBadge(bool valid) {
    final color = valid ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            valid ? Icons.verified_outlined : Icons.gpp_bad_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            valid
                ? L.t('Chain Verified', 'Zincir Doğrulandı')
                : L.t('Chain Broken', 'Zincir Bozuk'),
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandTeal.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppColors.brandTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                L.t('What is this?', 'Bu Nedir?'),
                style: AppTextStyles.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            L.t(
              'Every location is recorded and secured with an immutable '
              'SHA-256 hash chain. It provides strong supporting evidence '
              'for visa applications, insurance claims and legal '
              'proceedings.',
              'Her konumunuz kayıt altına alınır ve değiştirilemez SHA-256 '
              'hash zinciriyle güvence altına alınır. Visa başvuruları, '
              'sigorta talepleri ve hukuki süreçlerde güçlü destekleyici '
              'kanıt sağlar.',
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  L.t(
                    'NOTE: These records constitute strong supporting '
                    'evidence; however, they are not a notarized official '
                    'document.',
                    'NOT: Bu kayıtlar güçlü destekleyici kanıt '
                    'niteliğindedir; ancak noterin onayladığı resmi belge '
                    'değildir.',
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.travel_explore,
                color: AppColors.brandTeal, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            L.t('No records yet.', 'Henüz kayıt yok.'),
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            L.t(
              'The app tracks your location automatically.',
              'Uygulama konumunuzu otomatik takip ediyor.',
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────

  /// Groups entries by local calendar day, newest day (and newest record)
  /// first, and renders one header + rows per day.
  List<Widget> _buildTimeline(List<LocationProofEntry> entries) {
    final groups = <DateTime, List<LocationProofEntry>>{};
    for (final e in entries) {
      final local = e.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => <LocationProofEntry>[]).add(e);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final day in days) {
      final dayEntries = groups[day]!
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      widgets
        ..add(_buildDayHeader(day, dayEntries.length))
        ..add(const SizedBox(height: 8))
        ..add(
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < dayEntries.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 44),
                      color: AppColors.divider,
                    ),
                  _buildEntryRow(dayEntries[i]),
                ],
              ],
            ),
          ),
        )
        ..add(const SizedBox(height: 18));
    }
    return widgets;
  }

  Widget _buildDayHeader(DateTime day, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          Text(
            _dayLabel(day),
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.brandTeal),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
          const SizedBox(width: 8),
          Text(
            L.t('$count records', '$count kayıt'),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(LocationProofEntry entry) {
    final local = entry.timestamp.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';

    final place = [
      if (entry.city != null && entry.city!.isNotEmpty) entry.city,
      if (entry.country != null && entry.country!.isNotEmpty) entry.country,
    ].join(', ');
    final coords = '${entry.lat.toStringAsFixed(4)}, '
        '${entry.lng.toStringAsFixed(4)}';
    final hashTail = entry.hash.length >= 8
        ? entry.hash.substring(entry.hash.length - 8)
        : entry.hash;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.schedule,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          SizedBox(
            width: 42,
            child: Text(time, style: AppTextStyles.bodyMedium),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.place_outlined,
              size: 16, color: AppColors.brandTeal),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.isEmpty ? coords : place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
                if (place.isNotEmpty)
                  Text(
                    coords,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('#$hashTail', style: _monoStyle),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return L.t('Today', 'Bugün');
    if (day == today.subtract(const Duration(days: 1))) {
      return L.t('Yesterday', 'Dün');
    }
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const monthsTr = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final month = L.isTr ? monthsTr[day.month - 1] : monthsEn[day.month - 1];
    return L.isTr
        ? '${day.day} $month ${day.year}'
        : '$month ${day.day}, ${day.year}';
  }

  // ── Bottom bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brandNavyLight,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(L.t('Export', 'Dışa Aktar')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.labelLarge,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _verify,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandNavy,
                          ),
                        )
                      : const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(L.t('Verify', 'Doğrula')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    foregroundColor: AppColors.brandNavy,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.labelLarge,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
