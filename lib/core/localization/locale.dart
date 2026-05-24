import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/profile_provider.dart';

/// Lightweight derived locale: returns 'tr' if the user picked Turkish in
/// onboarding, otherwise 'en'. Watch this provider in any [ConsumerWidget]
/// that needs to localize a hardcoded English string via [t].
///
/// We intentionally do **not** wire `AppLocalizations.of(context)` here.
/// Existing screens hardcode English literals and refactoring all of them
/// to the ARB workflow is a separate, larger task. This inline pattern lets
/// individual screens become bilingual one at a time without rewiring app.dart
/// or regenerating gen-l10n output.
final localeProvider = Provider<String>((ref) {
  final code = ref.watch(profileProvider).preferredLocale;
  return code == 'tr' ? 'tr' : 'en';
});

/// Returns true if the active locale is Turkish.
final isTurkishProvider = Provider<bool>((ref) {
  return ref.watch(localeProvider) == 'tr';
});

/// Inline bilingual string picker.
///
///   Text(t(ref, 'Radar', 'Radar'))  // same in both — keeps signature consistent
///   Text(t(ref, 'Trips', 'Seyahatler'))
String t(WidgetRef ref, String en, String tr) {
  return ref.watch(isTurkishProvider) ? tr : en;
}
