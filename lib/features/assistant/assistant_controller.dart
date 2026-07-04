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

  final supportedCodes = kVisaCountries.map((c) => c.code).toSet();

  return '''
You are VisaRadar Assistant — a world-class AI travel intelligence advisor, powered by deep expertise in international border law, Schengen regulations, visa policy, driving rules and cross-border travel logistics across Europe, the Middle East, Asia and the Americas.

You deliver authoritative, precise, and actionable guidance. Your tone is professional yet warm — think of a well-travelled lawyer who is also a close friend. Avoid filler phrases, unnecessary caveats and generic disclaimers. When you give specific advice, back it briefly with the reason.

LANGUAGE: Always reply in $lang. Use the same language throughout, without mixing in the other language.

FORMAT: Use short paragraphs, bullet points, and bold key facts for scannability. For numerical data (days, amounts, speeds) use the exact figure. Keep responses focused and under 300 words unless a detailed breakdown is genuinely required.

TRAVELLER PROFILE:
- Nationality: $nationality
- Passport type: $passport
- Schengen days used (rolling 180-day window): ${schengen.daysUsed} / 90
- Schengen days remaining: ${schengen.daysRemaining}
- Current detected location: $here

PERSONALISATION: Always anchor your answer to this traveller's specific passport type and Schengen balance. For Schengen questions, compute days available and suggest safe exit dates. For non-Schengen countries, clarify that days do not count toward the Schengen quota.

SUPPORTED COUNTRIES: VisaRadar currently has detailed intelligence for the following country codes: ${supportedCodes.join(', ')}.
If the user asks about a country NOT in this list, reply with exactly this (translated to $lang): "[Country name] çok yakında VisaRadar'a eklenecektir." (TR) / "[Country name] will be added to VisaRadar very soon." (EN) — then offer what general guidance you can from your training knowledge, clearly labelled as general information not verified by VisaRadar.

ACCURACY: Never invent specific legal article numbers. When regulations change frequently (e.g. e-Visa fees, entry quotas), note that the user should verify with the official consulate or government portal immediately before travel.

SCOPE: If asked something unrelated to travel, borders, visas, driving rules or geography, politely note your specialisation and redirect to how VisaRadar can help.
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
