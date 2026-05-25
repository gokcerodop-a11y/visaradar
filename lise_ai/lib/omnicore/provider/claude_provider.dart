// claude_provider.dart
// AIProvider implementation backed by the existing AnthropicService.
//
// This is a thin adapter — it does NOT replace AnthropicService. It just
// gives callers the option to depend on the AIProvider interface instead
// of the concrete service. The original AnthropicService stays untouched,
// preserving every existing call site verbatim.

import 'dart:async';

import '../../services/anthropic_service.dart';
import 'ai_message.dart';
import 'ai_provider.dart';

class ClaudeProvider extends AIProvider {
  final AnthropicService _service;
  final bool _hasKey;

  ClaudeProvider(this._service, {required bool hasKey}) : _hasKey = hasKey;

  @override
  AIProviderKind get kind => AIProviderKind.claude;

  @override
  AIProviderCapabilities get capabilities => const AIProviderCapabilities(
        supportsStreaming: true,
        supportsImages: true,
        supportsSystemPrompt: true,
        defaultMaxTokens: 2048,
      );

  @override
  bool get isReady => _hasKey;

  @override
  Stream<String> streamMessage(
    List<AIMessage> history, {
    String? systemPrompt,
    int maxTokens = 2048,
  }) {
    if (!isReady) {
      throw const AIProviderNotReadyException(
        AIProviderKind.claude,
        'API anahtarı bulunamadı — Claude çağrısı yapılamıyor.',
      );
    }
    final claudeHistory = history.map((m) => m.toClaudeJson()).toList();
    return _service.streamMessage(
      claudeHistory,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );
  }
}
