import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/locale.dart';
import '../../services/ai/ai_message.dart';
import '../../services/ai/anthropic_proxy.dart';
import '../../services/premium_providers.dart';
import '../../services/subscription_service.dart';
import '../countries/domain/country_data.dart';
import '../location/presentation/providers/location_provider.dart';
import '../profile/domain/models/user_profile.dart';
import '../profile/presentation/providers/profile_provider.dart';
import '../travel/presentation/providers/trips_provider.dart';

/// Non-premium users may ask this many free AI questions before the paywall.
const int kFreeQuestionLimit = 3;

/// SharedPreferences key that tracks how many free questions have been used.
const String _kFreeQuestionsKey = 'free_ai_questions_used';

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

NEARBY SEARCHES: If the user asks to find a nearby place (currency exchange office, pharmacy, ATM, restaurant, supermarket, etc.), do NOT say you cannot help. Instead, reply briefly and then provide a tappable Apple Maps search link formatted exactly as: maps://?q=SEARCH_TERM (replace spaces with + in the search term). Example for currency exchange in $here: maps://?q=currency+exchange. Tell the user to tap the link to open Maps. This is the correct and expected behaviour.
''';
});

@immutable
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.loading = false,
    this.error,
    this.freeQuestionsUsed = 0,
  });

  final List<AIMessage> messages;
  final bool loading;
  final String? error; // localized key handled in UI
  final int freeQuestionsUsed;

  AssistantState copyWith({
    List<AIMessage>? messages,
    bool? loading,
    Object? error = _unset,
    int? freeQuestionsUsed,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      error: error == _unset ? this.error : error as String?,
      freeQuestionsUsed: freeQuestionsUsed ?? this.freeQuestionsUsed,
    );
  }

  static const _unset = Object();
}

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._ref) : super(const AssistantState()) {
    _loadFreeQuestions();
  }

  final Ref _ref;

  Future<void> _loadFreeQuestions() async {
    final used = await getFreeQuestionsUsed();
    if (mounted) state = state.copyWith(freeQuestionsUsed: used);
  }

  /// Reads how many free questions the user has consumed (default 0).
  Future<int> getFreeQuestionsUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kFreeQuestionsKey) ?? 0;
  }

  /// Increments and persists the free question counter, mirroring it in state.
  Future<void> incrementFreeQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_kFreeQuestionsKey) ?? 0) + 1;
    await prefs.setInt(_kFreeQuestionsKey, next);
    if (mounted) state = state.copyWith(freeQuestionsUsed: next);
  }

  /// True when the user is not premium and has used all free questions.
  bool isFreeTrialExhausted() {
    final isPremium = _ref.read(isPremiumProvider);
    return !isPremium && state.freeQuestionsUsed >= kFreeQuestionLimit;
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.loading) return;

    final isPremium = _ref.read(isPremiumProvider);
    final bearer = _ref.read(premiumBearerProvider);
    final isTr = _ref.read(isTurkishProvider);

    if (!isPremium) {
      final freeUsed = await getFreeQuestionsUsed();
      if (freeUsed >= kFreeQuestionLimit) {
        state = state.copyWith(
          error: 'free_limit_reached',
          freeQuestionsUsed: freeUsed,
        );
        return;
      }
    } else if (bearer == null || bearer.isEmpty) {
      state = state.copyWith(error: 'no-subscription');
      return;
    }

    final history = [...state.messages, AIMessage.user(trimmed)];
    state = state.copyWith(messages: history, loading: true, error: null);

    final proxy = AnthropicProxy(
      originalTransactionId:
          (bearer == null || bearer.isEmpty) ? 'free-trial' : bearer,
      language: isTr ? 'tr' : 'en',
    );
    try {
      final systemPrompt = _ref.read(assistantSystemPromptProvider);
      // Worker enforces a 12-message cap; send only the last 11 so long
      // conversations never hit a permanent 400.
      final trimmedMessages = state.messages.length > 11
          ? state.messages.sublist(state.messages.length - 11)
          : state.messages;
      final reply =
          await proxy.chat(trimmedMessages, systemPrompt: systemPrompt);
      state = state.copyWith(
        messages: [...history, AIMessage.assistant(reply)],
        loading: false,
      );
      if (!isPremium) await incrementFreeQuestions();
    } on ProxySubscriptionRequiredException catch (e) {
      if (e.reason == 'subscription-revoked') {
        SubscriptionService.instance.revokeEntitlement().ignore();
      }
      state = state.copyWith(loading: false, error: 'no-subscription');
    } on ProxyRateLimitException {
      state = state.copyWith(loading: false, error: 'rate-limit');
    } on ProxyNetworkException {
      state = state.copyWith(loading: false, error: 'network');
    } catch (e) {
      debugPrint('[AssistantController] $e');
      state = state.copyWith(loading: false, error: 'generic');
    } finally {
      proxy.dispose();
    }
  }

  void clear() =>
      state = AssistantState(freeQuestionsUsed: state.freeQuestionsUsed);
  void clearError() => state = state.copyWith(error: null);
}

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
  return AssistantController(ref);
});
