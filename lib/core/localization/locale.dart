import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/profile_provider.dart';

/// Resolves the device language to one of our two supported codes.
///
/// Apple requirement: detect device language on launch — Turkish device →
/// Turkish UI, anything else → English UI. We read the platform's preferred
/// locale list (not a build-time constant) so this reflects the user's real
/// system language, then fall back to English for every non-Turkish language.
String deviceLanguageCode() {
  final locales = WidgetsBinding.instance.platformDispatcher.locales;
  for (final l in locales) {
    if (l.languageCode.toLowerCase() == 'tr') return 'tr';
  }
  return 'en';
}

/// Active UI language code: the user's explicit choice when set, otherwise the
/// auto-detected device language. Watch this in any [ConsumerWidget] that needs
/// to localize a string via [t], or to drive `MaterialApp.locale`.
final localeProvider = Provider<String>((ref) {
  final pref = ref.watch(profileProvider).preferredLocale;
  if (pref == 'tr' || pref == 'en') return pref!;
  return deviceLanguageCode();
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

/// Non-watching variant for use outside the build tree (e.g. building an AI
/// system prompt inside a provider). Pass the resolved [isTurkish] flag.
String tr2(bool isTurkish, String en, String tr) => isTurkish ? tr : en;

/// Global, ref-free locale accessor usable from ANY widget (including plain
/// StatelessWidget sub-widgets) and outside the build tree. Kept in sync with
/// [localeProvider] by VisaRadarApp on every build, and seeded at startup.
///
///   Text(L.t('Language', 'Dil'))
class L {
  L._();
  static String code = 'en';
  static bool get isTr => code == 'tr';
  static String t(String en, String tr) => isTr ? tr : en;
}
