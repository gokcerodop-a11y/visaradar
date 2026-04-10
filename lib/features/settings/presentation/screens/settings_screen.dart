import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    final nationalityLabel = profile.nationalityLabel;
    final passportLabel = _passportLabel(profile.passportType);
    final profileSubtitle = nationalityLabel != null
        ? '$nationalityLabel · $passportLabel'
        : passportLabel;

    final langLabel = _langLabel(profile.preferredLocale);

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),

            // ── Membership card ──────────────────────────────────────────
            _MembershipCard(),
            const SizedBox(height: 24),

            // ── Account ──────────────────────────────────────────────────
            _SettingsSection(
              title: 'Account',
              items: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Travel Profile',
                  value: profileSubtitle,
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Preferences ───────────────────────────────────────────────
            _SettingsSection(
              title: 'Preferences',
              items: [
                _SettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  value: langLabel,
                  onTap: () => context.push(AppRoutes.languageSettings),
                ),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Privacy & Legal ───────────────────────────────────────────
            _SettingsSection(
              title: 'Privacy & Legal',
              items: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => _openLegal(
                    context,
                    url: AppConstants.privacyPolicyUrl,
                    fallback:
                        '${AppRoutes.legalText}?title=Privacy+Policy&type=privacy',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => _openLegal(
                    context,
                    url: AppConstants.termsUrl,
                    fallback:
                        '${AppRoutes.legalText}?title=Terms+of+Service&type=terms',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About VisaRadar',
                  value: 'v${AppConstants.appVersion}',
                  onTap: () => context.push(
                    '${AppRoutes.legalText}?title=About+VisaRadar&type=about',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Open a legal document.
  /// If [url] is non-empty and launchable, opens it in the system browser.
  /// Otherwise falls back to the in-app legal screen at [fallback].
  Future<void> _openLegal(
    BuildContext context, {
    required String url,
    required String fallback,
  }) async {
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (context.mounted) context.push(fallback);
  }

  String _passportLabel(PassportType type) {
    switch (type) {
      case PassportType.ordinary:
        return 'Ordinary';
      case PassportType.euEeaSwiss:
        return 'EU/EEA/Swiss';
      case PassportType.diplomatic:
        return 'Diplomatic';
      case PassportType.serviceOfficial:
        return 'Service/Official';
      case PassportType.special:
        return 'Special';
    }
  }

  String _langLabel(String? locale) {
    switch (locale) {
      case 'en':
        return 'English';
      case 'tr':
        return 'Türkçe';
      default:
        return 'Automatic';
    }
  }
}

// ---------------------------------------------------------------------------
// Membership Card
// ---------------------------------------------------------------------------

class _MembershipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.subscription),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brandTeal.withAlpha(60)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceCard,
              AppColors.brandTeal.withAlpha(12),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.brandTeal.withAlpha(60)),
                  ),
                  child: const Icon(Icons.radar,
                      color: AppColors.brandTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VisaRadar Premium',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StatusBadge(),
                  ],
                ),
                const Spacer(),
                Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 20),
              ],
            ),
            const SizedBox(height: 16),

            // Divider
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),

            // Trial info + pricing
            Text(
              '${AppConstants.trialDays}-day free trial, then:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PricePill(
                  icon: Icons.location_on,
                  label: '₺${AppConstants.priceTryMonthly.toStringAsFixed(0)} / mo',
                ),
                const SizedBox(width: 8),
                _PricePill(
                  icon: Icons.public,
                  label: '€${AppConstants.priceEurMonthly.toStringAsFixed(2)} / mo',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CTA button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.subscription),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: AppColors.brandNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Start Free Trial',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.brandNavy,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandTeal.withAlpha(70)),
      ),
      child: Text(
        'Trial',
        style: AppTextStyles.caption.copyWith(color: AppColors.brandTeal),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.brandTeal),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Section
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(letterSpacing: 1.2),
          ),
        ),
        Card(
          child: Column(
            children: items.expand((item) sync* {
              yield item;
              if (item != items.last) {
                yield const Divider(height: 0, indent: 52);
              }
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Tile
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: value != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 16),
              ],
            )
          : const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
