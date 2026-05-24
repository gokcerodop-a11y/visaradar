import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/image_context_model.dart';
import 'anthropic_service.dart';

// ── VisualReasoningEngine ─────────────────────────────────────────────────────
//
// Multimodal visual analysis pipeline:
//   1. Pre-process image (resize if needed)
//   2. Send to Claude Vision with structured analysis prompt
//   3. Parse JSON response → ImageAnalysisResult
//   4. Detect student visual reference keywords in messages
//   5. Build context-aware prompts for conversation integration
//
// Designed for future backend swap: Gemini Vision / GPT-4o Vision / local OCR.

class VisualReasoningEngine {
  final AnthropicService _anthropic;

  // Max bytes before we compress (Claude accepts up to ~5 MB base64)
  static const _maxBytes = 4 * 1024 * 1024;

  VisualReasoningEngine(this._anthropic);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Analyze an image and return a structured [ImageAnalysisResult].
  /// Returns [ImageAnalysisResult.unknown] on failure.
  Future<ImageAnalysisResult> analyzeImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    try {
      final processed = _preprocess(imageBytes);
      final json = await _callVisionApi(processed, mimeType);
      if (json == null) return ImageAnalysisResult.unknown;
      return ImageAnalysisResult.fromJson(json);
    } catch (e) {
      debugPrint('[VisualReasoningEngine] analyzeImage error: $e');
      return ImageAnalysisResult.unknown;
    }
  }

  /// Detect if user message references the uploaded visual.
  /// Returns a normalized hint string to inject, or null.
  String? detectVisualReference(String userMessage) {
    final lower = userMessage.toLowerCase();
    for (final kw in _referenceKeywords) {
      if (lower.contains(kw)) return kw;
    }
    return null;
  }

  /// Build a conversation-aware prompt that references an active ImageContext.
  String buildVisualPrompt(ImageContext ctx, String userMessage) {
    final ref = detectVisualReference(userMessage);
    final sb = StringBuffer();

    if (ref != null) {
      sb.writeln('[Öğrenci görsele atıfta bulunuyor: "$ref"]');
    }

    final r = ctx.analysisResult;
    if (r != null) {
      if (r.detectedMistakes.isNotEmpty && ref != null) {
        ctx.addDiscussion(ref);
        sb.writeln(
            'Bu satır/bölge hatalı olabilir. Hataları nazikçe açıkla: '
            '${r.detectedMistakes.join(", ")}');
      }
    }

    return sb.isEmpty ? userMessage : '${sb.toString().trim()}\n\n$userMessage';
  }

  // ── Internal: pre-process ──────────────────────────────────────────────────

  Uint8List _preprocess(Uint8List bytes) {
    // If already within limit, pass through.
    if (bytes.length <= _maxBytes) return bytes;
    // Truncation as last resort (real resize would need image package).
    // In practice, Flutter's file picker gives JPEG/PNG that are usually <4MB.
    return bytes.sublist(0, _maxBytes);
  }

  // ── Internal: Claude Vision API call ──────────────────────────────────────

  Future<Map<String, dynamic>?> _callVisionApi(
    Uint8List bytes,
    String mimeType,
  ) async {
    final b64 = base64Encode(bytes);

    // We use the non-streaming endpoint for structured JSON responses.
    // Re-use the same API key / client via AnthropicService internals.
    // We call `streamMessage` with a single-turn history.
    final analysisHistory = [
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mimeType,
              'data': b64,
            },
          },
          {
            'type': 'text',
            'text': _analysisPrompt,
          },
        ],
      },
    ];

    final buf = StringBuffer();
    await for (final token in _anthropic.streamMessage(
      analysisHistory,
      systemPrompt: _analysisSystemPrompt,
      maxTokens: 1024,
    )) {
      buf.write(token);
    }

    final raw = buf.toString().trim();
    // Extract JSON block (model may wrap in ```json ... ```)
    final jsonStr = _extractJson(raw);
    if (jsonStr == null) return null;

    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String? _extractJson(String raw) {
    // Try bare JSON first
    if (raw.startsWith('{')) return raw;

    // Strip ```json ... ``` fences
    final fence = RegExp(r'```(?:json)?\s*([\s\S]+?)\s*```');
    final m = fence.firstMatch(raw);
    if (m != null) return m.group(1);

    // Try to find { ... } block
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end > start) return raw.substring(start, end + 1);

    return null;
  }

  // ── Prompts ────────────────────────────────────────────────────────────────

  static const _analysisSystemPrompt = '''
Sen bir görsel analiz uzmanısın. Öğrencilerin yüklediği görselleri analiz edip yapılandırılmış JSON döndürüyorsun.
Yanıtın SADECE geçerli JSON olmalı — hiçbir açıklama ekleme, sadece JSON döndür.
''';

  static const _analysisPrompt = '''
Bu görseli analiz et ve şu JSON formatında yanıt ver:

{
  "content_type": "question|theory|mistake|diagram|equation|table|figure|mixed|unknown",
  "suggested_mode": "solutionMode|teachingMode|errorAnalysis",
  "diagram_type": "coordinateGraph|geometricFigure|chemicalStructure|physicsSetup|flowchart|numberTable|barChart|circuitDiagram|none",
  "subject": "math|physics|chemistry|biology|geometry|algebra|calculus|turkish|history|other",
  "ocr_text": "görseldeki tüm yazı/metin (yoksa null)",
  "equations": [
    {"raw": "ham denklem metni", "latex": "LaTeX karşılığı", "handwritten": true|false}
  ],
  "topic": "konu adı (örn. İkinci derece denklemler, Newton yasaları)",
  "complexity": 0.0-1.0,
  "mistakes": ["tespit edilen hata 1", "hata 2"],
  "has_handwriting": true|false,
  "has_math": true|false,
  "teaching_suggestion": "kısa öğretim önerisi (1 cümle, Türkçe)"
}

Kurallar:
- content_type: question = çözülecek soru, theory = konu/kural, mistake = hatalı öğrenci çalışması
- suggested_mode: solutionMode = soru var çözülmeli, teachingMode = konu anlatımı, errorAnalysis = hata düzeltme
- Metin yoksa ocr_text null bırak
- Hata tespit edilmezse mistakes boş liste []
- Yanıt SADECE JSON olmalı, başka hiçbir şey ekleme
''';

  // ── Visual reference keywords ──────────────────────────────────────────────

  static const _referenceKeywords = [
    'şurayı',
    'şurası',
    'burası',
    'burayı',
    'orayı',
    'orası',
    'bu satır',
    'bu adım',
    'bu kısım',
    'grafiği',
    'grafikte',
    'şekli',
    'şekilde',
    'tabloyu',
    'tabloda',
    'formülü',
    'denklemde',
    'çözümde',
    'hesapta',
    'neden yanlış',
    'anlamadım',
    'anlat',
    'tekrar çiz',
    'açıkla',
    'göster',
  ];
}

// ── VisualSubjectDetector ─────────────────────────────────────────────────────
//
// Lightweight client-side subject hint from filename/message (no API call).

class VisualSubjectDetector {
  static VisualSubject fromMessage(String message) {
    final lower = message.toLowerCase();
    if (_physics.any(lower.contains)) return VisualSubject.physics;
    if (_chemistry.any(lower.contains)) return VisualSubject.chemistry;
    if (_biology.any(lower.contains)) return VisualSubject.biology;
    if (_geometry.any(lower.contains)) return VisualSubject.geometry;
    if (_calculus.any(lower.contains)) return VisualSubject.calculus;
    if (_math.any(lower.contains)) return VisualSubject.math;
    return VisualSubject.other;
  }

  static const _physics = [
    'fizik', 'kuvvet', 'hız', 'ivme', 'enerji', 'newton',
    'elektrik', 'manyetik', 'dalga', 'optik', 'termodinamik',
  ];
  static const _chemistry = [
    'kimya', 'atom', 'molekül', 'bağ', 'reaksiyon', 'element',
    'periyodik', 'asit', 'baz', 'mol', 'çözelti',
  ];
  static const _biology = [
    'biyoloji', 'hücre', 'dna', 'gen', 'protein', 'enzim',
    'fotosentez', 'mitoz', 'mayoz', 'evrim',
  ];
  static const _geometry = [
    'geometri', 'üçgen', 'çember', 'açı', 'alan', 'çevre',
    'dik', 'ikizkenar', 'eşkenar', 'dörtgen', 'çokgen',
  ];
  static const _calculus = [
    'türev', 'integral', 'limit', 'fonksiyon', 'süreklilik',
    'maksimum', 'minimum', 'eğim',
  ];
  static const _math = [
    'matematik', 'denklem', 'kesir', 'oran', 'logaritma',
    'trigonometri', 'matris', 'determinant',
  ];
}
