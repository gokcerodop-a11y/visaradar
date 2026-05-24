import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ── SecretKey ──────────────────────────────────────────────────────────────────

class SecretKey {
  final String name;
  final bool required;
  final String? placeholder;   // known bad placeholder values to reject
  final int minLength;

  const SecretKey({
    required this.name,
    this.required = true,
    this.placeholder,
    this.minLength = 8,
  });
}

// ── ValidationResult ──────────────────────────────────────────────────────────

class ValidationResult {
  final bool valid;
  final List<String> missing;
  final List<String> placeholder;  // keys present but are placeholder values
  final List<String> warnings;

  const ValidationResult({
    required this.valid,
    required this.missing,
    required this.placeholder,
    required this.warnings,
  });

  bool get hasIssues => missing.isNotEmpty || placeholder.isNotEmpty;

  @override
  String toString() {
    final buf = StringBuffer('SecretValidation: ${valid ? 'PASS' : 'FAIL'}\n');
    for (final m in missing)     buf.writeln('  MISSING: $m');
    for (final p in placeholder) buf.writeln('  PLACEHOLDER: $p');
    for (final w in warnings)    buf.writeln('  WARN: $w');
    return buf.toString();
  }
}

// ── SecretsValidator ──────────────────────────────────────────────────────────

/// Validates that all required secrets are present and not placeholder values.
///
/// Call [SecretsValidator.validate()] early in app startup.
/// In production builds, missing required secrets will trigger a [FlutterError]
/// so the issue appears in crash reports immediately.
class SecretsValidator {
  SecretsValidator._();

  /// All secrets the app uses — expand as new integrations are added.
  static const List<SecretKey> _keys = [
    SecretKey(
      name: 'ANTHROPIC_API_KEY',
      required: true,
      placeholder: 'your_api_key_here',
      minLength: 20,
    ),
    // Add future keys here:
    // SecretKey(name: 'SENTRY_DSN', required: false),
    // SecretKey(name: 'GOOGLE_CLIENT_ID', required: false),
  ];

  // ── Validation ─────────────────────────────────────────────────────────────

  static ValidationResult validate() {
    final missing     = <String>[];
    final placeholder = <String>[];
    final warnings    = <String>[];

    for (final key in _keys) {
      String? value;
      try {
        value = dotenv.env[key.name];
      } catch (_) {
        value = null;
      }

      if (value == null || value.isEmpty) {
        if (key.required) {
          missing.add(key.name);
        } else {
          warnings.add('${key.name} not set (optional)');
        }
        continue;
      }

      // Check for known placeholder values.
      if (key.placeholder != null && value == key.placeholder) {
        placeholder.add(key.name);
        continue;
      }

      // Check minimum length.
      if (value.length < key.minLength) {
        warnings.add('${key.name} is suspiciously short (${value.length} chars)');
      }
    }

    final valid = missing.isEmpty && placeholder.isEmpty;
    final result = ValidationResult(
      valid: valid,
      missing: missing,
      placeholder: placeholder,
      warnings: warnings,
    );

    // Log summary.
    if (kDebugMode) {
      debugPrint(result.toString());
    }

    // In production, assert required keys — shows in Crashlytics immediately.
    if (!kDebugMode && !valid) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError(
          'SecretsValidator: required secrets missing or invalid. '
          'Missing: ${missing.join(', ')}. '
          'Placeholder: ${placeholder.join(', ')}.',
        ),
        library: 'SecretsValidator',
        context: ErrorDescription('during app initialisation'),
      ));
    }

    return result;
  }

  // ── Safe fallback mode ─────────────────────────────────────────────────────

  /// Returns true if the app should run in demo/offline mode
  /// (i.e. the API key is missing or a placeholder).
  static bool get shouldUseFallbackMode {
    try {
      final key = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
      return key.isEmpty || key == 'your_api_key_here' || key.length < 20;
    } catch (_) {
      return true;
    }
  }
}
