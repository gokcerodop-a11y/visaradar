import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/saved_places.dart';

/// Profile › Saved places — every spot the user pinned, kept on-device until
/// they delete it. Each entry can be re-opened in Maps for pinpoint navigation
/// years later. Populated from the Radar › Current location "Save place" action.
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPlacesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(L.t('Saved places', 'Kayıtlı yerlerim'))),
      body: saved.isEmpty
          ? _empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  L.t(
                      'The exact spots you saved. Re-open any of them in Maps to '
                          'navigate back — even years later.',
                      'Kaydettiğin tam noktalar. İstediğini Haritalar\'da açıp '
                          'yıllar sonra bile nokta atışı geri dönebilirsin.'),
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                ...saved.map((p) => _SavedTile(place: p)),
              ],
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              L.t('No saved places yet', 'Henüz kayıtlı yer yok'),
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              L.t(
                  'Open Radar › Current location and tap "Save place" to pin a '
                      'spot here.',
                  'Radar › Güncel konum ekranını açıp "Konumu kaydet" ile bir '
                      'noktayı buraya sabitle.'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.place});

  final SavedPlace place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = place;
    final subtitle = [
      if (p.city != null && p.city!.isNotEmpty) p.city!,
      '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.place, color: AppColors.brandTeal),
          title: Text(p.name, style: AppTextStyles.bodyLarge),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.navigation_outlined, size: 20),
                tooltip: L.t('Navigate', 'Git'),
                onPressed: () => _openInMaps(p.lat, p.lng, p.name),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: L.t('More', 'Daha fazla'),
                onPressed: () => _showActions(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(L.t('Rename', 'Yeniden adlandır')),
              onTap: () {
                Navigator.pop(ctx);
                _rename(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(L.t('Delete', 'Sil'),
                  style: const TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(savedPlacesProvider.notifier).remove(place.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: place.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(L.t('Rename place', 'Yeri yeniden adlandır')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L.t('Name', 'Ad'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.t('Cancel', 'İptal'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(L.t('Save', 'Kaydet'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(savedPlacesProvider.notifier).rename(place.id, name);
    }
  }

  Future<void> _openInMaps(double lat, double lng, String label) async {
    final uri = Uri.parse(
        'https://maps.apple.com/?ll=$lat,$lng&q=${Uri.encodeComponent(label)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
