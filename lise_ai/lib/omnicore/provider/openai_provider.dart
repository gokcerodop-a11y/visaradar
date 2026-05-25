// openai_provider.dart
// Stub OpenAI implementation of AIProvider.
//
// Phase 1: declares the interface and capabilities so the rest of the app
// can compile against it. isReady is hardcoded false; calling streamMessage
// throws AIProviderNotReadyException.
//
// Phase 5+: real HTTP / SSE transport will be filled in here.

import 'ai_message.dart';
import 'ai_provider.dart';

class OpenAIProvider extends AIProvider {
  /// Optional OpenAI API key — when null, the provider is not ready.
  final String? apiKey;

  /// Model identifier (e.g. "gpt-4o-mini"). Filled in when transport lands.
  final String model;

  const OpenAIProvider({this.apiKey, this.model = 'gpt-4o-mini'});

  @override
  AIProviderKind get kind => AIProviderKind.openai;

  @override
  AIProviderCapabilities get capabilities => const AIProviderCapabilities(
        supportsStreaming: true,
        supportsImages: true,
        supportsSystemPrompt: true,
        defaultMaxTokens: 2048,
      );

  @override
  bool get isReady => false; // No transport yet.

  @override
  Stream<String> streamMessage(
    List<AIMessage> history, {
    String? systemPrompt,
    int maxTokens = 2048,
  }) {
    throw const AIProviderNotReadyException(
      AIProviderKind.openai,
      'OpenAI provider Phase 5\'te bağlanacak. Şu an stub.',
    );
  }

  @override
  Future<String> sendOnce(
    List<AIMessage> history, {
    String? systemPrompt,
    int maxTokens = 2048,
  }) async {
    throw const AIProviderNotReadyException(
      AIProviderKind.openai,
      'OpenAI provider Phase 5\'te bağlanacak. Şu an stub.',
    );
  }
}
