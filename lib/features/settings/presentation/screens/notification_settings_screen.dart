import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/location/domain/models/location_state.dart';
import '../../../../features/location/presentation/providers/location_provider.dart';
import '../../../../features/notifications/providers/notification_coordinator_provider.dart';
import '../../../../features/notifications/services/local_notification_service.dart';
import '../providers/notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs    = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final locPerm  = ref.watch(locationProvider.select((s) => s.permission));
    final notifPerm = ref.watch(notificationPermissionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(L.t('Notifications', 'Bildirimler'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Banner ──────────────────────────────────────────────────────
          _NoticeCard(
            icon:  Icons.notifications_active_outlined,
            color: AppColors.brandTeal,
            title: L.t('Stay ahead of your limits', 'Limitlerinin önünde ol'),
            body:  L.t(
              'VisaRadar will remind you before your Schengen allowance '
                  'runs out, so you never overstay by accident.',
              'VisaRadar, Schengen hakkın dolmadan önce seni uyarır; '
                  'böylece yanlışlıkla fazla kalmazsın.',
            ),
          ),
          const SizedBox(height: 20),

          // ── Device permissions ───────────────────────────────────────────
          _SectionHeader(title: L.t('Device permissions', 'Cihaz izinleri')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                notifPerm.when(
                  data: (granted) => _PermissionTile(
                    icon:    Icons.notifications_outlined,
                    label:   L.t('Notifications', 'Bildirimler'),
                    granted: granted,
                    hint:    granted
                        ? L.t('VisaRadar can send you alerts.',
                            'VisaRadar sana uyarı gönderebilir.')
                        : L.t('Allow notifications so VisaRadar can remind you.',
                            'VisaRadar seni hatırlatabilmesi için bildirimlere izin ver.'),
                    onTap: granted
                        ? null
                        : () async {
                            await LocalNotificationService.requestPermission();
                            // ignore: unused_result
                            ref.invalidate(notificationPermissionProvider);
                          },
                  ),
                  loading: () => const _PermissionTileLoading(),
                  error:   (e, s) => const SizedBox.shrink(),
                ),
                const Divider(height: 0, indent: 52),
                _PermissionTile(
                  icon:    Icons.location_on_outlined,
                  label:   L.t('Location access', 'Konum erişimi'),
                  granted: locPerm == LocationPermissionStatus.granted,
                  hint:    locPerm == LocationPermissionStatus.granted
                      ? L.t('Automatic border detection is active.',
                          'Otomatik sınır algılama aktif.')
                      : L.t('Location is off — border detection is limited.',
                          'Konum kapalı — sınır algılama sınırlı.'),
                  onTap: locPerm == LocationPermissionStatus.granted
                      ? null
                      : () => ref.read(locationProvider.notifier).requestPermission(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Schengen alerts ──────────────────────────────────────────────
          _SectionHeader(title: L.t('Schengen alerts', 'Schengen uyarıları')),
          const SizedBox(height: 4),
          Text(
            L.t('Get a heads-up before your 90-day allowance runs out.',
                '90 günlük hakkın dolmadan önce haberin olsun.'),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _NotifTile(
                  icon:      Icons.schedule_outlined,
                  color:     AppColors.info,
                  title:     L.t('30 days remaining', '30 gün kaldı'),
                  subtitle:  L.t('Early notice with time to plan ahead.',
                      'Planlamak için erkenden haber.'),
                  value:     prefs.schengenAlert30,
                  onChanged: notifier.setSchengenAlert30,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.warning_amber_outlined,
                  color:     AppColors.warning,
                  title:     L.t('15 days remaining', '15 gün kaldı'),
                  subtitle:  L.t('Time to think about your travel plans.',
                      'Seyahat planlarını düşünme zamanı.'),
                  value:     prefs.schengenAlert15,
                  onChanged: notifier.setSchengenAlert15,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.warning_amber_outlined,
                  color:     AppColors.warning,
                  title:     L.t('7 days remaining', '7 gün kaldı'),
                  subtitle:  L.t('Start planning your exit or next steps.',
                      'Çıkışını ya da sonraki adımlarını planlamaya başla.'),
                  value:     prefs.schengenAlert7,
                  onChanged: notifier.setSchengenAlert7,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.dangerous_outlined,
                  color:     AppColors.danger,
                  title:     L.t('3 days remaining', '3 gün kaldı'),
                  subtitle:  L.t('Urgent — arrange your stay or exit.',
                      'Acil — kalışını ya da çıkışını ayarla.'),
                  value:     prefs.schengenAlert3,
                  onChanged: notifier.setSchengenAlert3,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.dangerous_outlined,
                  color:     AppColors.danger,
                  title:     L.t('1 day remaining', '1 gün kaldı'),
                  subtitle:  L.t('Final warning before your limit.',
                      'Limitine ulaşmadan önceki son uyarı.'),
                  value:     prefs.schengenAlert1,
                  onChanged: notifier.setSchengenAlert1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Travel reminders ─────────────────────────────────────────────
          _SectionHeader(title: L.t('Travel reminders', 'Seyahat hatırlatmaları')),
          const SizedBox(height: 4),
          Text(
            L.t('Nudges to keep your trip log accurate.',
                'Seyahat kaydını doğru tutman için küçük hatırlatmalar.'),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _NotifTile(
                  icon:      Icons.flight_outlined,
                  color:     AppColors.brandTeal,
                  title:     L.t('Open trip reminder', 'Açık seyahat hatırlatması'),
                  subtitle:  L.t(
                      'Nudge to close a trip when you have an entry with no exit date logged.',
                      'Çıkış tarihi kaydedilmemiş bir girişin olduğunda seyahati kapatman için hatırlatma.'),
                  value:     prefs.ongoingStayReminder,
                  onChanged: notifier.setOngoingStayReminder,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.flag_outlined,
                  color:     AppColors.brandTeal,
                  title:     L.t('Border crossing review', 'Sınır geçişi incelemesi'),
                  subtitle:  L.t(
                      'Nudge to review your trips after dismissing a crossing suggestion.',
                      'Bir geçiş önerisini reddettikten sonra seyahatlerini gözden geçirmen için hatırlatma.'),
                  value:     prefs.dismissedCrossingReminder,
                  onChanged: notifier.setDismissedCrossingReminder,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.location_off_outlined,
                  color:     AppColors.textSecondary,
                  title:     L.t('Location inactive', 'Konum kapalı'),
                  subtitle:  L.t(
                      'Alert when location access is off and you have active trips.',
                      'Konum erişimi kapalıyken ve aktif seyahatlerin varken uyar.'),
                  value:     prefs.locationInactiveReminder,
                  onChanged: notifier.setLocationInactiveReminder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Debug tools (only in debug builds) ───────────────────────────
          if (kDebugMode) ...[
            _SectionHeader(title: L.t('Developer tools', 'Geliştirici araçları')),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _ActionTile(
                    icon:     Icons.science_outlined,
                    color:    AppColors.info,
                    title:    L.t('Send test notification', 'Test bildirimi gönder'),
                    subtitle: L.t('Fires an immediate test notification.',
                        'Hemen bir test bildirimi gönderir.'),
                    label:    L.t('Send', 'Gönder'),
                    onTap: () async {
                      await LocalNotificationService.showNow(
                        id:    AppConstants.notifIdDebugTest,
                        title: L.t('VisaRadar test', 'VisaRadar testi'),
                        body:  L.t('Notifications are working correctly.',
                            'Bildirimler doğru çalışıyor.'),
                      );
                    },
                  ),
                  const Divider(height: 0, indent: 52),
                  _ActionTile(
                    icon:     Icons.refresh_outlined,
                    color:    AppColors.info,
                    title:    L.t('Reschedule all', 'Tümünü yeniden planla'),
                    subtitle: L.t('Re-evaluate and rebuild the full notification schedule.',
                        'Tüm bildirim planını yeniden değerlendirir ve oluşturur.'),
                    label:    L.t('Run', 'Çalıştır'),
                    onTap: () {
                      ref.invalidate(notificationCoordinatorProvider);
                    },
                  ),
                  const Divider(height: 0, indent: 52),
                  _ActionTile(
                    icon:     Icons.delete_outline,
                    color:    AppColors.danger,
                    title:    L.t('Cancel all notifications', 'Tüm bildirimleri iptal et'),
                    subtitle: L.t('Clears every pending notification.',
                        'Bekleyen tüm bildirimleri temizler.'),
                    label:    L.t('Clear', 'Temizle'),
                    onTap:    LocalNotificationService.cancelAll,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L.t('Debug tools are only visible in development builds.',
                  'Hata ayıklama araçları yalnızca geliştirme sürümlerinde görünür.'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              L.t(
                'Notification delivery requires permission. '
                    'You can also manage this in your device settings → VisaRadar.',
                'Bildirim gönderimi izin gerektirir. '
                    'Bunu cihaz ayarlarından da yönetebilirsin → VisaRadar.',
              ),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color:          AppColors.textSecondary,
        fontWeight:     FontWeight.w600,
        letterSpacing:  0.8,
      ),
    );
  }
}

// ── Notice card ──────────────────────────────────────────────────────────────

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color    color;
  final String   title;
  final String   body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission tile ──────────────────────────────────────────────────────────

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.label,
    required this.granted,
    required this.hint,
    this.onTap,
  });

  final IconData icon;
  final String   label;
  final bool     granted;
  final String   hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = granted ? AppColors.success : AppColors.warning;
    final statusLabel = granted
        ? L.t('Allowed', 'İzin verildi')
        : L.t('Not allowed', 'İzin verilmedi');

    return ListTile(
      leading: Icon(icon, color: statusColor, size: 22),
      title:   Text(label, style: AppTextStyles.bodyMedium),
      subtitle: Text(hint,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary)),
      trailing: onTap != null
          ? TextButton(
              onPressed: onTap,
              child: Text(L.t('Enable', 'Etkinleştir')),
            )
          : _StatusBadge(label: statusLabel, color: statusColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _PermissionTileLoading extends StatelessWidget {
  const _PermissionTileLoading();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text(L.t('Notifications', 'Bildirimler')),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color:      color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Notification toggle tile ─────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData           icon;
  final Color              color;
  final String             title;
  final String             subtitle;
  final bool               value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: color, size: 22),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      value:            value,
      onChanged:        onChanged,
      activeThumbColor: AppColors.brandTeal,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Action tile (for debug tools) ────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
  });

  final IconData  icon;
  final Color     color;
  final String    title;
  final String    subtitle;
  final String    label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      trailing: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(80)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: AppTextStyles.caption),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
