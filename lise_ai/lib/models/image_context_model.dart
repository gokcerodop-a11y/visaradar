import 'dart:typed_data';

import 'package:flutter/material.dart';

// ── Visual content classification ─────────────────────────────────────────────

enum VisualContentType {
  question,   // solvable problem
  theory,     // concept/definition/formula
  mistake,    // student work with errors
  diagram,    // graph, chart, figure
  equation,   // pure math expressions
  table,      // tabular data
  figure,     // geometric shape
  mixed,      // combination
  unknown,
}

enum DiagramType {
  coordinateGraph,
  geometricFigure,
  chemicalStructure,
  physicsSetup,
  flowchart,
  numberTable,
  barChart,
  circuitDiagram,
  none,
}

enum VisualSubject {
  math,
  physics,
  chemistry,
  biology,
  geometry,
  algebra,
  calculus,
  turkish,
  history,
  other,
}

// What teaching mode the AI should enter
enum VisualMode { solutionMode, teachingMode, errorAnalysis }

// Future: swap backends without touching orchestration layer
enum VisionBackend { claude, gemini, openaiVision, localOcr }

// ── Detected equation ─────────────────────────────────────────────────────────

class DetectedEquation {
  final String raw;
  final String? latex;
  final bool isHandwritten;

  const DetectedEquation({
    required this.raw,
    this.latex,
    this.isHandwritten = false,
  });
}

// ── Analysis result ───────────────────────────────────────────────────────────

class ImageAnalysisResult {
  final VisualContentType contentType;
  final VisualMode suggestedMode;
  final DiagramType diagramType;
  final VisualSubject subject;
  final String? extractedText;      // OCR output
  final List<DetectedEquation> equations;
  final String? topicHint;          // e.g. "İkinci derece denklemler"
  final double complexityScore;     // 0–1
  final List<String> detectedMistakes;
  final bool hasHandwriting;
  final bool hasMathContent;
  final String? teachingSuggestion; // short Claude-generated hint for teacher

  const ImageAnalysisResult({
    required this.contentType,
    required this.suggestedMode,
    this.diagramType = DiagramType.none,
    this.subject = VisualSubject.other,
    this.extractedText,
    this.equations = const [],
    this.topicHint,
    this.complexityScore = 0.5,
    this.detectedMistakes = const [],
    this.hasHandwriting = false,
    this.hasMathContent = false,
    this.teachingSuggestion,
  });

  String get modeLabel => switch (suggestedMode) {
        VisualMode.solutionMode  => 'Çözüm Modu',
        VisualMode.teachingMode  => 'Öğretim Modu',
        VisualMode.errorAnalysis => 'Hata Analizi',
      };

  Color get modeColor => switch (suggestedMode) {
        VisualMode.solutionMode  => const Color(0xFF38BDF8),
        VisualMode.teachingMode  => const Color(0xFF7C6BF8),
        VisualMode.errorAnalysis => const Color(0xFFF87171),
      };

  /// Fallback result when analysis fails or is unavailable.
  static ImageAnalysisResult get unknown => const ImageAnalysisResult(
        contentType: VisualContentType.unknown,
        suggestedMode: VisualMode.teachingMode,
      );

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> j) {
    final ctStr = j['content_type'] as String? ?? 'unknown';
    final ct = VisualContentType.values.firstWhere(
        (v) => v.name == ctStr,
        orElse: () => VisualContentType.unknown);

    final modeStr = j['suggested_mode'] as String? ?? 'teachingMode';
    final mode = VisualMode.values.firstWhere(
        (v) => v.name == modeStr,
        orElse: () => VisualMode.teachingMode);

    final dtStr = j['diagram_type'] as String? ?? 'none';
    final dt = DiagramType.values.firstWhere(
        (v) => v.name == dtStr,
        orElse: () => DiagramType.none);

    final subjStr = j['subject'] as String? ?? 'other';
    final subj = VisualSubject.values.firstWhere(
        (v) => v.name == subjStr,
        orElse: () => VisualSubject.other);

    final rawEqs = (j['equations'] as List? ?? []);
    final eqs = rawEqs.map((e) {
      final m = e as Map<String, dynamic>;
      return DetectedEquation(
        raw: m['raw'] as String? ?? '',
        latex: m['latex'] as String?,
        isHandwritten: m['handwritten'] as bool? ?? false,
      );
    }).toList();

    return ImageAnalysisResult(
      contentType: ct,
      suggestedMode: mode,
      diagramType: dt,
      subject: subj,
      extractedText: j['ocr_text'] as String?,
      equations: eqs,
      topicHint: j['topic'] as String?,
      complexityScore:
          (j['complexity'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      detectedMistakes:
          (j['mistakes'] as List? ?? []).map((e) => e.toString()).toList(),
      hasHandwriting: j['has_handwriting'] as bool? ?? false,
      hasMathContent: j['has_math'] as bool? ?? false,
      teachingSuggestion: j['teaching_suggestion'] as String?,
    );
  }
}

// ── Session image context ─────────────────────────────────────────────────────

class ImageContext {
  final Uint8List imageBytes;
  final String mimeType;
  ImageAnalysisResult? analysisResult;

  // Overlay positioning
  Offset overlayPosition;
  double overlayScale;
  bool isVisible;

  // Compare mode: uploaded ↔ AI version
  bool isCompareMode;
  String? aiCorrectedDescription;

  // Spotlight / focus mode
  bool isSpotlightMode;
  Rect? spotlightRegion; // normalized 0–1 relative to overlay bounds

  // Animated teacher cursor position (normalized 0–1 within image)
  Offset? teacherCursorPos;

  // Session memory
  String? lastDiscussedElement;
  final List<String> discussionHistory;
  final DateTime capturedAt;

  ImageContext({
    required this.imageBytes,
    required this.mimeType,
    this.analysisResult,
    this.overlayPosition = const Offset(16, 100),
    this.overlayScale = 1.0,
    this.isVisible = true,
    this.isCompareMode = false,
    this.aiCorrectedDescription,
    this.isSpotlightMode = false,
    this.spotlightRegion,
    this.teacherCursorPos,
    this.lastDiscussedElement,
    List<String>? discussionHistory,
  })  : discussionHistory = discussionHistory ?? [],
        capturedAt = DateTime.now();

  void addDiscussion(String element) {
    lastDiscussedElement = element;
    discussionHistory.add(element);
    if (discussionHistory.length > 20) discussionHistory.removeAt(0);
  }

  /// Injects visual context into Claude system prompt.
  String buildContextBlock() {
    final r = analysisResult;
    if (r == null) {
      return '\n[GÖRSEL BAĞLAM]\nÖğrenci bir görsel paylaştı. Görseli analiz et ve yardımcı ol.\n';
    }

    final sb = StringBuffer();
    sb.writeln('\n[GÖRSEL BAĞLAM]');
    sb.writeln('İçerik türü: ${r.contentType.name}');
    sb.writeln('Konu: ${r.topicHint ?? r.subject.name}');
    sb.writeln('Önerilen mod: ${r.modeLabel}');
    if (r.extractedText?.isNotEmpty == true) {
      sb.writeln('OCR çıktısı: ${r.extractedText}');
    }
    if (r.equations.isNotEmpty) {
      sb.writeln('Tespit edilen denklemler:');
      for (final eq in r.equations) {
        sb.writeln('  - ${eq.latex ?? eq.raw}');
      }
    }
    if (r.detectedMistakes.isNotEmpty) {
      sb.writeln('Tespit edilen hatalar: ${r.detectedMistakes.join(", ")}');
    }
    if (r.hasHandwriting) sb.writeln('El yazısı içeriyor.');
    if (r.complexityScore > 0.7) sb.writeln('Karmaşık içerik (ileri seviye).');
    if (lastDiscussedElement != null) {
      sb.writeln('Son tartışılan element: $lastDiscussedElement');
    }
    if (r.teachingSuggestion?.isNotEmpty == true) {
      sb.writeln('Öğretim önerisi: ${r.teachingSuggestion}');
    }
    sb.writeln(
        'Öğrenci görselden bahsedince (şurayı, bu satır, grafiği, vb.) '
        'yukarıdaki bağlamı kullanarak yanıtla.');
    return sb.toString();
  }
}
