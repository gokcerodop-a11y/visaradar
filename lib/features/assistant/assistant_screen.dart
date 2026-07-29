import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/localization/locale.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/ai/ai_message.dart';
import '../../services/ai/anthropic_proxy.dart';
import '../../services/natural_tts.dart';
import '../../services/premium_providers.dart';
import 'assistant_controller.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = stt.SpeechToText();
  final _tts = NaturalTts();
  bool _isListening = false;
  bool _speechAvailable = false;
  int _playingIndex = -1;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final isTr = ref.read(isTurkishProvider);
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _input.text = result.recognizedWords;
          });
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: isTr ? 'tr_TR' : 'en_US',
          listenMode: stt.ListenMode.dictation,
        ),
      );
    }
  }

  Future<void> _toggleSpeak(String text, int index) async {
    if (_playingIndex == index) {
      await _tts.stop();
      setState(() => _playingIndex = -1);
      return;
    }
    if (_tts.isPlaying) await _tts.stop();
    setState(() => _playingIndex = index);
    final bearer = ref.read(premiumBearerProvider);
    if (bearer == null || bearer.isEmpty) {
      setState(() => _playingIndex = -1);
      return;
    }
    final ok = await _tts.speak(text,
        baseUrl: AnthropicProxy.defaultBaseUrl, token: bearer);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.isTr ? 'Ses yüklenemedi' : 'Audio unavailable'),
        ),
      );
    }
    if (mounted) setState(() => _playingIndex = -1);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (ref.read(assistantControllerProvider.notifier).isFreeTrialExhausted()) {
      return;
    }
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(assistantControllerProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.radar),
              ),
        title: Text(isTr ? 'Asistan' : 'Assistant'),
        actions: [
          if (isPremium)
            IconButton(
              tooltip: isTr ? 'Sohbeti temizle' : 'Clear chat',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(assistantControllerProvider.notifier).clear(),
            ),
        ],
      ),
      body: _chat(isTr, isPremium),
    );
  }

  // ── Chat ───────────────────────────────────────────────────────────

  Widget _chat(bool isTr, bool isPremium) {
    final state = ref.watch(assistantControllerProvider);
    final exhausted = !isPremium &&
        state.freeQuestionsUsed >= kFreeQuestionLimit;

    ref.listen(assistantControllerProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollToEnd();
      }
      if (next.error != null && next.error != prev?.error) {
        _showError(next.error!, isTr);
        ref.read(assistantControllerProvider.notifier).clearError();
      }
    });

    return Column(
      children: [
        if (!isPremium) _freeTrialBanner(isTr, state.freeQuestionsUsed),
        Expanded(
          child: state.messages.isEmpty
              ? _emptyState(isTr)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: state.messages.length + (state.loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= state.messages.length) {
                      return const _TypingIndicator();
                    }
                    final m = state.messages[i];
                    final isLast = i == state.messages.length - 1;
                    return _bubble(m, i, isTr, animate: isLast && !state.loading);
                  },
                ),
        ),
        if (exhausted) _trialEndedCard(isTr),
        _inputBar(isTr, state.loading, exhausted),
      ],
    );
  }

  // ── Free trial banner ──────────────────────────────────────────────

  Widget _freeTrialBanner(bool isTr, int used) {
    final shown = used > kFreeQuestionLimit ? kFreeQuestionLimit : used;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.brandTeal.withValues(alpha: 0.10),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard,
              size: 14, color: AppColors.brandTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isTr
                  ? 'Ücretsiz deneme: $shown/$kFreeQuestionLimit soru kullanıldı'
                  : 'Free trial: $shown/$kFreeQuestionLimit questions used',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.brandTeal),
            ),
          ),
        ],
      ),
    );
  }

  // ── Trial ended card ───────────────────────────────────────────────

  Widget _trialEndedCard(bool isTr) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandTeal.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  size: 18, color: AppColors.brandTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTr
                      ? 'Ücretsiz deneme sona erdi. Günde 40 soruluk AI asistan için '
                          'Premium\'a geçin!'
                      : 'Free trial ended. Upgrade to Premium for 40 AI questions/day!',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.lock_open, size: 18),
              label: Text(isTr ? 'Premium\'a Geç' : 'Upgrade'),
              onPressed: () => context.push(AppRoutes.subscription),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isTr) {
    final prompts = isTr
        ? const [
            'Bulgaristan\'da kaç gün kalabilirim?',
            'Arabamla Yunanistan\'a sigorta gerekiyor mu?',
            'Yanımda kaç Euro taşıyabilirim?',
          ]
        : const [
            'How many days can I stay in Bulgaria?',
            'Do I need insurance to drive to Greece?',
            'How much cash can I carry across the border?',
          ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Icon(Icons.bolt,
            color: AppColors.brandTeal.withValues(alpha: 0.8), size: 40),
        const SizedBox(height: 12),
        Text(
          isTr ? 'Ne sormak istersin?' : 'What would you like to ask?',
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        for (final p in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _input.text = p;
                _send();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 18, color: AppColors.brandTeal),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p, style: AppTextStyles.bodyMedium)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _AiExamplesCard(isTr: isTr),
      ],
    );
  }

  Widget _bubble(AIMessage m, int index, bool isTr, {required bool animate}) {
    final isUser = m.role == AIMessageRole.user;
    final isPlaying = _playingIndex == index;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              color: isUser ? AppColors.brandTeal : AppColors.surfaceCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: isUser
                ? Text(m.text,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.brandNavy))
                : (animate
                    ? _TypewriterText(text: m.text)
                    : Text(m.text, style: AppTextStyles.bodyMedium)),
          ),
        ),
        if (!isUser) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _toggleSpeak(m.text, index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined,
                      size: 14,
                      color: isPlaying
                          ? AppColors.danger
                          : AppColors.brandTeal,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPlaying
                          ? (isTr ? 'Durdur' : 'Stop')
                          : (isTr ? 'Dinle' : 'Listen'),
                      style: AppTextStyles.caption.copyWith(
                        color: isPlaying
                            ? AppColors.danger
                            : AppColors.brandTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 12),
      ],
    );
  }

  Widget _inputBar(bool isTr, bool loading, bool exhausted) {
    final blocked = loading || exhausted;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            if (_speechAvailable)
              FloatingActionButton.small(
                heroTag: 'mic',
                onPressed: blocked ? null : _toggleListening,
                backgroundColor: _isListening
                    ? AppColors.danger
                    : AppColors.surfaceCard,
                foregroundColor: _isListening
                    ? Colors.white
                    : AppColors.textSecondary,
                elevation: 0,
                child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none),
              ),
            if (_speechAvailable) const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _input,
                enabled: !exhausted,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: exhausted
                      ? (isTr
                          ? 'Ücretsiz deneme sona erdi'
                          : 'Free trial ended')
                      : _isListening
                          ? (isTr ? 'Dinleniyor…' : 'Listening…')
                          : (isTr ? 'Mesaj yaz…' : 'Type a message…'),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'send',
              onPressed: blocked ? null : _send,
              backgroundColor: blocked
                  ? AppColors.brandTeal.withValues(alpha: 0.35)
                  : AppColors.brandTeal,
              foregroundColor: AppColors.brandNavy,
              elevation: 0,
              child: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String code, bool isTr) {
    final msg = switch (code) {
      'no-subscription' => isTr
          ? 'Premium aboneliği gerekiyor.'
          : 'A Premium subscription is required.',
      'free_limit_reached' => isTr
          ? 'Ücretsiz deneme sona erdi. Günde 40 soruluk AI asistan için Premium\'a geçin!'
          : 'Free trial ended. Upgrade to Premium for 40 AI questions/day!',
      'rate-limit' => isTr
          ? 'Günlük soru limitine ulaştın. Yarın tekrar dene.'
          : 'You\'ve reached today\'s question limit. Try again tomorrow.',
      'network' => isTr
          ? 'İnternet bağlantısı yok. Bağlantını kontrol et ve tekrar dene.'
          : 'No internet connection. Check your connection and try again.',
      _ => isTr
          ? 'Bir sorun oluştu. Lütfen tekrar dene.'
          : 'Something went wrong. Please try again.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Typewriter reveal ─────────────────────────────────────────────────

class _TypewriterText extends StatefulWidget {
  const _TypewriterText({required this.text});
  final String text;

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 12), (t) {
      if (_shown >= widget.text.length) {
        t.cancel();
        return;
      }
      setState(() => _shown = (_shown + 3).clamp(0, widget.text.length));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text.substring(0, _shown),
      style: AppTextStyles.bodyMedium,
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.brandTeal,
          ),
        ),
      ),
    );
  }
}

// ── AI examples showcase ──────────────────────────────────────────────

class _AiExamplesCard extends StatelessWidget {
  const _AiExamplesCard({required this.isTr});
  final bool isTr;

  @override
  Widget build(BuildContext context) {
    final examples = isTr
        ? const [
            'Yakinimdaki change office nerede?',
            'eSIM satan bayi bul',
            'Buradan Milano kac km?',
            'Mayorka plaji UV endeksi ve nem orani nedir?',
            'Paris hava kirliligi ve yagmur tahmini?',
            'Hirvatistan gumrugundan kac kilo cikolata gecebilirim?',
            'Madridte ne yerim, neresi meshur?',
            'Romada nerede kalayim, hangi mahalle?',
            'Almanyada hiz limitleri nedir?',
            'Schengen vizesi nasil alinir?',
            'Fransada tax-free icin minimum ne kadar harcamam lazim?',
            'Bu urunum icin gumrukte ne kadar vergi oderim?',
          ]
        : const [
            'Find a currency exchange office nearby',
            'Find an eSIM provider near me',
            'How far is Milan from here?',
            'UV index and humidity at Mallorca beach?',
            'Paris air quality and rain forecast?',
            'How much chocolate can I bring through Croatian customs?',
            'What to eat in Madrid - what is famous?',
            'Where to stay in Rome - which neighbourhood?',
            'What are speed limits in Germany?',
            'How do I get a Schengen visa?',
            'Minimum spend for tax-free shopping in France?',
            'How much import tax for this item entering Turkey?',
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 16, color: AppColors.brandTeal),
              const SizedBox(width: 8),
              Text(
                isTr ? 'Soracaklarınızdan Bazıları' : 'Some of Your Questions',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.brandTeal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in examples) _AiExampleRow(text: e),
          const SizedBox(height: 4),
          Text(
            isTr ? 've diğer sormak istedikleriniz…' : 'and whatever else you\'d like to ask…',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiExampleRow extends StatelessWidget {
  const _AiExampleRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: AppColors.brandTeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
