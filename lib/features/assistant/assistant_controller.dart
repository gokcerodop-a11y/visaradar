import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale.dart';
import '../../services/ai/ai_message.dart';
import '../../services/ai/anthropic_proxy.dart';
import '../../services/premium_providers.dart';
import '../countries/domain/country_data.dart';
import '../location/presentation/providers/location_provider.dart';
import '../profile/domain/models/user_profile.dart';
import '../profile/presentation/providers/profile_provider.dart';
import '../travel/presentation/providers/trips_provider.dart';

String passportLabel(PassportType t, bool tr) {
  switch (t) {
    case PassportType.ordinary:
      return tr ? 'Umuma mahsus (bordo) pasaport' : 'Ordinary passport';
    case PassportType.special:
      return tr ? 'Hususi (yeşil) pasaport' : 'Special (green) passport';
    case PassportType.serviceOfficial:
      return tr ? 'Hizmet pasaportu' : 'Service passport';
    case PassportType.diplomatic:
      return tr ? 'Diplomatik pasaport' : 'Diplomatic passport';
    case PassportType.euEeaSwiss:
      return tr ? 'AB/EEA/İsviçre pasaportu' : 'EU/EEA/Swiss passport';
  }
}

/// Builds the system prompt with live user context so Claude answers in the
/// right language and grounded in the traveller's real Schengen state.
final assistantSystemPromptProvider = Provider<String>((ref) {
  final isTr = ref.watch(isTurkishProvider);
  final profile = ref.watch(profileProvider);
  final schengen = ref.watch(schengenResultProvider);
  final detected = ref.watch(detectedCountryProvider);
  final country = detected != null ? visaCountryByCode(detected.isoCode) : null;

  final lang = isTr ? 'Turkish' : 'English';
  final passport = passportLabel(profile.passportType, isTr);
  final nationality = profile.nationalityLabel ?? profile.nationality ?? 'Turkey';
  final here = country?.name(isTr) ??
      detected?.toString() ??
      (isTr ? 'bilinmiyor' : 'unknown');

  return '''
You are VisaRadar Assistant, an expert AI travel companion specialised in
border crossings, visa rules, the Schengen 90/180 rule, and country-specific
travel intelligence for travellers around Turkey, Greece, Bulgaria and the
wider Schengen and Balkan region.

ALWAYS reply in $lang. Be concise, practical and friendly. Use short
paragraphs or bullet points. Never invent specific legal article numbers.
When rules can change, add a one-line reminder to verify with the official
consulate or border authority.

Traveller context:
- Nationality: $nationality
- Passport: $passport
- Schengen days used (rolling 180 days): ${schengen.daysUsed}/90
- Schengen days remaining: ${schengen.daysRemaining}
- Currently detected location: $here

Use this context to personalise answers (e.g. remaining Schengen days, whether
a country counts toward Schengen). If asked something outside travel/border/
visa scope, gently steer back to how VisaRadar can help.
''';
});

@immutable
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.loading = false,
    this.error,
  });

  final List<AIMessage> messages;
  final bool loading;
  final String? error; // localized key handled in UI

  AssistantState copyWith({
    List<AIMessage>? messages,
    bool? loading,
    Object? error = _unset,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      error: error == _unset ? this.error : error as String?,
    );
  }

  static const _unset = Object();
}

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._ref) : super(const AssistantState());

  final Ref _ref;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.loading) return;

    final bearer = _ref.read(premiumBearerProvider);
    final isTr = _ref.read(isTurkishProvider);
    if (bearer == null || bearer.isEmpty) {
      state = state.copyWith(error: 'no-subscription');
      return;
    }

    final history = [...state.messages, AIMessage.user(trimmed)];
    state = state.copyWith(messages: history, loading: true, error: null);

    final proxy = AnthropicProxy(
      originalTransactionId: bearer,
      language: isTr ? 'tr' : 'en',
    );
    try {
      final systemPrompt = _ref.read(assistantSystemPromptProvider);
      final reply = await proxy.chat(history, systemPrompt: systemPrompt);
      state = state.copyWith(
        messages: [...history, AIMessage.assistant(reply)],
        loading: false,
      );
    } on ProxySubscriptionRequiredException {
      state = state.copyWith(loading: false, error: 'no-subscription');
    } on ProxyRateLimitException {
      state = state.copyWith(loading: false, error: 'rate-limit');
    } catch (e) {
      debugPrint('[AssistantController] $e');
      state = state.copyWith(loading: false, error: 'generic');
    } finally {
      proxy.dispose();
    }
  }

  void clear() => state = const AssistantState();
  void clearError() => state = state.copyWith(error: null);
}

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
  return AssistantController(ref);
});
