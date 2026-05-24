import 'dart:convert';

import '../models/image_context_model.dart';
import '../models/lesson_timeline.dart';
import '../models/whiteboard_element.dart';
import 'anthropic_service.dart';

// ── BoardRedrawService ────────────────────────────────────────────────────────
//
// Translates an ImageAnalysisResult into a LessonTimeline for whiteboard
// redraw. Uses Claude to generate structured step-by-step redraw when
// content is complex; falls back to lightweight template for simple cases.

class BoardRedrawService {
  final AnthropicService _anthropic;

  BoardRedrawService(this._anthropic);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generate a whiteboard lesson from an image analysis result.
  /// Falls back to a simple OCR-based lesson on failure.
  Future<LessonTimeline?> generateFromImage(ImageContext ctx) async {
    final result = ctx.analysisResult;
    if (result == null) return null;

    // For pure text / simple content, generate via Claude
    try {
      return await _generateViaClaudeLesson(ctx, result);
    } catch (_) {
      return _fallbackLesson(result);
    }
  }

  // ── Claude-powered redraw ──────────────────────────────────────────────────

  Future<LessonTimeline?> _generateViaClaudeLesson(
    ImageContext ctx,
    ImageAnalysisResult result,
  ) async {
    final prompt = _buildRedrawPrompt(result);
    final history = [
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': ctx.mimeType,
              'data': base64Encode(ctx.imageBytes),
            },
          },
          {'type': 'text', 'text': prompt},
        ],
      },
    ];

    return await _anthropic.generateLessonFromHistory(history);
  }

  String _buildRedrawPrompt(ImageAnalysisResult result) {
    final mode = result.suggestedMode;
    final topic = result.topicHint ?? result.subject.name;

    return switch (mode) {
      VisualMode.solutionMode => '''
Bu görseldeki soruyu tahtada adım adım çöz.
Konu: $topic
${result.equations.isNotEmpty ? 'Tespit edilen denklemler: ${result.equations.map((e) => e.latex ?? e.raw).join(", ")}' : ''}

Çözümü bir LessonTimeline olarak oluştur.
Her adımı net açıkla ve whiteboard elementleri ile görselleştir.
${AnthropicService.lessonJsonInstructions}
''',
      VisualMode.errorAnalysis => '''
Bu görselde öğrencinin yaptığı hataları analiz et ve doğrusunu tahtada göster.
Konu: $topic
Tespit edilen hatalar: ${result.detectedMistakes.join(", ")}

Önce hatayı açıkla, sonra doğru çözümü adım adım göster.
${AnthropicService.lessonJsonInstructions}
''',
      VisualMode.teachingMode => '''
Bu görseldeki kavramı/konuyu tahtada anlat.
Konu: $topic
${result.extractedText != null ? 'İçerik: ${result.extractedText}' : ''}

Konuyu adım adım, görsel olarak açıkla.
${AnthropicService.lessonJsonInstructions}
''',
    };
  }

  // ── Fallback: template-based lesson ───────────────────────────────────────

  LessonTimeline _fallbackLesson(ImageAnalysisResult result) {
    final topic = result.topicHint ?? 'Görsel Analiz';
    final mode = result.suggestedMode;

    final elements = <WhiteboardElement>[];
    final steps = <LessonStep>[];

    // Title
    elements.add(WhiteboardElement(
      type: WBType.text,
      content: topic,
      x: 0.5,
      y: 0.08,
      fontSize: 22,
      delay: 0.0,
      colorName: 'white',
    ));

    if (mode == VisualMode.errorAnalysis && result.detectedMistakes.isNotEmpty) {
      // Highlight each mistake
      for (int i = 0; i < result.detectedMistakes.length; i++) {
        final mistake = result.detectedMistakes[i];
        elements.add(WhiteboardElement(
          type: WBType.text,
          content: '✗ $mistake',
          x: 0.5,
          y: 0.20 + i * 0.12,
          fontSize: 14,
          delay: 0.8 + i * 0.5,
          colorName: 'red',
        ));
      }
      steps.add(LessonStep(
        stepTitle: 'Hata',
        text: 'Görselde ${result.detectedMistakes.length} hata tespit edildi.',
        elementIndices: List.generate(result.detectedMistakes.length, (i) => i + 1),
        pauseAfter: 2.0,
      ));
    } else if (result.extractedText?.isNotEmpty == true) {
      final text = result.extractedText!;
      elements.add(WhiteboardElement(
        type: WBType.text,
        content: text.length > 200 ? '${text.substring(0, 200)}…' : text,
        x: 0.5,
        y: 0.35,
        fontSize: 13,
        delay: 0.5,
        colorName: 'white',
      ));
      steps.add(LessonStep(
        stepTitle: 'İçerik',
        text: 'Görseldeki içerik tahtaya aktarıldı.',
        elementIndices: [1],
        pauseAfter: 2.0,
      ));
    } else {
      elements.add(WhiteboardElement(
        type: WBType.text,
        content: 'Görsel analiz edildi',
        x: 0.5,
        y: 0.35,
        fontSize: 16,
        delay: 0.5,
        colorName: 'gray',
      ));
      steps.add(LessonStep(
        stepTitle: 'Analiz',
        text: 'Görsel işlendi.',
        elementIndices: [1],
        pauseAfter: 1.5,
      ));
    }

    return LessonTimeline(
      title: topic,
      steps: steps,
      elements: elements,
    );
  }
}
