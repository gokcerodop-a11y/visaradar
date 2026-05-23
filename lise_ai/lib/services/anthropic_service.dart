import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/whiteboard_element.dart';

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

  // ── Whiteboard generation ──────────────────────────────────────────────────

  static const _wbSystemPrompt = '''
Sen bir matematik/fizik öğretmenisin. Verilen konu için görsel bir tahta (whiteboard) JSON'u oluştur.
SADECE geçerli JSON döndür, başka hiçbir şey yazma — açıklama, kod bloğu işareti veya markdown kullanma.

JSON formatı:
{
  "title": "Konu başlığı (Türkçe, kısa)",
  "elements": [
    {"type": "step", "content": "1", "label": "Adım 1: ...", "x": 0.04, "y": 0.04, "delay": 0},
    {"type": "text", "content": "Açıklama metni", "x": 0.04, "y": 0.13, "size": 14, "delay": 0.3},
    {"type": "formula", "content": "f(x) = x²", "x": 0.04, "y": 0.22, "size": 17, "delay": 0.6},
    {"type": "axes", "x": 0.08, "y": 0.72, "w": 0.75, "h": 0.28, "label": "x,y", "delay": 0.9},
    {"type": "curve", "points": [[0.08,0.72],[0.25,0.62],[0.45,0.55],[0.65,0.51],[0.83,0.50]], "color": "purple", "label": "f(x)", "delay": 1.2},
    {"type": "arrow", "x1": 0.3, "y1": 0.3, "x2": 0.6, "y2": 0.2, "color": "orange", "label": "F⃗", "delay": 1.5},
    {"type": "circle", "cx": 0.5, "cy": 0.5, "r": 0.1, "color": "green", "label": "çember", "delay": 1.8},
    {"type": "point", "x": 0.45, "y": 0.55, "label": "(1, 1)", "color": "yellow", "delay": 2.0},
    {"type": "line", "x1": 0.1, "y1": 0.4, "x2": 0.9, "y2": 0.4, "color": "gray", "delay": 2.2}
  ]
}

Kurallar:
- Tüm koordinatlar 0.0–1.0 arasında normalize edilmiştir (canvas boyutuna göre)
- x/cx: 0.04–0.95, y/cy: 0.04–0.95 arasında tut
- delay değerleri 0'dan başlayıp kademeli artar (her element öncekinden ~0.3s sonra)
- step tipi: numaralı adım işaretçisi (küçük mor daire + label)
- formula tipi: matematik formülü (Unicode: ×, ÷, √, ∫, ∂, →, ∞, ², ³, π, α, β, θ, Δ, Σ)
- Renk isimleri: white, purple, blue, green, orange, red, yellow, gray, pink, cyan
- Maksimum 12 element (okunabilirlik için)
- Türkçe etiketler ve açıklamalar kullan
- Sadece JSON döndür, başka hiçbir şey yazma
''';

  /// Generates whiteboard drawing data for a math/physics explanation.
  /// Returns null if generation fails or response is not parseable JSON.
  Future<WhiteboardData?> generateWhiteboard(
    String userQuestion,
    String assistantReply,
  ) async {
    final prompt =
        'Kullanıcının sorusu: "$userQuestion"\n\nClaude\'un cevabı: "$assistantReply"\n\nBu konuyu görselleştiren bir tahta JSON\'u oluştur.';

    final response = await _client.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1500,
        'system': _wbSystemPrompt,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) return null;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (body['content'] as List).first as Map<String, dynamic>;
      var raw = content['text'] as String;

      // Strip markdown code fences if Claude wraps with ```json
      raw = raw.trim();
      if (raw.startsWith('```')) {
        raw = raw.replaceFirst(RegExp(r'^```[a-z]*\n?'), '');
        raw = raw.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(raw.trim()) as Map<String, dynamic>;
      return WhiteboardData.fromJson(json);
    } catch (_) {
      return null;
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
