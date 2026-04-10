import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/travel/presentation/providers/trips_provider.dart';
import '../../domain/models/crossing_suggestion.dart';
import '../providers/border_crossing_provider.dart';

/// Premium alert card surfaced on the Radar screen when a country change is
/// detected. Shows from→to country and prompts the user to confirm or dismiss.
///
/// Renders nothing when there is no pending suggestion.
class CrossingSuggestionCard extends ConsumerWidget {
  const CrossingSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(borderCrossingProvider);
    if (suggestion == null) return const SizedBox.shrink();

    return _SuggestionCard(suggestion: suggestion);
  }
}

// ---------------------------------------------------------------------------
// Card implementation
// ---------------------------------------------------------------------------

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.suggestion});

  final CrossingSuggestion suggestion;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(borderCrossingProvider.notifier);
    final trips = ref.read(tripsProvider);
    final tripsNotifier = ref.read(tripsProvider.notifier);

    final isClose = suggestion.type == CrossingSuggestionType.closeAndStartNew;
    final actionLabel = isClose
        ? 'Close stay & log entry'
        : 'Log entry in ${suggestion.toLabel}';
    final timeStr = _timeFmt.format(suggestion.detectedAt.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandTeal.withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withAlpha(22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.brandTeal,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POSSIBLE BORDER CROSSING',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.brandTeal,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Detected at $timeStr',
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

          // ── Country route ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _CountryChip(
                  code: suggestion.fromCountryCode,
                  name: suggestion.fromLabel,
                  isDim: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                ),
                _CountryChip(
                  code: suggestion.toCountryCode,
                  name: suggestion.toLabel,
                  isDim: false,
                ),
              ],
            ),
          ),

          // ── Description ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              isClose
                  ? 'You appear to have left ${suggestion.fromLabel} and entered ${suggestion.toLabel}. Confirm to close your current stay and log your new entry.'
                  : 'You appear to be in ${suggestion.toLabel}. Confirm to log a new trip entry.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),

          // ── Actions ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: actionLabel,
                    isPrimary: true,
                    onTap: () async {
                      await notifier.confirmSuggestion(
                        suggestion: suggestion,
                        tripsNotifier: tripsNotifier,
                        currentTrips: trips,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  label: 'Not now',
                  isPrimary: false,
                  onTap: notifier.dismissSuggestion,
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
// Atoms
// ---------------------------------------------------------------------------

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.code,
    required this.name,
    required this.isDim,
  });

  final String code;
  final String name;
  final bool isDim;

  @override
  Widget build(BuildContext context) {
    final textColor = isDim ? AppColors.textMuted : AppColors.textPrimary;
    final bgColor = isDim
        ? AppColors.divider.withAlpha(120)
        : AppColors.brandTeal.withAlpha(20);
    final borderColor = isDim ? Colors.transparent : AppColors.brandTeal.withAlpha(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: AppTextStyles.caption.copyWith(
              color: isDim ? AppColors.textMuted : AppColors.brandTeal,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.brandTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(color: AppColors.divider, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: isPrimary ? AppColors.brandNavy : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
