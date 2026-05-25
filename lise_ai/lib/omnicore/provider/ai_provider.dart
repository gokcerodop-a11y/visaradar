// ai_provider.dart
// Provider-agnostic interface for streaming + one-shot LLM calls.
//
// Concrete implementations live in claude_provider.dart, openai_provider.dart
// and gemini_provider.dart. Apps depend on this abstract surface so a single
// configuration switch can change provider without touching call sites.

import 'ai_message.dart';

/// Identifies which backend a provider implementation talks to.
enum AIProviderKind {
  claude,
  openai,
  gemini,
}

/// Capabilities a provider advertises so callers can degrade gracefully.
class AIProviderCapabilities {
  final bool supportsStreaming;
  final bool supportsImages;
  final bool supportsSystemPrompt;
  final int defaultMaxTokens;

  const AIProviderCapabilities({
    required this.supportsStreaming,
    required this.supportsImages,
    required this.supportsSystemPrompt,
    required this.defaultMaxTokens,
  });
}

/// Raised when a provider is not configured (missing key, missing endpoint,
/// or stubbed in Phase 1) but the caller invoked it anyway.
class AIProviderNotReadyException implements Exception {
  final AIProviderKind kind;
  final String reason;

  const AIProviderNotReadyException(this.kind, this.reason);

  @override
  String toString() => 'AIProviderNotReadyException(${kind.name}: $reason)';
}

/// Common interface implemented by every concrete LLM provider.
abstract class AIProvider {
  const AIProvider();

  AIProviderKind get kind;

  AIProviderCapabilities get capabilities;

  /// True when the provider has everything it needs to take a call
  /// (e.g. API key set, endpoint reachable, transport initialized).
  /// Stub providers return false until they are filled in.
  bool get isReady;

  /// Stream tokens from the model.
  ///
  /// [history] is the full conversation so far. [systemPrompt] (if supported)
  /// is the steering prompt. [maxTokens] caps the response length.
  ///
  /// Implementations MUST throw [AIProviderNotReadyException] if
  /// [isReady] is false rather than failing silently.
  Stream<String> streamMessage(
    List<AIMessage> history, {
    String? systemPrompt,
    int maxTokens = 2048,
  });

  /// Non-streaming convenience that buffers the full response. Default
  /// implementation drains [streamMessage]; override when a provider
  /// has a separate single-shot endpoint.
  Future<String> sendOnce(
    List<AIMessage> history, {
    String? systemPrompt,
    int maxTokens = 2048,
  }) async {
    final buf = StringBuffer();
    await for (final chunk in streamMessage(
      history,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    )) {
      buf.write(chunk);
    }
    return buf.toString();
  }
}
