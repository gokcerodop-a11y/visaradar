import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AnthropicService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';
  static const _apiVersion = '2023-06-01';

  static const _systemPrompt = '''
Sen Türk lise öğrencilerine yardım eden zeki, sabırlı ve samimi bir yapay zeka öğretmenisin. Adın Lise AI.

Görevlerin:
- Matematik, Fizik, Kimya, Biyoloji, Tarih, Edebiyat ve diğer lise derslerinde yardım etmek
- Konuları açık, net ve anlaşılır bir şekilde açıklamak
- Soruları adım adım çözmek — her adımı kısaca açıklamak
- Öğrencinin gerçekten anladığından emin olmak için zaman zaman kısa takip soruları sormak
- Hataları nazikçe düzeltmek ve doğru yolu göstermek
- Eğlenceli ama olgun bir dil kullanmak — ne çok resmi ne de çocukça
- Emoji kullanabilirsin ama abartma; bir tane yeterliyse iki kullanma
- Fotoğraf gönderildiğinde: soruyu veya içeriği tanı, adım adım çöz
- Yanıtlarında markdown kullanabilirsin: **kalın**, *italik*, listeler, kod blokları

Yanıtlarını kısa ve odaklı tut. Öğrenci daha fazla detay isterse genişlet.
Türkçe yanıt ver.
''';

  final String _apiKey;
  final http.Client _client;

  AnthropicService(this._apiKey) : _client = http.Client();

  void dispose() => _client.close();

  // ── Streaming ──────────────────────────────────────────────────────────────

  /// Streams text tokens from Claude as they arrive (Server-Sent Events).
  /// Yields each text delta string. Throws [AnthropicException] on API errors.
  Stream<String> streamMessage(List<Map<String, dynamic>> history) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({
      'x-api-key': _apiKey,
      'anthropic-version': _apiVersion,
      'content-type': 'application/json',
      'accept': 'text/event-stream',
    });
    request.body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'stream': true,
      'system': _systemPrompt,
      'messages': history
          .map((e) => {'role': e['role'], 'content': e['content']})
          .toList(),
    });

    final streamed = await _client.send(request);

    if (streamed.statusCode == 401) {
      throw AnthropicException('API anahtarı geçersiz. Lütfen .env dosyasını kontrol et.');
    }
    if (streamed.statusCode != 200) {
      throw AnthropicException('Bir sorun oluştu (${streamed.statusCode}). Lütfen tekrar dene.');
    }

    // SSE line buffer — chunks may split across line boundaries.
    final lineBuffer = StringBuffer();

    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      lineBuffer.write(chunk);

      // Drain complete lines from the buffer.
      while (true) {
        final raw = lineBuffer.toString();
        final nl = raw.indexOf('\n');
        if (nl == -1) break;

        final line = raw.substring(0, nl).trimRight(); // strip \r too
        lineBuffer.clear();
        lineBuffer.write(raw.substring(nl + 1));

        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6);
        if (payload.isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        if (event['type'] == 'content_block_delta') {
          final delta = event['delta'] as Map<String, dynamic>?;
          if (delta?['type'] == 'text_delta') {
            final text = delta!['text'] as String?;
            if (text != null && text.isNotEmpty) yield text;
          }
        } else if (event['type'] == 'message_stop') {
          return;
        } else if (event['type'] == 'error') {
          final err = event['error'] as Map<String, dynamic>?;
          throw AnthropicException(err?['message']?.toString() ?? 'Bilinmeyen hata.');
        }
      }
    }
  }

  // ── Vision helpers ─────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> buildImageContent(
    List<int> imageBytes,
    String mimeType, {
    String text = '',
  }) {
    return [
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType,
          'data': base64Encode(imageBytes),
        },
      },
      {
        'type': 'text',
        'text': text.isEmpty
            ? 'Bu görseli analiz et ve Türkçe açıkla. Matematik sorusuysa adım adım çöz.'
            : text,
      },
    ];
  }
}

class AnthropicException implements Exception {
  final String message;
  const AnthropicException(this.message);

  @override
  String toString() => message;
}
