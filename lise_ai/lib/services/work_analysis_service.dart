import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;

import '../models/correction_annotation.dart';
import '../models/image_context_model.dart';
import 'anthropic_service.dart';

// ── WorkAnalysisService ───────────────────────────────────────────────────────
//
// Specialized Claude Vision pipeline for student work analysis.
// Detects:
//   - Wrong steps and calculation mistakes
//   - Skipped logic / missing justification
//   - Misconception patterns
//   - Formatting problems
//   - Geometry errors
//   - Equation decomposition steps
//
// Returns a WorkAnalysisReport with CorrectionAnnotations for the overlay.
//
// Future hooks:
//   - Camera live analysis (continuous frame analysis for desk scanning)
//   - Apple Pencil ink stream (analyze as student writes)
//   - Eye tracking focus zone (analyze where student looks)
//   - Wearable stress → adjust correction delivery speed

class WorkAnalysisService {
  final AnthropicService _anthropic;

  WorkAnalysisService(this._anthropic);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Analyze student work image and return a detailed correction report.
  /// This is distinct from the quick analyzeImage() in VisualReasoningEngine —
  /// this produces pedagogically rich correction data.
  Future<WorkAnalysisReport> analyzeStudentWork(
    ImageContext ctx, {
    String? hint, // optional teacher hint: "focus on algebra steps"
  }) async {
    try {
      final bytes = ctx.imageBytes;
      final mime = ctx.mimeType;
      final b64 = base64Encode(bytes);

      final prompt = _buildAnalysisPrompt(ctx, hint: hint);

      final history = [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': mime, 'data': b64},
            },
            {'type': 'text', 'text': prompt},
          ],
        },
      ];

      final buf = StringBuffer();
      await for (final token in _anthropic.streamMessage(
        history,
        systemPrompt: _systemPrompt,
        maxTokens: 2048,
      )) {
        buf.write(token);
      }

      final raw = buf.toString().trim();
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return WorkAnalysisReport.empty;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WorkAnalysisReport.fromJson(json);
    } catch (e) {
      debugPrint('[WorkAnalysisService] error: $e');
      return WorkAnalysisReport.empty;
    }
  }

  /// Quick geometry recognition — returns cleaned SVG path data or null.
  /// Future: feed into GeometryRenderEngine for clean redraws.
  Future<GeometryRecognitionResult?> recognizeGeometry(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    try {
      final b64 = base64Encode(imageBytes);
      final history = [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': mimeType, 'data': b64},
            },
            {'type': 'text', 'text': _geometryPrompt},
          ],
        },
      ];

      final buf = StringBuffer();
      await for (final token in _anthropic.streamMessage(
        history,
        systemPrompt: _systemPrompt,
        maxTokens: 512,
      )) {
        buf.write(token);
      }

      final raw = buf.toString().trim();
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return null;

      final j = jsonDecode(jsonStr) as Map<String, dynamic>;
      return GeometryRecognitionResult.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  // ── Prompts ────────────────────────────────────────────────────────────────

  static const _systemPrompt = '''
Sen bir Türk lise matematik/fen öğretmeninin öğrenci çalışması analiz asistanısın.
Görseli titizlikle incele, adım adım hataları tespit et.
Yanıtın SADECE geçerli JSON olmalı — hiçbir açıklama ekleme.
Öğrencinin çalışmasını analiz ederken nazik ama net ol.
Normalize koordinatlar: x ve y 0.0–1.0 arasında (görselin sol üstü 0,0; sağ alt 1,1).
''';

  String _buildAnalysisPrompt(ImageContext ctx, {String? hint}) {
    final existingTopic = ctx.analysisResult?.topicHint ?? '';
    return '''
Bu öğrenci çalışmasını analiz et ve şu JSON formatında dön:

{
  "subject": "math|physics|chemistry|biology|geometry|other",
  "topic": "konu adı (örn: İkinci Derece Denklemler)",
  "has_handwriting": true|false,
  "has_equations": true|false,
  "has_geometry": true|false,
  "errors": [
    "Hata açıklaması 1 (kısa, Türkçe)",
    "Hata açıklaması 2"
  ],
  "annotations": [
    {
      "id": "ann_0",
      "type": "errorCircle|correctMark|correctionArrow|textMarker|highlightLine|crossOut|underline|bubbleNote",
      "region": {"x": 0.1, "y": 0.2, "w": 0.4, "h": 0.08},
      "label": "Çarpım yanlış",
      "explanation": "3 × 4 = 12 olmalıydı, 14 yazılmış",
      "is_error": true,
      "arrow_target": {"x": 0.6, "y": 0.25}
    }
  ],
  "equation_steps": [
    {
      "text": "2x + 4 = 10",
      "explanation": "Başlangıç denklemi doğru",
      "is_error": false,
      "transform": null
    },
    {
      "text": "2x = 6",
      "explanation": "Her iki taraftan 4 çıkartıldı — doğru",
      "is_error": false,
      "transform": "move_term"
    }
  ],
  "feedback": "Genel değerlendirme: 2-3 cümle, Türkçe, öğretmen sesiyle",
  "score": 0.0–1.0
}

Kurallar:
- annotations: Her hata için 1 annotation. Bölgeler normalize (0-1).
- errorCircle: yanlış hesaplama veya adım
- textMarker: "Hata burada başladı" veya "Bu satırdan itibaren yanlış"
- highlightLine: kritik satır vurgusu
- crossOut: tamamen yanlış değer/adım
- correctionArrow: yanlış sonucu doğru sonuca bağlar
- correctMark: doğru yapılan adımlar için
- equation_steps: sadece denklem varsa doldur, yoksa boş liste []
- score: 1.0 = tamamen doğru, 0.0 = tamamen yanlış
${hint != null ? "- Öğretmen notu: $hint" : ""}
${existingTopic.isNotEmpty ? "- Konu bağlamı: $existingTopic" : ""}

Yanıt SADECE JSON olsun.
''';
  }

  static const _geometryPrompt = '''
Bu görseldeki geometrik şekli tanımla ve JSON döndür:
{
  "shape_type": "triangle|circle|rectangle|polygon|coordinate_system|function_graph|vector|angle|other",
  "properties": {
    "vertices": [[x1,y1],[x2,y2]],
    "angles": [90, 45, 45],
    "labels": ["A","B","C"],
    "special": "right_triangle|equilateral|isosceles|scalene|null"
  },
  "clean_description": "Düz çizgilerle çizilmiş, 90° köşeli dik üçgen",
  "teaching_approach": "Pisagor teoremi ile açıklanabilir"
}
Yanıt SADECE JSON.
''';

  static String? _extractJson(String raw) {
    if (raw.startsWith('{')) return raw;
    final fence = RegExp(r'```(?:json)?\s*([\s\S]+?)\s*```');
    final m = fence.firstMatch(raw);
    if (m != null) return m.group(1);
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end > start) return raw.substring(start, end + 1);
    return null;
  }
}

// ── GeometryRecognitionResult ─────────────────────────────────────────────────

class GeometryRecognitionResult {
  final String shapeType;
  final String cleanDescription;
  final String teachingApproach;
  final List<String> labels;
  final List<double> angles;

  const GeometryRecognitionResult({
    required this.shapeType,
    required this.cleanDescription,
    required this.teachingApproach,
    required this.labels,
    required this.angles,
  });

  factory GeometryRecognitionResult.fromJson(Map<String, dynamic> j) {
    final props = j['properties'] as Map<String, dynamic>? ?? {};
    final rawLabels = props['labels'] as List<dynamic>? ?? [];
    final rawAngles = props['angles'] as List<dynamic>? ?? [];

    return GeometryRecognitionResult(
      shapeType: j['shape_type'] as String? ?? 'other',
      cleanDescription: j['clean_description'] as String? ?? '',
      teachingApproach: j['teaching_approach'] as String? ?? '',
      labels: rawLabels.map((e) => e.toString()).toList(),
      angles: rawAngles.map((e) => (e as num).toDouble()).toList(),
    );
  }
}

// ── CameraLearningService stub ────────────────────────────────────────────────
//
// Future: live camera frame processing for desk scanning / notebook tracking.
// Architecture prepared — no functional implementation yet.
//
// Integration points:
//   - camera_controller: flutter_camera package frame stream
//   - WorkAnalysisService.analyzeStudentWork() called on captured frames
//   - AttentionEngine.recordUserInput() fed gaze/gesture signals
//   - Visual overlay shows real-time corrections on camera feed

abstract class CameraLearningInterface {
  /// Initialize camera (front/back for desk scanning).
  Future<bool> initialize();

  /// Capture current frame for analysis.
  Future<Uint8List?> captureFrame();

  /// Start continuous tracking (calls onFrame every ~2 seconds).
  void startTracking({required void Function(Uint8List frame) onFrame});

  /// Stop tracking.
  void stopTracking();

  /// Dispose camera resources.
  Future<void> dispose();
}

// ── ApplePencilInputHandler stub ──────────────────────────────────────────────
//
// Future: Apple Pencil + iPad Pro realtime ink capture.
// Architecture prepared for:
//   - scribble_kit: UIScribbleInteraction for iPad text input
//   - pencilkit: PKDrawing for ink capture
//   - Teacher annotation layer synchronized with student work
//   - Collaborative board: student writes, AI teacher annotates in real-time

abstract class PencilInputInterface {
  /// Called when pencil touches canvas.
  void onStrokeBegin(Offset position, double pressure, double azimuth);

  /// Called for each point during stroke.
  void onStrokeMove(Offset position, double pressure);

  /// Called when pencil lifts.
  void onStrokeEnd();

  /// Get all strokes as replay data.
  List<Map<String, dynamic>> exportStrokes();

  /// Clear canvas.
  void clearCanvas();
}
