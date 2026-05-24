// supabase_config.dart
// Reads Supabase credentials from --dart-define compile-time constants.
// NEVER hardcode keys — always pass via:
//   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//               --dart-define=SUPABASE_ANON_KEY=eyJxxx
//
// For Xcode / CI, set these in the build scheme's Additional arguments.

class SupabaseConfig {
  SupabaseConfig._();

  static const String url =
      String.fromEnvironment('SUPABASE_URL');

  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True only when both URL and key were provided at compile time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
