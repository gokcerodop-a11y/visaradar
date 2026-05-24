import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/locale.dart';
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
    final isTr = ref.watch(isTurkishProvider);

    final nationalityLabel = profile.nationalityLabel;
    final passportLabel = _passportLabel(profile.passportType, isTr);
    final profileSubtitle = nationalityLabel != null
        ? '$nationalityLabel · $passportLabel'
        : passportLabel;

    final langLabel = _langLabel(profile.preferredLocale, isTr);

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        title: Text(isTr ? 'Ayarlar' : 'Settings'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),

            // ── Brand hero ────────────────────────────────────────────────
            _HeroCard(
              isTr: isTr,
              onTap: () => context.push(
                '${AppRoutes.legalText}?title=About+VisaRadar&type=about',
              ),
            ),
            const SizedBox(height: 20),

            // ── Account ──────────────────────────────────────────────────
            _SettingsSection(
              title: isTr ? 'Hesap' : 'Account',
              items: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: isTr ? 'Seyahat Profili' : 'Travel Profile',
                  value: profileSubtitle,
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Preferences ───────────────────────────────────────────────
            _SettingsSection(
              title: isTr ? 'Tercihler' : 'Preferences',
              items: [
                _SettingsTile(
                  icon: Icons.language,
                  title: isTr ? 'Dil' : 'Language',
                  value: langLabel,
                  onTap: () => context.push(AppRoutes.languageSettings),
                ),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: isTr ? 'Bildirimler' : 'Notifications',
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Privacy & Legal ───────────────────────────────────────────
            _SettingsSection(
              title: isTr ? 'Gizlilik ve Yasal' : 'Privacy & Legal',
              items: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: isTr ? 'Gizlilik Politikası' : 'Privacy Policy',
                  onTap: () => _openLegal(
                    context,
                    url: AppConstants.privacyPolicyUrl,
                    fallback:
                        '${AppRoutes.legalText}?title=Privacy+Policy&type=privacy',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: isTr ? 'Kullanım Şartları' : 'Terms of Service',
                  onTap: () => _openLegal(
                    context,
                    url: AppConstants.termsUrl,
                    fallback:
                        '${AppRoutes.legalText}?title=Terms+of+Service&type=terms',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: isTr ? 'VisaRadar Hakkında' : 'About VisaRadar',
                  value: 'v${AppConstants.appVersion}',
                  onTap: () => context.push(
                    '${AppRoutes.legalText}?title=About+VisaRadar&type=about',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Help & Diagnostics ────────────────────────────────────────
            _SettingsSection(
              title: isTr ? 'Yardım ve Tanılama' : 'Help & Diagnostics',
              items: [
                _SettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: isTr ? 'Tanılama' : 'Diagnostics',
                  onTap: () => context.push(AppRoutes.diagnostics),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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

  String _passportLabel(PassportType type, bool isTr) {
    switch (type) {
      case PassportType.ordinary:
        return isTr ? 'Umuma mahsus' : 'Ordinary';
      case PassportType.euEeaSwiss:
        return isTr ? 'AB/AEA/İsviçre' : 'EU/EEA/Swiss';
      case PassportType.diplomatic:
        return isTr ? 'Diplomatik' : 'Diplomatic';
      case PassportType.serviceOfficial:
        return isTr ? 'Hizmet/Hususi' : 'Service/Official';
      case PassportType.special:
        return isTr ? 'Özel' : 'Special';
    }
  }

  String _langLabel(String? locale, bool isTr) {
    switch (locale) {
      case 'en':
        return 'English';
      case 'tr':
        return 'Türkçe';
      default:
        return isTr ? 'Otomatik' : 'Automatic';
    }
  }
}

// ---------------------------------------------------------------------------
// Brand hero card — informational only (no commerce / no subscription claims)
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isTr, required this.onTap});

  final bool isTr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brandTeal.withAlpha(50)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceCard,
              AppColors.brandTeal.withAlpha(10),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.brandTeal.withAlpha(60)),
                  ),
                  child: const Icon(Icons.radar,
                      color: AppColors.brandTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VisaRadar',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTr
                            ? 'Nerede olduğunuzu tam olarak bilin.'
                            : 'Know exactly where you stand.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),
            _HeroFeatureRow(
              icon: Icons.timer_outlined,
              label: isTr
                  ? '90/180 günlük Schengen hesaplayıcı'
                  : 'Accurate 90/180-day Schengen calculator',
            ),
            const SizedBox(height: 10),
            _HeroFeatureRow(
              icon: Icons.notifications_outlined,
              label: isTr
                  ? 'Süreniz bitmeden önce uyarılar'
                  : 'Alerts before your allowance runs out',
            ),
            const SizedBox(height: 10),
            _HeroFeatureRow(
              icon: Icons.lock_outline,
              label: isTr
                  ? 'Verileriniz yalnızca cihazınızda kalır'
                  : 'Your data stays on your device only',
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFeatureRow extends StatelessWidget {
  const _HeroFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.brandTeal.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.brandTeal, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
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
