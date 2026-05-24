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
            const SizedBox(height: 16),

            // ── Help & Diagnostics ────────────────────────────────────────
            _SettingsSection(
              title: 'Help & Diagnostics',
              items: [
                _SettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Diagnostics',
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
