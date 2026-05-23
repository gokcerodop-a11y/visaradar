import 'dart:convert';
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

Yanıtlarını kısa ve odaklı tut. Öğrenci daha fazla detay isterse genişlet.
Türkçe yanıt ver.
''';

  final String _apiKey;

  AnthropicService(this._apiKey);

  /// Sends the conversation history to Claude and returns the assistant reply.
  ///
  /// Each entry in [history] is a map with:
  ///   - "role": "user" or "assistant"
  ///   - "content": either a plain String (text-only) or a List of content
  ///     blocks (for vision messages).
  Future<String> sendMessage(List<Map<String, dynamic>> history) async {
    // Build the messages list — Anthropic accepts both string and list content.
    final messages = history.map((entry) {
      return {
        'role': entry['role'],
        'content': entry['content'],
      };
    }).toList();

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'system': _systemPrompt,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    }

    if (response.statusCode == 401) {
      throw AnthropicException('API anahtarı geçersiz. Lütfen .env dosyasını kontrol et.');
    }

    throw AnthropicException(
      'Bir sorun oluştu (${response.statusCode}). Lütfen tekrar dene.',
    );
  }

  /// Builds a vision content block list from [imageBytes] + optional [text].
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
