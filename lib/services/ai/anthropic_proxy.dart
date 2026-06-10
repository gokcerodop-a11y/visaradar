// anthropic_proxy.dart
// Talks to the VisaRadar Cloudflare Worker (visaradar-proxy), which hides the
// Anthropic API key, validates the Apple receipt (bearer = original
// transaction id), enforces rate limits, and tunnels to Claude.
//
// Endpoints:
//   POST /v1/chat    { messages, context }            -> { text }
//   POST /v1/vision  { imageBase64, imageMediaType, userPrompt, context }
//                                                      -> { text }

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_message.dart';

/// Premium not active or receipt invalid.
class ProxySubscriptionRequiredException implements Exception {
  final String reason;
  const ProxySubscriptionRequiredException(this.reason);
  @override
  String toString() => 'ProxySubscriptionRequiredException($reason)';
}

/// Daily / monthly usage cap reached.
class ProxyRateLimitException implements Exception {
  final String reason;
  final String? resetAt;
  const ProxyRateLimitException(this.reason, this.resetAt);
  @override
  String toString() => 'ProxyRateLimitException($reason, resetAt=$resetAt)';
}

class AnthropicProxy {
  /// Production Worker URL. Same Cloudflare account subdomain as refakat-proxy.
  static const defaultBaseUrl = 'https://visaradar-proxy.gokcerodop.workers.dev';

  final String baseUrl;
  final String originalTransactionId;
  final String language; // 'tr' | 'en'
  final http.Client _client;

  AnthropicProxy({
    required this.originalTransactionId,
    String? baseUrl,
    this.language = 'tr',
    http.Client? client,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  void dispose() => _client.close();

  bool get isReady => originalTransactionId.isNotEmpty;

  Map<String, String> _headers() => {
        'authorization': 'Bearer $originalTransactionId',
        'content-type': 'application/json',
        'x-client-version': '1.0.0',
      };

  /// Text chat. Sends full history; the system prompt is composed server-side
  /// from the [systemPrompt] passed in `context`.
  Future<String> chat(
    List<AIMessage> history, {
    required String systemPrompt,
  }) async {
    final body = {
      'messages': history
          .map((m) => {'role': m.role.name, 'content': m.text})
          .toList(),
      'context': {'language': language, 'systemPrompt': systemPrompt},
    };
    return _post('/v1/chat', body);
  }

  /// Vision — analyse a single document/photo (passport, visa, permit).
  Future<String> vision({
    required AIImageAttachment image,
    required String userPrompt,
    required String systemPrompt,
  }) async {
    final body = {
      'imageBase64': base64Encode(image.bytes),
      'imageMediaType': image.mediaType,
      'userPrompt': userPrompt,
      'context': {'language': language, 'systemPrompt': systemPrompt},
    };
    return _post('/v1/vision', body);
  }

  Future<String> _post(String path, Map<String, dynamic> body) async {
    if (!isReady) {
      throw const ProxySubscriptionRequiredException('no-subscription');
    }
    final resp = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );

    if (resp.statusCode == 401 || resp.statusCode == 402) {
      throw ProxySubscriptionRequiredException(
        _field(resp.body, 'reason') ?? 'subscription-invalid',
      );
    }
    if (resp.statusCode == 429) {
      throw ProxyRateLimitException(
        _field(resp.body, 'reason') ?? 'rate-limited',
        _field(resp.body, 'resetAt'),
      );
    }
    if (resp.statusCode != 200) {
      debugPrint('[AnthropicProxy] HTTP ${resp.statusCode}: ${resp.body}');
      throw Exception('server-error-${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = (data['text'] as String?) ?? '';
    if (text.isEmpty) throw Exception('empty-response');
    return text;
  }

  String? _field(String body, String key) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return m[key] as String?;
    } catch (_) {
      return null;
    }
  }
}
