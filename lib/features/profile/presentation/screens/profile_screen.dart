import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../services/premium_providers.dart';
import '../../../assistant/assistant_controller.dart';
import '../../../paywall/paywall_screen.dart';
import '../../../scanner/document_scanner_screen.dart';
import '../../domain/models/user_profile.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = ref.watch(isTurkishProvider);
    final profile = ref.watch(profileProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isTr ? 'Profil' : 'Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _passportCard(context, profile, isTr),
          const SizedBox(height: 16),
          _premiumCard(context, isPremium, ref, isTr),
          const SizedBox(height: 16),
          _sectionLabel(isTr ? 'Premium araçları' : 'Premium tools'),
          _tile(
            context,
            Icons.document_scanner_outlined,
            isTr ? 'Belge Tarayıcı' : 'Document Scanner',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DocumentScannerScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(isTr ? 'Ayarlar' : 'Settings'),
          _tile(
            context,
            Icons.badge_outlined,
            isTr ? 'Seyahat profili' : 'Travel profile',
            () => context.push(AppRoutes.editProfile),
          ),
          _tile(
            context,
            Icons.language,
            isTr ? 'Dil' : 'Language',
            () => context.push(AppRoutes.languageSettings),
          ),
          _tile(
            context,
            Icons.notifications_outlined,
            isTr ? 'Bildirimler' : 'Notifications',
            () => context.push(AppRoutes.notificationSettings),
          ),
          const SizedBox(height: 16),
          _sectionLabel(isTr ? 'Hakkında' : 'About'),
          _tile(
            context,
            Icons.privacy_tip_outlined,
            isTr ? 'Gizlilik Politikası' : 'Privacy Policy',
            () => context.push(
                '${AppRoutes.legalText}?type=privacy&title=${Uri.encodeComponent(isTr ? 'Gizlilik' : 'Privacy')}'),
          ),
          _tile(
            context,
            Icons.description_outlined,
            isTr ? 'Kullanım Şartları' : 'Terms of Use',
            () => context.push(
                '${AppRoutes.legalText}?type=terms&title=${Uri.encodeComponent(isTr ? 'Şartlar' : 'Terms')}'),
          ),
          _tile(
            context,
            Icons.bug_report_outlined,
            isTr ? 'Tanılama' : 'Diagnostics',
            () => context.push(AppRoutes.diagnostics),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'VisaRadar Travel 1.0.0',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passportCard(BuildContext context, UserProfile p, bool isTr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandNavyLight, AppColors.surfaceCard],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle,
                  color: AppColors.brandTeal, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nationalityLabel ??
                          (isTr ? 'Gezgin' : 'Traveller'),
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      passportLabel(p.passportType, isTr),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => context.push(AppRoutes.editProfile),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumCard(
      BuildContext context, bool isPremium, WidgetRef ref, bool isTr) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandTeal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: AppColors.brandTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isTr ? 'Premium aktif — teşekkürler!' : 'Premium active — thank you!',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.brandTeal),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandTeal, AppColors.info],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? 'Premium\'a Geç' : 'Go Premium',
                      style: AppTextStyles.titleLarge
                          .copyWith(color: Colors.white),
                    ),
                    Text(
                      isTr
                          ? 'AI asistan, belge tarayıcı, sınır modu'
                          : 'AI assistant, document scanner, border mode',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(text.toUpperCase(), style: AppTextStyles.caption),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Icon(icon, color: AppColors.brandTeal),
          title: Text(label, style: AppTextStyles.bodyLarge),
          trailing:
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}
