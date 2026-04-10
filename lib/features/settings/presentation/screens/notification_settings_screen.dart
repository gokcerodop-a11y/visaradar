import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
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
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Banner ──────────────────────────────────────────────────────
          _NoticeCard(
            icon:  Icons.notifications_active_outlined,
            color: AppColors.brandTeal,
            title: 'Stay ahead of your limits',
            body:  'VisaRadar will remind you before your Schengen allowance '
                   'runs out, so you never overstay by accident.',
          ),
          const SizedBox(height: 20),

          // ── Device permissions ───────────────────────────────────────────
          _SectionHeader(title: 'Device permissions'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                notifPerm.when(
                  data: (granted) => _PermissionTile(
                    icon:    Icons.notifications_outlined,
                    label:   'Notifications',
                    granted: granted,
                    hint:    granted
                        ? 'VisaRadar can send you alerts.'
                        : 'Allow notifications so VisaRadar can remind you.',
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
                  label:   'Location access',
                  granted: locPerm == LocationPermissionStatus.granted,
                  hint:    locPerm == LocationPermissionStatus.granted
                      ? 'Automatic border detection is active.'
                      : 'Location is off — border detection is limited.',
                  onTap: locPerm == LocationPermissionStatus.granted
                      ? null
                      : () => ref.read(locationProvider.notifier).requestPermission(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Schengen alerts ──────────────────────────────────────────────
          _SectionHeader(title: 'Schengen alerts'),
          const SizedBox(height: 4),
          Text(
            'Get a heads-up before your 90-day allowance runs out.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _NotifTile(
                  icon:      Icons.schedule_outlined,
                  color:     AppColors.info,
                  title:     '30 days remaining',
                  subtitle:  'Early notice with time to plan ahead.',
                  value:     prefs.schengenAlert30,
                  onChanged: notifier.setSchengenAlert30,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.warning_amber_outlined,
                  color:     AppColors.warning,
                  title:     '15 days remaining',
                  subtitle:  'Time to think about your travel plans.',
                  value:     prefs.schengenAlert15,
                  onChanged: notifier.setSchengenAlert15,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.warning_amber_outlined,
                  color:     AppColors.warning,
                  title:     '7 days remaining',
                  subtitle:  'Start planning your exit or next steps.',
                  value:     prefs.schengenAlert7,
                  onChanged: notifier.setSchengenAlert7,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.dangerous_outlined,
                  color:     AppColors.danger,
                  title:     '3 days remaining',
                  subtitle:  'Urgent — arrange your stay or exit.',
                  value:     prefs.schengenAlert3,
                  onChanged: notifier.setSchengenAlert3,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.dangerous_outlined,
                  color:     AppColors.danger,
                  title:     '1 day remaining',
                  subtitle:  'Final warning before your limit.',
                  value:     prefs.schengenAlert1,
                  onChanged: notifier.setSchengenAlert1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Travel reminders ─────────────────────────────────────────────
          _SectionHeader(title: 'Travel reminders'),
          const SizedBox(height: 4),
          Text(
            'Nudges to keep your trip log accurate.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _NotifTile(
                  icon:      Icons.flight_outlined,
                  color:     AppColors.brandTeal,
                  title:     'Open trip reminder',
                  subtitle:  'Nudge to close a trip when you have an entry with no exit date logged.',
                  value:     prefs.ongoingStayReminder,
                  onChanged: notifier.setOngoingStayReminder,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.flag_outlined,
                  color:     AppColors.brandTeal,
                  title:     'Border crossing review',
                  subtitle:  'Nudge to review your trips after dismissing a crossing suggestion.',
                  value:     prefs.dismissedCrossingReminder,
                  onChanged: notifier.setDismissedCrossingReminder,
                ),
                const Divider(height: 0, indent: 52),
                _NotifTile(
                  icon:      Icons.location_off_outlined,
                  color:     AppColors.textSecondary,
                  title:     'Location inactive',
                  subtitle:  'Alert when location access is off and you have active trips.',
                  value:     prefs.locationInactiveReminder,
                  onChanged: notifier.setLocationInactiveReminder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Debug tools (only in debug builds) ───────────────────────────
          if (kDebugMode) ...[
            _SectionHeader(title: 'Developer tools'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _ActionTile(
                    icon:     Icons.science_outlined,
                    color:    AppColors.info,
                    title:    'Send test notification',
                    subtitle: 'Fires an immediate test notification.',
                    label:    'Send',
                    onTap: () async {
                      await LocalNotificationService.showNow(
                        id:    AppConstants.notifIdDebugTest,
                        title: 'VisaRadar test',
                        body:  'Notifications are working correctly.',
                      );
                    },
                  ),
                  const Divider(height: 0, indent: 52),
                  _ActionTile(
                    icon:     Icons.refresh_outlined,
                    color:    AppColors.info,
                    title:    'Reschedule all',
                    subtitle: 'Re-evaluate and rebuild the full notification schedule.',
                    label:    'Run',
                    onTap: () {
                      ref.invalidate(notificationCoordinatorProvider);
                    },
                  ),
                  const Divider(height: 0, indent: 52),
                  _ActionTile(
                    icon:     Icons.delete_outline,
                    color:    AppColors.danger,
                    title:    'Cancel all notifications',
                    subtitle: 'Clears every pending notification.',
                    label:    'Clear',
                    onTap:    LocalNotificationService.cancelAll,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Debug tools are only visible in development builds.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Notification delivery requires permission. '
              'You can also manage this in your device settings → VisaRadar.',
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
    final statusLabel = granted ? 'Allowed' : 'Not allowed';

    return ListTile(
      leading: Icon(icon, color: statusColor, size: 22),
      title:   Text(label, style: AppTextStyles.bodyMedium),
      subtitle: Text(hint,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary)),
      trailing: onTap != null
          ? TextButton(
              onPressed: onTap,
              child: const Text('Enable'),
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
    return const ListTile(
      leading: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text('Notifications'),
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
