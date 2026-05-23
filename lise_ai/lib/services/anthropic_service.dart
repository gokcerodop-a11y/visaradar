import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/lesson_timeline.dart';
import '../models/whiteboard_element.dart';

class AnthropicService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';
  static const _apiVersion = '2023-06-01';

  // Raw string so $ and \ are not treated as Dart interpolation / escapes.
  static const _systemPrompt = r'''
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

Matematik ve formül yazım kuralları (ÇOK ÖNEMLİ):
- Satır içi (inline) formüller için: $formül$ kullan. Örnek: $x^2 + y^2 = r^2$
- Blok formüller için (kendi satırında, boş satırlarla çevrelenmiş): $$formül$$ kullan.
  Örnek: $$f'(x) = \lim_{h \to 0} \frac{f(x+h)-f(x)}{h}$$
- Tüm matematiği LaTeX formatında yaz — asla düz metin olarak yazma
- Örnekler: $\sqrt{x}$, $\frac{a}{b}$, $\int_0^1 x\,dx$, $$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$
- Markdown da kullanabilirsin: **kalın**, *italik*, listeler

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
Sen bir animasyonlu eğitim tahtası oluşturan matematik/fizik öğretmenisin.
SADECE geçerli JSON döndür — açıklama, kod bloğu işareti veya markdown kullanma.

JSON formatı:
{
  "title": "Konu başlığı (Türkçe, kısa)",
  "elements": [ ...element nesneleri... ]
}

ELEMENT TİPLERİ ve ZORUNLU ALANLARI:
step    → {"type":"step","content":"1","label":"Adım açıklama","x":0.04,"y":0.04,"delay":0}
text    → {"type":"text","content":"Metin","x":0.05,"y":0.12,"size":14,"delay":0.3}
formula → {"type":"formula","content":"f(x) = x²","x":0.05,"y":0.20,"size":18,"delay":0.6}
axes    → {"type":"axes","x":0.08,"y":0.75,"w":0.84,"h":0.55,"label":"x,y","color":"gray","delay":0.0}
line    → {"type":"line","x1":0.1,"y1":0.5,"x2":0.9,"y2":0.5,"color":"white","delay":1.0}
arrow   → {"type":"arrow","x1":0.3,"y1":0.6,"x2":0.6,"y2":0.4,"color":"orange","label":"F","delay":1.2}
vector  → {"type":"vector","x1":0.4,"y1":0.7,"x2":0.7,"y2":0.4,"color":"cyan","label":"|v|=5","delay":1.4}
circle  → {"type":"circle","cx":0.5,"cy":0.55,"r":0.12,"color":"green","label":"r=5","delay":1.0}
rect    → {"type":"rect","x":0.2,"y":0.3,"w":0.35,"h":0.2,"color":"blue","delay":1.5}
triangle→ {"type":"triangle","points":[[0.2,0.8],[0.5,0.3],[0.8,0.8]],"color":"orange","label":"A,B,C","delay":1.0}
curve   → {"type":"curve","points":[[0.08,0.6],[0.3,0.45],[0.55,0.5],[0.8,0.35],[0.92,0.4]],"color":"purple","label":"f(x)","delay":1.5}
parabola→ {"type":"parabola","cx":0.5,"cy":0.75,"a":1.5,"x1":0.08,"x2":0.92,"color":"purple","label":"y=ax²","delay":1.2}
sine    → {"type":"sine","x1":0.08,"x2":0.92,"y":0.6,"amplitude":0.18,"frequency":2,"color":"cyan","label":"sin(x)","delay":1.0}
point   → {"type":"point","x":0.5,"y":0.55,"label":"(1,2)","color":"yellow","delay":2.0}

KURALLAR:
- Koordinatlar 0.0–1.0 normalize (canvas'a göre). x/cx: 0.05–0.93, y/cy: 0.05–0.93
- Grafik varsa axes ilk element olmalı (delay:0.0)
- delay: 0'dan başla, elementler arası ~0.4–0.6s
- axes olmadan parabola/sine/curve ekleme
- parabola: cx/cy vertex noktası, a katsayısı 1.0–3.0, x1/x2 çizim aralığı
- sine: y merkez çizgisi, amplitude 0.10–0.25, frequency 1–4 döngü
- triangle: 3 köşe points, label virgüllü köşe adları "A,B,C"
- vector: fizik vektörleri (kuvvet, hız) — arrow'dan kalın
- formula: Unicode kullan: ×÷√∫∂→∞²³παβθΔΣ±≤≥
- Renkler: white purple blue green orange red yellow gray pink cyan
- Maksimum 14 element
- Türkçe etiket ve açıklamalar
- SADECE JSON döndür
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

  // ── Lesson generation ───────────────────────────────────────────────────────

  static const _lessonSystemPrompt = r'''
Sen gerçekçi bir canlı ders yapan matematik/fizik öğretmenisin.
SADECE geçerli JSON döndür — açıklama veya markdown kullanma.

Format:
{
  "title": "Konu Başlığı (Türkçe, 2-4 kelime)",
  "steps": [
    {
      "step_title": "Tanım",
      "text": "Öğrenciye hitap eden doğal Türkçe öğretmen anlatımı (2-4 cümle). Sanki öğrencinin karşısında duruyormuş gibi konuş.",
      "elements": [0, 1],
      "pause_after": 2.0
    }
  ],
  "elements": [ ...element nesneleri... ]
}

ELEMENT FORMATI:
step    → {"type":"step","content":"1","label":"Açıklama","x":0.04,"y":0.04,"delay":0}
text    → {"type":"text","content":"Metin","x":0.05,"y":0.10,"size":14,"delay":0.5}
formula → {"type":"formula","content":"f(x)=x²","x":0.05,"y":0.18,"size":18,"delay":1.0}
axes    → {"type":"axes","x":0.08,"y":0.75,"w":0.84,"h":0.55,"label":"x,y","color":"gray","delay":0.0}
line    → {"type":"line","x1":0.1,"y1":0.5,"x2":0.9,"y2":0.5,"color":"white","delay":1.5}
arrow   → {"type":"arrow","x1":0.3,"y1":0.6,"x2":0.6,"y2":0.4,"color":"orange","label":"F","delay":2.0}
vector  → {"type":"vector","x1":0.4,"y1":0.7,"x2":0.7,"y2":0.4,"color":"cyan","label":"|v|=5","delay":2.5}
circle  → {"type":"circle","cx":0.5,"cy":0.55,"r":0.12,"color":"green","label":"r=5","delay":1.5}
rect    → {"type":"rect","x":0.2,"y":0.3,"w":0.35,"h":0.2,"color":"blue","delay":2.0}
triangle→ {"type":"triangle","points":[[0.2,0.8],[0.5,0.3],[0.8,0.8]],"color":"orange","label":"A,B,C","delay":1.5}
curve   → {"type":"curve","points":[[0.08,0.6],[0.3,0.45],[0.55,0.5],[0.8,0.35]],"color":"purple","label":"f(x)","delay":2.0}
parabola→ {"type":"parabola","cx":0.5,"cy":0.75,"a":1.5,"x1":0.08,"x2":0.92,"color":"purple","label":"y=ax²","delay":1.5}
sine    → {"type":"sine","x1":0.08,"x2":0.92,"y":0.6,"amplitude":0.18,"frequency":2,"color":"cyan","label":"sin(x)","delay":1.5}
point   → {"type":"point","x":0.5,"y":0.55,"label":"(1,2)","color":"yellow","delay":3.0}

KURALLAR:
- Maksimum 4 step, maksimum 14 element
- Her adım kendi başına tam tahta sayfasıdır. Her adımda tahta temizlenir, yeni çizimler başlar.
- steps[i].elements: o adımda görünen elementlerin 0-based indeksleri (global liste, her adım kendi subset'ini kullanır)
- Her adımın elementleri delay=0.0'dan başlar. Element delay'ları: 0.0–4.0s arası (adım içi sıralama)
- Adım içi elementler arası: 0.5–1.0s
- pause_after: 1.5–2.5 (adım sonunda bekleme, saniye)
- step_title: 1-3 kelime, kısa etiket (ör: "Tanım", "Grafik", "Örnek", "Sonuç")
- text: gerçek öğretmen dili — "Şimdi şunu inceleyelim...", "Dikkat edin..." gibi
- Elementler tahtayı dengeli kullanmalı — tüm koordinat alanını kullan
- SADECE JSON döndür
''';

  /// Generates a synchronized lesson timeline with steps and whiteboard elements.
  Future<LessonTimeline?> generateLesson(
      String userQuestion, String assistantReply) async {
    final prompt =
        'Kullanıcının sorusu: "$userQuestion"\n\n'
        'Claude\'un cevabı: "$assistantReply"\n\n'
        'Bu konuyu anlatan adım adım Canlı Ders JSON\'u oluştur.';

    final response = await _client.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 2000,
        'system': _lessonSystemPrompt,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) return null;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          (body['content'] as List).first as Map<String, dynamic>;
      var raw = (content['text'] as String).trim();
      if (raw.startsWith('```')) {
        raw = raw.replaceFirst(RegExp(r'^```[a-z]*\n?'), '');
        raw = raw.replaceFirst(RegExp(r'\n?```$'), '');
      }
      final json = jsonDecode(raw.trim()) as Map<String, dynamic>;
      final lesson = LessonTimeline.fromJson(json);
      debugPrint(
          '[Lesson] Generated: ${lesson.steps.length} steps, ${lesson.elements.length} elements');
      return lesson;
    } catch (e) {
      debugPrint('[Lesson] Parse error: $e');
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

  /// Build a content block list for multiple PDF page images.
  static List<Map<String, dynamic>> buildMultiImageContent(
    List<Uint8List> pages, {
    String text = '',
  }) {
    final blocks = <Map<String, dynamic>>[];
    for (final pageBytes in pages) {
      blocks.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/png',
          'data': base64Encode(pageBytes),
        },
      });
    }
    blocks.add({
      'type': 'text',
      'text': text.isNotEmpty
          ? text
          : 'Bu PDF sayfalarındaki soruları ve konuları analiz et. '
              'Matematik/fen sorularını adım adım LaTeX ile çöz. Türkçe yanıtla.',
    });
    return blocks;
  }
}

class AnthropicException implements Exception {
  final String message;
  const AnthropicException(this.message);

  @override
  String toString() => message;
}
