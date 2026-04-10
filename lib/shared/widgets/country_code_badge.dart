import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Styled 2-letter ISO-3166 country code badge.
///
/// Replaces flag emoji for 100% cross-platform reliability.
/// Works identically on iOS, Android, and any system regardless of
/// emoji font support.
class CountryCodeBadge extends StatelessWidget {
  const CountryCodeBadge({
    super.key,
    required this.code,
    this.highlighted = false,
    this.size = BadgeSize.medium,
  });

  final String code;
  final bool highlighted;
  final BadgeSize size;

  static const CountryCodeBadge empty = CountryCodeBadge(code: '  ');

  @override
  Widget build(BuildContext context) {
    final (w, h, fs) = switch (size) {
      BadgeSize.small => (32.0, 22.0, 9.0),
      BadgeSize.medium => (38.0, 26.0, 10.0),
      BadgeSize.large => (46.0, 32.0, 12.0),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.brandTeal.withAlpha(25)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: highlighted ? AppColors.brandTeal : AppColors.divider,
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w700,
          color: highlighted ? AppColors.brandTeal : AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

enum BadgeSize { small, medium, large }
