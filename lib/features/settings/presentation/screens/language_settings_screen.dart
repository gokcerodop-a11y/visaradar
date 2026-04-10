import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final current = profile.preferredLocale; // null = auto

    Future<void> select(String? locale) async {
      await ref.read(profileProvider.notifier).update(
            profile.copyWith(preferredLocale: locale),
          );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                _LangTile(
                  label: 'Automatic',
                  subtitle: 'Follow system language',
                  icon: Icons.language,
                  isSelected: current == null,
                  onTap: () => select(null),
                ),
                const Divider(height: 0, indent: 52),
                _LangTile(
                  label: 'English',
                  subtitle: 'English',
                  icon: Icons.translate,
                  isSelected: current == 'en',
                  onTap: () => select('en'),
                ),
                const Divider(height: 0, indent: 52),
                _LangTile(
                  label: 'Türkçe',
                  subtitle: 'Turkish',
                  icon: Icons.translate,
                  isSelected: current == 'tr',
                  onTap: () => select('tr'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'More languages will be added in future updates.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? AppColors.brandTeal : AppColors.textSecondary,
          size: 22),
      title: Text(label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          )),
      subtitle: Text(subtitle,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary)),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.brandTeal, size: 18)
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
