// sync_status_badge.dart
// Compact status badge showing the current Supabase sync state.
// Tap to manually trigger a flush of queued ops.

import 'package:flutter/material.dart';

import '../services/supabase_sync_service.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupabaseSyncService.instance,
      builder: (context, _) {
        final svc = SupabaseSyncService.instance;
        final status = svc.status;

        // Don't show anything in fully local mode unless queue has items.
        if (status == SyncStatus.localOnly && svc.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final (icon, color, label) = switch (status) {
          SyncStatus.localOnly => (Icons.cloud_off_rounded, const Color(0xFF6B7280), 'Yerel'),
          SyncStatus.syncing   => (Icons.sync_rounded, const Color(0xFF60A5FA), 'Sync…'),
          SyncStatus.synced    => (Icons.cloud_done_rounded, const Color(0xFF4ADE80), 'Sync'),
          SyncStatus.offline   => (Icons.cloud_off_rounded, const Color(0xFFFBBF24), 'Çevrimdışı'),
          SyncStatus.conflict  => (Icons.warning_amber_rounded, const Color(0xFFF87171), 'Çakışma'),
        };

        final pending = svc.pendingCount;

        return GestureDetector(
          onTap: () {
            if (status == SyncStatus.offline || pending > 0) {
              SupabaseSyncService.instance.flush();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusIcon(icon: icon, color: color, syncing: status == SyncStatus.syncing),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$pending',
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// Spins when syncing, static otherwise.
class _StatusIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool syncing;

  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.syncing,
  });

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.syncing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_StatusIcon old) {
    super.didUpdateWidget(old);
    if (widget.syncing && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.syncing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(widget.icon, color: widget.color, size: 11),
    );
  }
}
