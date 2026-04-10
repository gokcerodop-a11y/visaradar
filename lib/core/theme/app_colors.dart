import 'package:flutter/material.dart';

/// VisaRadar brand color palette.
///
/// Design language: deep navy + electric teal accent, minimal white space,
/// premium feel.
abstract class AppColors {
  // Brand
  static const Color brandNavy = Color(0xFF0B1120);
  static const Color brandNavyLight = Color(0xFF131E33);
  static const Color brandTeal = Color(0xFF00D4AA);
  static const Color brandTealDim = Color(0xFF00A884);

  // Neutrals
  static const Color surface = Color(0xFF111827);
  static const Color surfaceCard = Color(0xFF1C2A3F);
  static const Color divider = Color(0xFF243047);
  static const Color textPrimary = Color(0xFFEDF2FF);
  static const Color textSecondary = Color(0xFF8FA3BF);
  static const Color textMuted = Color(0xFF4A607A);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Schengen risk gradient
  static const Color riskSafe = success;
  static const Color riskWarning = warning;
  static const Color riskCritical = danger;
}
