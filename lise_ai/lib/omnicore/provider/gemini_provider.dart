// gemini_provider.dart
// Stub Google Gemini implementation of AIProvider.
//
// Phase 1: stub. Phase 5+ wires the real transport.

import 'ai_message.dart';
import 'ai_provider.dart';

class GeminiProvider extends AIProvider {
  /// Optional Gemini API key — when null, the provider is not ready.
  final String? apiKey;

  /// Model identifier (e.g. "gemini-1.5-pro").
  final String model;

  const GeminiProvider({this.apiKey, this.model = 'gemini-1.5-pro'});

  @override
  AIProviderKind get kind => AIProviderKind.gemini;

  @override
  AIProviderCapabilities get capabilities => const AIProviderCapabilities(
        supportsStreaming: true,
        supportsImages: true,
        // Gemini uses "systemInstruction"; map at call time.
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
      AIProviderKind.gemini,
      'Gemini provider Phase 5\'te bağlanacak. Şu an stub.',
    );
  }

  @override
  Future<String> sendOnce(
    List<AIMessage> history, {
    String? systemPrompt,
    int maxTokens = 2048,
  }) async {
    throw const AIProviderNotReadyException(
      AIProviderKind.gemini,
      'Gemini provider Phase 5\'te bağlanacak. Şu an stub.',
    );
  }
}
