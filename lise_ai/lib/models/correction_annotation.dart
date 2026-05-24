import 'package:flutter/material.dart';

// ── AnnotationType ────────────────────────────────────────────────────────────

enum AnnotationType {
  errorCircle,      // red circle around wrong step/area
  correctMark,      // green check for right approach
  correctionArrow,  // animated arrow pointing to error source
  spotlight,        // focus oval — teacher draws eye to specific area
  textMarker,       // "Hata burada başladı" pinned label
  highlightLine,    // horizontal stripe highlight
  crossOut,         // strikethrough over wrong value/step
  underline,        // underline for emphasis
  bubbleNote,       // speech-bubble style annotation
}

// ── CorrectionAnnotation ──────────────────────────────────────────────────────
//
// A single teacher annotation on the student's work.
// All regions are normalized 0-1 relative to the image dimensions.

class CorrectionAnnotation {
  final String id;
  final AnnotationType type;

  /// Normalized region [0,1] x [0,1]. For point annotations use small w/h.
  final Rect region;

  final String? label;          // "Çarpım yanlış", "Hata burada başladı"
  final String? explanation;    // full sentence explanation
  final bool isError;           // true=red error, false=green correction

  /// Step index for sequential reveal (0 = first shown).
  final int revealStep;

  /// Optional: arrow target (normalized). If set, an arrow goes from region center to arrowTarget.
  final Offset? arrowTarget;

  const CorrectionAnnotation({
    required this.id,
    required this.type,
    required this.region,
    this.label,
    this.explanation,
    this.isError = true,
    this.revealStep = 0,
    this.arrowTarget,
  });

  Color get baseColor => isError ? const Color(0xFFF87171) : const Color(0xFF4ADE80);

  factory CorrectionAnnotation.fromJson(Map<String, dynamic> j, int step) {
    final type = _parseType(j['type'] as String? ?? 'errorCircle');
    final region = _parseRegion(j['region']);
    final arrowTarget = j['arrow_target'] != null
        ? _parseOffset(j['arrow_target'] as Map<String, dynamic>)
        : null;

    return CorrectionAnnotation(
      id: j['id'] as String? ?? 'ann_$step',
      type: type,
      region: region,
      label: j['label'] as String?,
      explanation: j['explanation'] as String?,
      isError: (j['is_error'] as bool?) ?? true,
      revealStep: step,
      arrowTarget: arrowTarget,
    );
  }

  static AnnotationType _parseType(String s) => switch (s) {
        'correctMark'     => AnnotationType.correctMark,
        'correctionArrow' => AnnotationType.correctionArrow,
        'spotlight'       => AnnotationType.spotlight,
        'textMarker'      => AnnotationType.textMarker,
        'highlightLine'   => AnnotationType.highlightLine,
        'crossOut'        => AnnotationType.crossOut,
        'underline'       => AnnotationType.underline,
        'bubbleNote'      => AnnotationType.bubbleNote,
        _                 => AnnotationType.errorCircle,
      };

  static Rect _parseRegion(dynamic r) {
    if (r == null) return const Rect.fromLTWH(0.3, 0.3, 0.4, 0.15);
    if (r is Map<String, dynamic>) {
      final x = (r['x'] as num?)?.toDouble() ?? 0.3;
      final y = (r['y'] as num?)?.toDouble() ?? 0.3;
      final w = (r['w'] as num?)?.toDouble() ?? 0.3;
      final h = (r['h'] as num?)?.toDouble() ?? 0.12;
      return Rect.fromLTWH(x, y, w, h);
    }
    return const Rect.fromLTWH(0.3, 0.3, 0.4, 0.15);
  }

  static Offset _parseOffset(Map<String, dynamic> m) {
    return Offset(
      (m['x'] as num?)?.toDouble() ?? 0.5,
      (m['y'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

// ── WorkAnalysisReport ────────────────────────────────────────────────────────
//
// Full structured report returned by WorkAnalysisService.

class WorkAnalysisReport {
  final String subject;
  final String topic;
  final List<String> errorSummary;          // plain-language mistake list
  final List<CorrectionAnnotation> annotations;
  final List<EquationStep> equationSteps;   // empty if no equations
  final String overallFeedback;             // teacher verdict (2-3 sentences)
  final double scoreEstimate;               // 0-1 correctness
  final bool hasHandwriting;
  final bool hasEquations;
  final bool hasGeometry;

  const WorkAnalysisReport({
    required this.subject,
    required this.topic,
    required this.errorSummary,
    required this.annotations,
    required this.equationSteps,
    required this.overallFeedback,
    required this.scoreEstimate,
    required this.hasHandwriting,
    required this.hasEquations,
    required this.hasGeometry,
  });

  static final empty = WorkAnalysisReport(
    subject: 'Belirsiz',
    topic: '',
    errorSummary: [],
    annotations: [],
    equationSteps: [],
    overallFeedback: 'Analiz tamamlanamadı.',
    scoreEstimate: 0.5,
    hasHandwriting: false,
    hasEquations: false,
    hasGeometry: false,
  );

  factory WorkAnalysisReport.fromJson(Map<String, dynamic> j) {
    final rawAnns = (j['annotations'] as List<dynamic>?) ?? [];
    final annotations = rawAnns.asMap().entries.map((e) {
      return CorrectionAnnotation.fromJson(
          e.value as Map<String, dynamic>, e.key);
    }).toList();

    final rawSteps = (j['equation_steps'] as List<dynamic>?) ?? [];
    final steps = rawSteps.map((s) {
      final m = s as Map<String, dynamic>;
      return EquationStep(
        displayText: m['text'] as String? ?? '',
        explanation: m['explanation'] as String? ?? '',
        isError: (m['is_error'] as bool?) ?? false,
        transformType: m['transform'] as String?,
      );
    }).toList();

    return WorkAnalysisReport(
      subject: j['subject'] as String? ?? 'Matematik',
      topic: j['topic'] as String? ?? '',
      errorSummary: List<String>.from(j['errors'] as List<dynamic>? ?? []),
      annotations: annotations,
      equationSteps: steps,
      overallFeedback: j['feedback'] as String? ?? '',
      scoreEstimate: (j['score'] as num?)?.toDouble() ?? 0.5,
      hasHandwriting: (j['has_handwriting'] as bool?) ?? false,
      hasEquations: (j['has_equations'] as bool?) ?? false,
      hasGeometry: (j['has_geometry'] as bool?) ?? false,
    );
  }
}

// ── EquationStep ──────────────────────────────────────────────────────────────

class EquationStep {
  final String displayText;
  final String explanation;
  final bool isError;
  final String? transformType; // "move_term", "simplify", "substitute", "solve"

  const EquationStep({
    required this.displayText,
    required this.explanation,
    required this.isError,
    this.transformType,
  });
}
