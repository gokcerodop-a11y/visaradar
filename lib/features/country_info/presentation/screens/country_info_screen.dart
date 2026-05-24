import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/country_code_badge.dart';
import '../../domain/models/country_profile.dart';
import '../providers/country_info_provider.dart';

class CountryInfoScreen extends ConsumerWidget {
  const CountryInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeCountryProfileProvider);
    final countryCode = ref.watch(activeCountryCodeProvider);
    final countryName = ref.watch(activeCountryNameProvider);
    final isTr = ref.watch(isTurkishProvider);

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        title: Text(
          countryName ?? (isTr ? 'Ülke' : 'Country'),
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          if (countryCode != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: CountryCodeBadge(
                  code: countryCode,
                  size: BadgeSize.small,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: profile != null
            ? _CountryBody(profile: profile, isTr: isTr)
            : countryCode != null
                ? _ComingSoonBody(
                    countryCode: countryCode,
                    countryName: countryName,
                    isTr: isTr,
                  )
                : _EmptyState(isTr: isTr),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full country body — shown when seed data exists
// ---------------------------------------------------------------------------

class _CountryBody extends StatelessWidget {
  const _CountryBody({required this.profile, required this.isTr});

  final CountryProfile profile;
  final bool isTr;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(profile: profile, isTr: isTr),
          const SizedBox(height: 12),
          _BulletCard(
            icon: Icons.badge_outlined,
            title: isTr ? 'Giriş ve Kalış' : 'Entry & Stay',
            bullets: profile.entryNotes,
          ),
          const SizedBox(height: 12),
          _BulletCard(
            icon: Icons.directions_car_outlined,
            title: isTr ? 'Ulaşım ve Sınır' : 'Transport & Border',
            bullets: profile.transportNotes,
          ),
          const SizedBox(height: 12),
          _BulletCard(
            icon: Icons.payments_outlined,
            title: isTr ? 'Para ve Ödeme' : 'Money & Payments',
            bullets: profile.moneyNotes,
          ),
          const SizedBox(height: 12),
          _BulletCard(
            icon: Icons.signal_cellular_alt_outlined,
            title: isTr ? 'Bağlantı' : 'Connectivity',
            bullets: profile.connectivityNotes,
          ),
          const SizedBox(height: 12),
          _BulletCard(
            icon: Icons.local_hospital_outlined,
            title: isTr ? 'Güvenlik ve Acil Durum' : 'Safety & Emergency',
            bullets: profile.safetyNotes,
          ),
          const SizedBox(height: 12),
          _WeatherCard(isTr: isTr),
          const SizedBox(height: 12),
          _BulletCard(
            icon: Icons.lightbulb_outline,
            title: isTr ? 'Seyahat İpuçları' : 'Traveler Tips',
            bullets: profile.localTips,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.profile, required this.isTr});

  final CountryProfile profile;
  final bool isTr;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CountryCodeBadge(code: profile.isoCode, size: BadgeSize.large),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  profile.name,
                  style: AppTextStyles.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: profile.isSchengen
                      ? Icons.verified_outlined
                      : Icons.remove_circle_outline,
                  label: 'Schengen',
                  value: profile.isSchengen
                      ? (isTr ? 'Üye' : 'Member')
                      : (isTr ? 'Üye değil' : 'Non-member'),
                  valueColor: profile.isSchengen
                      ? AppColors.brandTeal
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.attach_money_outlined,
                  label: isTr ? 'Para birimi' : 'Currency',
                  value: profile.currencyDisplay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bullet card — used for every content section
// When bullets is empty, shows the "Coming soon" treatment instead.
// ---------------------------------------------------------------------------

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.icon,
    required this.title,
    required this.bullets,
  });

  final IconData icon;
  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final hasContent = bullets.isNotEmpty;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandTeal, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTextStyles.titleLarge),
              ),
              if (!hasContent) _ComingSoonBadge(),
            ],
          ),
          if (hasContent) ...[
            const SizedBox(height: 14),
            ...bullets.map((b) => _BulletRow(text: b)),
          ],
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brandTeal.withAlpha(160),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weather card — premium coming-soon placeholder
// ---------------------------------------------------------------------------

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.isTr});

  final bool isTr;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  color: AppColors.brandTeal, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTr ? 'Hava ve Hava Kalitesi' : 'Weather & Air Quality',
                  style: AppTextStyles.titleLarge,
                ),
              ),
              const _ComingSoonBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _WeatherPlaceholder(
                      label: isTr ? 'Sıcaklık' : 'Temperature')),
              const SizedBox(width: 8),
              Expanded(
                  child: _WeatherPlaceholder(
                      label: isTr ? 'UV İndeksi' : 'UV Index')),
              const SizedBox(width: 8),
              Expanded(
                  child: _WeatherPlaceholder(
                      label: isTr ? 'Hava Kalitesi' : 'Air Quality')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherPlaceholder extends StatelessWidget {
  const _WeatherPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coming-soon badge (inline pill)
// ---------------------------------------------------------------------------

class _ComingSoonBadge extends ConsumerWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isTr ? 'Yakında' : 'Coming soon',
        style: AppTextStyles.caption.copyWith(color: AppColors.brandTeal),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coming-soon body — country is known but not yet in seed data
// ---------------------------------------------------------------------------

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody({
    required this.countryCode,
    required this.isTr,
    this.countryName,
  });

  final String countryCode;
  final String? countryName;
  final bool isTr;

  @override
  Widget build(BuildContext context) {
    final displayName = countryName ?? countryCode;
    final sectionTitles = isTr
        ? const [
            'Giriş ve Kalış',
            'Ulaşım ve Sınır',
            'Para ve Ödeme',
            'Bağlantı',
            'Güvenlik ve Acil Durum',
            'Seyahat İpuçları',
          ]
        : const [
            'Entry & Stay',
            'Transport & Border',
            'Money & Payments',
            'Connectivity',
            'Safety & Emergency',
            'Traveler Tips',
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Partial header
          _Card(
            child: Row(
              children: [
                CountryCodeBadge(code: countryCode, size: BadgeSize.large),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.displayMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        countryCode,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Coming-soon notice card
          _Card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.travel_explore,
                    color: AppColors.brandTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTr
                            ? 'Daha fazla destinasyon yakında'
                            : 'More destinations coming soon',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isTr
                            ? '$displayName için ayrıntılı bilgi hazırlanıyor. '
                                'Her güncellemeyle yeni ülke paketleri ekleniyor.'
                            : 'Detailed info for $displayName is being prepared. '
                                'New country packs are added with each update.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Skeleton cards to show what's coming
          ...sectionTitles.map(
            (title) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Card(
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: AppColors.textMuted, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isTr ? 'Yakında' : 'Soon',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — no active trip and no GPS country
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isTr});

  final bool isTr;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(
                Icons.flag_outlined,
                color: AppColors.textMuted,
                size: 34,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isTr ? 'Ülke seçilmedi' : 'No country selected',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isTr
                  ? 'Giriş kuralları, ulaşım ipuçları, acil durum iletişimleri ve yerel bilgileri görmek için bir seyahat ekleyin.'
                  : 'Log a trip to see entry rules, transport tips, emergency contacts, and local insights for your destination.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => context.push('/trips/add'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.brandTeal.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add,
                        color: AppColors.brandTeal, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isTr ? 'Seyahat ekle' : 'Log a trip',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.brandTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card atom
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}
