import 'dart:async';

import 'package:flutter/material.dart';

import '../models/correction_annotation.dart';
import '../models/image_context_model.dart';
import '../services/teacher_pen_engine.dart';
import '../services/work_analysis_service.dart';
import '../widgets/visual_correction_layer.dart';

// ── VisualTeachingScreen ──────────────────────────────────────────────────────
//
// Full-screen visual teaching experience.
// "A real teacher is actively reviewing MY work."
//
// Flow:
//   1. Load image + run WorkAnalysisService (show analyzing spinner)
//   2. Teacher "pauses" 1.5s before first annotation (studies the work)
//   3. Spotlight appears on first error region
//   4. Circle draws itself around the error
//   5. Pen marks the mistake
//   6. Explanation text slides in from left (teacher speaks)
//   7. Tap "İleri" to advance to next step
//   8. Green checkmarks appear for correct parts
//
// Visual teaching modes:
//   - Çözüm (Solution walkthrough)
//   - Hata Analizi (Error analysis — default when mistakes detected)
//   - Öğretim (Teaching from scratch)
//   - İpucu (Hint mode — partial reveal only)
//   - Sınav Koçu (Exam coach — time pressure, faster pacing)
//   - Sessiz Görsel Çözüm (Silent visual — no text, only marks)

enum VisualTeachingMode {
  cozum,           // Çözüm — solution walkthrough
  hataAnalizi,     // Hata Analizi — error correction
  ogretim,         // Öğretim — concept teaching
  ipucu,           // İpucu — hints only
  sinavKocu,       // Sınav Koçu — exam pace
  sessizGorsel,    // Sessiz Görsel — silent visual marks
}

extension VisualTeachingModeExt on VisualTeachingMode {
  String get label => switch (this) {
        VisualTeachingMode.cozum        => 'Çözüm',
        VisualTeachingMode.hataAnalizi  => 'Hata Analizi',
        VisualTeachingMode.ogretim      => 'Öğretim',
        VisualTeachingMode.ipucu        => 'İpucu',
        VisualTeachingMode.sinavKocu   => 'Sınav Koçu',
        VisualTeachingMode.sessizGorsel => 'Sessiz Görsel',
      };

  Color get color => switch (this) {
        VisualTeachingMode.hataAnalizi  => const Color(0xFFF87171),
        VisualTeachingMode.cozum        => const Color(0xFF4ADE80),
        VisualTeachingMode.ogretim      => const Color(0xFF7C6BF8),
        VisualTeachingMode.ipucu        => const Color(0xFFFBBF24),
        VisualTeachingMode.sinavKocu   => const Color(0xFFF97316),
        VisualTeachingMode.sessizGorsel => const Color(0xFF9CA3AF),
      };
}

// ── VisualTeachingScreen ──────────────────────────────────────────────────────

class VisualTeachingScreen extends StatefulWidget {
  final ImageContext imageCtx;
  final WorkAnalysisService analysisService;
  final VisualTeachingMode initialMode;
  final String teacherName;

  const VisualTeachingScreen({
    super.key,
    required this.imageCtx,
    required this.analysisService,
    this.initialMode = VisualTeachingMode.hataAnalizi,
    this.teacherName = 'Öğretmen',
  });

  @override
  State<VisualTeachingScreen> createState() => _VisualTeachingScreenState();
}

class _VisualTeachingScreenState extends State<VisualTeachingScreen>
    with TickerProviderStateMixin {

  // Analysis state
  bool _analyzing = true;
  WorkAnalysisReport? _report;

  // Teaching mode
  late VisualTeachingMode _mode;

  // Step reveal: how many annotation steps revealed
  int _revealStep = 0;

  // Teacher pause before first mark
  bool _teacherPausing = false;

  // Spotlight target (normalized)
  Offset? _spotlightTarget;

  // Pen engine
  late final TeacherPenEngine _penEngine;
  bool _penReplaying = false;

  // Explanation panel
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;
  String _currentExplanation = '';
  String _currentLabel = '';

  // Auto-advance for sınav kocu mode
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _penEngine = TeacherPenEngine();

    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));

    _startAnalysis();
  }

  @override
  void dispose() {
    _penEngine.dispose();
    _panelCtrl.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  // ── Analysis ───────────────────────────────────────────────────────────────

  Future<void> _startAnalysis() async {
    setState(() => _analyzing = true);

    final report = await widget.analysisService.analyzeStudentWork(widget.imageCtx);

    if (!mounted) return;
    setState(() {
      _report = report;
      _analyzing = false;
    });

    // Teacher "studies the work" before marking
    _teacherPause();
  }

  Future<void> _teacherPause() async {
    setState(() => _teacherPausing = true);
    // Deliberately wait — feels like teacher is looking at the work
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _teacherPausing = false);

    // Begin first annotation
    if (_report != null && _report!.annotations.isNotEmpty) {
      _advanceStep();
    }

    // Sınav kocu: auto-advance every 6 seconds
    if (_mode == VisualTeachingMode.sinavKocu) {
      _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) _advanceStep();
      });
    }
  }

  // ── Step advance ───────────────────────────────────────────────────────────

  void _advanceStep() {
    final report = _report;
    if (report == null) return;

    final maxStep = report.annotations
        .map((a) => a.revealStep)
        .fold(0, math.max) + 1;

    if (_revealStep >= maxStep) return;

    // Find annotations for this step
    final stepAnns = report.annotations
        .where((a) => a.revealStep == _revealStep)
        .toList();

    // Spotlight the first annotation in this step
    if (stepAnns.isNotEmpty) {
      final ann = stepAnns.first;
      _moveSpotlight(ann.region.center);

      // Show explanation
      final explanation = ann.explanation ?? ann.label ?? '';
      if (explanation.isNotEmpty && _mode != VisualTeachingMode.sessizGorsel) {
        _showExplanation(explanation, ann.label ?? '');
      }

      // Generate and replay pen strokes for this annotation
      _generatePenStrokes(stepAnns);
    }

    setState(() => _revealStep++);
  }

  void _previousStep() {
    if (_revealStep <= 0) return;
    setState(() {
      _revealStep--;
      _penEngine.clear();
      _currentExplanation = '';
      _panelCtrl.reverse();
    });
  }

  // ── Spotlight ──────────────────────────────────────────────────────────────

  Future<void> _moveSpotlight(Offset target) async {
    // Smoothly move spotlight — feels like teacher's eye moving
    setState(() => _spotlightTarget = target);
    // Clear spotlight after a moment
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _spotlightTarget = null);
  }

  // ── Explanation panel ──────────────────────────────────────────────────────

  void _showExplanation(String explanation, String label) {
    setState(() {
      _currentExplanation = explanation;
      _currentLabel = label;
    });
    _panelCtrl.forward(from: 0);
  }

  // ── Pen strokes ────────────────────────────────────────────────────────────

  void _generatePenStrokes(List<CorrectionAnnotation> annotations) {
    final strokes = <PenStroke>[];
    for (final ann in annotations) {
      switch (ann.type) {
        case AnnotationType.errorCircle:
        case AnnotationType.spotlight:
          strokes.add(TeacherPenEngine.circle(
            ann.region,
            ann.isError ? PenMode.redCorrection : PenMode.greenConfirmation,
            prePause: const Duration(milliseconds: 500),
          ));
        case AnnotationType.correctMark:
          strokes.add(TeacherPenEngine.checkmark(
            ann.region,
            PenMode.greenConfirmation,
          ));
        case AnnotationType.crossOut:
        case AnnotationType.highlightLine:
          strokes.add(TeacherPenEngine.line(
            ann.region,
            ann.isError ? PenMode.redCorrection : PenMode.blueExplanation,
            strikethrough: ann.type == AnnotationType.crossOut,
          ));
        case AnnotationType.underline:
          strokes.add(TeacherPenEngine.line(
            ann.region,
            PenMode.blueExplanation,
            strikethrough: false,
          ));
        default:
          break;
      }
    }

    if (strokes.isNotEmpty) {
      _penEngine.addStrokes(strokes);
      setState(() => _penReplaying = true);
      _penEngine.replayAll(onComplete: () {
        if (mounted) setState(() => _penReplaying = false);
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _analyzing ? _buildAnalyzing() : _buildTeachingView(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF4B5563), size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'Görsel Analiz',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // Mode selector
          _ModePill(
            current: _mode,
            onSelected: (m) {
              setState(() {
                _mode = m;
                _revealStep = 0;
                _penEngine.clear();
                _panelCtrl.reverse();
              });
              if (!_analyzing) _teacherPause();
            },
          ),
        ],
      ),
    );
  }

  // ── Analyzing spinner ──────────────────────────────────────────────────────

  Widget _buildAnalyzing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF7C6BF8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.teacherName} inceliyor…',
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Adım adım analiz ediliyor',
            style: TextStyle(color: Color(0xFF374151), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Main teaching view ─────────────────────────────────────────────────────

  Widget _buildTeachingView() {
    final report = _report;
    return Column(
      children: [
        // Image + annotation overlay
        Expanded(
          flex: 3,
          child: _buildImageWithOverlays(report),
        ),

        // Equation steps (if any)
        if (report != null && report.equationSteps.isNotEmpty && _mode != VisualTeachingMode.sessizGorsel)
          _EquationStepsPanel(
            steps: report.equationSteps,
            revealCount: _revealStep + 1,
          ),

        // Teacher explanation panel
        if (_currentExplanation.isNotEmpty &&
            _mode != VisualTeachingMode.sessizGorsel)
          SlideTransition(
            position: _panelSlide,
            child: _ExplanationPanel(
              label: _currentLabel,
              text: _currentExplanation,
              teacherName: widget.teacherName,
            ),
          ),

        // Overall feedback (after all steps revealed)
        if (report != null && _allStepsRevealed(report) && report.overallFeedback.isNotEmpty)
          _FeedbackPanel(
            feedback: report.overallFeedback,
            score: report.scoreEstimate,
            teacherName: widget.teacherName,
          ),
      ],
    );
  }

  Widget _buildImageWithOverlays(WorkAnalysisReport? report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            // Image
            Positioned.fill(
              child: Image.memory(
                widget.imageCtx.imageBytes,
                fit: BoxFit.contain,
              ),
            ),

            // Correction overlay
            if (report != null)
              Positioned.fill(
                child: VisualCorrectionLayer(
                  annotations: report.annotations,
                  currentRevealStep: _revealStep,
                  spotlightCenter: _spotlightTarget,
                ),
              ),

            // Pen canvas
            Positioned.fill(
              child: TeacherPenCanvas(
                engine: _penEngine,
                imageSize: size,
              ),
            ),

            // "Teacher studying" overlay
            if (_teacherPausing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                  child: Center(
                    child: Text(
                      '${widget.teacherName} inceliyor…',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),

            // Error summary chip (top-right)
            if (report != null && report.errorSummary.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: _ErrorCountChip(count: report.errorSummary.length),
              ),

            // Subject / topic chip (top-left)
            if (report != null)
              Positioned(
                top: 8,
                left: 8,
                child: _SubjectChip(
                  subject: report.subject,
                  topic: report.topic,
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    final report = _report;
    final maxStep = report == null
        ? 0
        : (report.annotations.isEmpty
            ? 0
            : report.annotations.map((a) => a.revealStep).fold(0, math.max) + 1);
    final allRevealed = _allStepsRevealed(report);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Step counter
          Text(
            _analyzing
                ? 'Analiz ediliyor…'
                : allRevealed
                    ? 'Tümü gösterildi'
                    : 'Adım ${_revealStep + 1} / $maxStep',
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
          ),
          const Spacer(),

          // Prev
          if (_revealStep > 0)
            _ControlBtn(
              icon: Icons.arrow_back_rounded,
              onTap: _previousStep,
              tooltip: 'Önceki',
            ),
          const SizedBox(width: 8),

          // Next / Reveal all
          if (!_analyzing && !allRevealed)
            _ControlBtn(
              icon: Icons.arrow_forward_rounded,
              color: _mode.color,
              onTap: _advanceStep,
              tooltip: 'İleri',
              label: 'İleri',
            ),

          if (!_analyzing && allRevealed && report != null)
            _ControlBtn(
              icon: Icons.replay_rounded,
              onTap: () {
                setState(() {
                  _revealStep = 0;
                  _penEngine.clear();
                  _currentExplanation = '';
                  _panelCtrl.reverse();
                });
                _teacherPause();
              },
              tooltip: 'Başa dön',
              label: 'Yeniden',
            ),

          const SizedBox(width: 8),

          // Pen replay button
          if (!_analyzing && _penEngine.strokes.isNotEmpty && !_penReplaying)
            _ControlBtn(
              icon: Icons.draw_rounded,
              onTap: () {
                _penEngine.clear();
                if (_report != null) {
                  final visible = _report!.annotations
                      .where((a) => a.revealStep < _revealStep)
                      .toList();
                  _generatePenStrokes(visible);
                }
              },
              tooltip: 'İşaretleri tekrar göster',
            ),
        ],
      ),
    );
  }

  bool _allStepsRevealed(WorkAnalysisReport? report) {
    if (report == null || report.annotations.isEmpty) return false;
    final maxStep = report.annotations.map((a) => a.revealStep).fold(0, math.max);
    return _revealStep > maxStep;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// ignore: avoid_classes_with_only_static_members
class math {
  static int max(int a, int b) => a > b ? a : b;
}

// ── _ModePill ─────────────────────────────────────────────────────────────────

class _ModePill extends StatelessWidget {
  final VisualTeachingMode current;
  final ValueChanged<VisualTeachingMode> onSelected;

  const _ModePill({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: current.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: current.color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: TextStyle(
                  color: current.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: current.color, size: 13),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<VisualTeachingMode>(
      context: context,
      backgroundColor: const Color(0xFF0C0C18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Öğretim Modu',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VisualTeachingMode.values.map((m) {
                final sel = m == current;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(m);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? m.color.withValues(alpha: 0.14)
                          : const Color(0xFF111122),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? m.color.withValues(alpha: 0.40)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    child: Text(
                      m.label,
                      style: TextStyle(
                        color: sel ? m.color : const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ExplanationPanel ─────────────────────────────────────────────────────────

class _ExplanationPanel extends StatelessWidget {
  final String label;
  final String text;
  final String teacherName;

  const _ExplanationPanel({
    required this.label,
    required this.text,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: const Color(0xFFF87171).withValues(alpha: 0.25)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💬 ', style: TextStyle(fontSize: 11)),
              Expanded(
                child: Text(
                  '"$text"',
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '— $teacherName',
            style: const TextStyle(
                color: Color(0xFF4B5563), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── _EquationStepsPanel ───────────────────────────────────────────────────────

class _EquationStepsPanel extends StatelessWidget {
  final List<EquationStep> steps;
  final int revealCount;

  const _EquationStepsPanel({required this.steps, required this.revealCount});

  @override
  Widget build(BuildContext context) {
    final visible = steps.take(revealCount).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF060618),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A1A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adımlar',
              style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          ...visible.asMap().entries.map((e) {
            final step = e.value;
            final isLast = e.key == visible.length - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      step.isError
                          ? Icons.cancel_rounded
                          : Icons.check_circle_rounded,
                      color: step.isError
                          ? const Color(0xFFF87171)
                          : const Color(0xFF4ADE80),
                      size: 12,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.displayText,
                          style: TextStyle(
                            color: step.isError
                                ? const Color(0xFFF87171)
                                : isLast
                                    ? Colors.white
                                    : const Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: isLast
                                ? FontWeight.w600
                                : FontWeight.w400,
                            decoration: step.isError
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (step.explanation.isNotEmpty && isLast)
                          Text(
                            step.explanation,
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── _FeedbackPanel ────────────────────────────────────────────────────────────

class _FeedbackPanel extends StatelessWidget {
  final String feedback;
  final double score;
  final String teacherName;

  const _FeedbackPanel({
    required this.feedback,
    required this.score,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.7
        ? const Color(0xFF4ADE80)
        : score >= 0.4
            ? const Color(0xFFFBBF24)
            : const Color(0xFFF87171);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.40), width: 2),
            ),
            child: Center(
              child: Text(
                '${(score * 100).round()}',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherName,
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  feedback,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ErrorCountChip ───────────────────────────────────────────────────────────

class _ErrorCountChip extends StatelessWidget {
  final int count;
  const _ErrorCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFF87171), size: 10),
          const SizedBox(width: 4),
          Text(
            '$count hata',
            style: const TextStyle(
                color: Color(0xFFF87171),
                fontSize: 9,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── _SubjectChip ──────────────────────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  final String subject;
  final String topic;
  const _SubjectChip({required this.subject, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        topic.isNotEmpty ? topic : subject,
        style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 9,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── _ControlBtn ───────────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final String? label;
  final Color color;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.label,
    this.color = const Color(0xFF7C6BF8),
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: label != null ? 12 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(label!,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
