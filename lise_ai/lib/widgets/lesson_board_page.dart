import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/lesson_timeline.dart';
import '../models/whiteboard_element.dart';
import '../services/chalk_sound.dart';
import '../services/teacher_voice_service.dart';

// ── Public helper function ─────────────────────────────────────────────────────

Future<void> pushLessonBoard(
  BuildContext context,
  LessonTimeline lesson, {
  Future<void> Function(Uint8List)? onCheckDrawing,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => LessonBoardPage(
      lesson: lesson,
      onCheckDrawing: onCheckDrawing,
    ),
  ));
}

// ── Draw mode & speed enums ───────────────────────────────────────────────────

enum _DrawMode { none, pen, eraser }

enum _TeachingSpeed { slow, normal, fast }

// ── Drawing notifier ──────────────────────────────────────────────────────────

class _DrawingNotifier extends ChangeNotifier {
  final List<List<Offset>> strokes = [];
  List<Offset> currentStroke = [];
  static const double _minDist = 2.0;
  static const double _eraseRadius = 22.0;

  bool get hasStrokes => strokes.isNotEmpty;

  void startStroke(Offset pt) {
    currentStroke = [pt];
    notifyListeners();
  }

  void extendStroke(Offset pt) {
    if (currentStroke.isNotEmpty &&
        (currentStroke.last - pt).distance < _minDist) return;
    currentStroke.add(pt);
    notifyListeners();
  }

  void commitStroke() {
    if (currentStroke.length >= 2) strokes.add(List.from(currentStroke));
    currentStroke = [];
    notifyListeners();
  }

  void cancelStroke() {
    currentStroke = [];
    notifyListeners();
  }

  void eraseAt(Offset pt) {
    bool changed = false;
    final next = <List<Offset>>[];
    for (final stroke in strokes) {
      final segs = _splitStroke(stroke, pt);
      if (segs.length != 1 || segs.first.length != stroke.length) {
        changed = true;
      }
      next.addAll(segs);
    }
    if (changed) {
      strokes
        ..clear()
        ..addAll(next);
      notifyListeners();
    }
  }

  List<List<Offset>> _splitStroke(List<Offset> stroke, Offset eraserPt) {
    final result = <List<Offset>>[];
    var seg = <Offset>[];
    for (final pt in stroke) {
      if ((pt - eraserPt).distance < _eraseRadius) {
        if (seg.length >= 2) result.add(List.from(seg));
        seg = [];
      } else {
        seg.add(pt);
      }
    }
    if (seg.length >= 2) result.add(List.from(seg));
    return result;
  }

  void clearStudent() {
    strokes.clear();
    currentStroke = [];
    notifyListeners();
  }
}

// ── Main full-screen page ─────────────────────────────────────────────────────

class LessonBoardPage extends StatefulWidget {
  final LessonTimeline lesson;
  final Future<void> Function(Uint8List)? onCheckDrawing;

  const LessonBoardPage({
    super.key,
    required this.lesson,
    this.onCheckDrawing,
  });

  @override
  State<LessonBoardPage> createState() => _LessonBoardPageState();
}

class _LessonBoardPageState extends State<LessonBoardPage>
    with TickerProviderStateMixin {
  // ── Page state ─────────────────────────────────────────────────────────────
  int _currentPage = 0; // index into lesson.steps
  double _pageTime = 0.0; // seconds elapsed this page
  double _textTime = 0.0; // seconds elapsed for text reveal
  bool _paused = false;
  Timer? _timer;

  // ── Speed settings ─────────────────────────────────────────────────────────
  // Slow mode used to be painfully slow (0.40). Calibrated to: slow=0.75,
  // normal=1.0, fast=1.25 — calm but not lethargic. Default starts at normal
  // so first-time users do not see crawling animation.
  _TeachingSpeed _speed = _TeachingSpeed.normal;
  double get _boardSpeed => switch (_speed) {
        _TeachingSpeed.slow => 0.75,
        _TeachingSpeed.normal => 1.0,
        _TeachingSpeed.fast => 1.25,
      };
  double get _textCps => switch (_speed) {
        _TeachingSpeed.slow => 9.0,
        _TeachingSpeed.normal => 12.0,
        _TeachingSpeed.fast => 15.0,
      };

  // ── Drawing state ──────────────────────────────────────────────────────────
  _DrawMode _drawMode = _DrawMode.none;
  final _drawNotifier = _DrawingNotifier();
  bool _pointerDown = false;
  bool _checking = false;
  final _repaintKey = GlobalKey();

  // ── Chalk sound ────────────────────────────────────────────────────────────
  final _chalkSound = ChalkSoundService();
  Set<int> _soundedElements = {};
  bool _muted = true;

  // ── Teacher voice ─────────────────────────────────────────────────────────
  TeacherVoiceService? _voice;
  late final List<String?> _voiceFiles; // cached audio paths per step
  bool _voiceMuted = false;
  double _voiceSpeed = 1.0;             // 0.75, 1.0, 1.25
  bool _voiceGenerating = false;        // true while current step audio loads

  // ── Fade animation ─────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _transitioning = false;

  // ── Computed page properties ───────────────────────────────────────────────

  LessonStep get _currentStep =>
      widget.lesson.steps[_currentPage.clamp(0, widget.lesson.steps.length - 1)];

  List<WhiteboardElement> get _pageElements {
    final step = _currentStep;
    return step.elementIndices
        .where((idx) => idx < widget.lesson.elements.length)
        .map((idx) => widget.lesson.elements[idx])
        .toList();
  }

  double get _pageStartDelay {
    final els = _pageElements;
    if (els.isEmpty) return 0.0;
    return els.map((e) => e.delay).reduce((a, b) => a < b ? a : b);
  }

  double get _pageMaxEnd {
    final els = _pageElements;
    if (els.isEmpty) return 0.0;
    return els.map((e) => e.delay).reduce((a, b) => a > b ? a : b) + 2.5;
  }

  double get _pageDuration => (_pageMaxEnd - _pageStartDelay) + _currentStep.pauseAfter;

  /// Absolute time to pass to the painter (page-relative delay → absolute time).
  double get _absTime => _pageTime + _pageStartDelay;

  // ── Text reveal ────────────────────────────────────────────────────────────
  int get _revealedChars =>
      (_textTime * _textCps).floor().clamp(0, _currentStep.text.length);

  String get _displayedText =>
      _currentStep.text.substring(0, _revealedChars);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _chalkSound.init();
    _chalkSound.muted = _muted;

    // Initialise voice (async — detects local TTS availability)
    _voiceFiles = List.filled(widget.lesson.steps.length, null);
    TeacherVoiceService.create().then((svc) {
      if (!mounted) return;
      if (svc.isAvailable) {
        setState(() => _voice = svc);
        _pregenerateStep(0); // kick off pipeline
      }
    });

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voice?.dispose();
    _fadeCtrl.dispose();
    _drawNotifier.dispose();
    super.dispose();
  }

  // ── Timer tick ─────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), _tick);
  }

  void _tick(Timer t) {
    if (_paused || _transitioning) return;
    const dt = 0.05; // 50ms in seconds
    final newPageTime = _pageTime + dt * _boardSpeed;
    final newTextTime = _textTime + dt;

    // Chalk sound per element
    if (!_muted) {
      final els = _pageElements;
      for (int i = 0; i < els.length; i++) {
        final el = els[i];
        final globalIdx = _currentStep.elementIndices[i];
        if (_absTime + dt * _boardSpeed >= el.delay &&
            !_soundedElements.contains(globalIdx)) {
          _soundedElements.add(globalIdx);
          if (el.type != WBType.point) _chalkSound.playStroke();
        }
      }
    }

    // Page advance — timer drives it only when voice is not active for this step
    final ttsActive = _voice != null && !_voiceMuted && _voiceFiles[_currentPage] != null;
    if (!ttsActive && newPageTime >= _pageDuration) {
      _advancePage();
      return;
    }

    if (mounted) {
      setState(() {
        _pageTime = newPageTime;
        _textTime = newTextTime;
      });
    }
  }

  // ── TTS pipeline ───────────────────────────────────────────────────────────

  /// Pre-generate audio for step [index]. After completion, kick off [index+1].
  Future<void> _pregenerateStep(int index) async {
    if (_voice == null) return;
    if (index >= widget.lesson.steps.length) return;
    if (_voiceFiles[index] != null) {
      // Already cached — just play if it's the current step
      if (index == _currentPage && !_paused && !_voiceMuted) {
        _playStepAudio(index);
      }
      return;
    }

    if (index == _currentPage && mounted) {
      setState(() => _voiceGenerating = true);
    }

    final text = widget.lesson.steps[index].text;
    final path = await _voice!.generate(text, stepIndex: index);
    if (!mounted) return;

    _voiceFiles[index] = path;

    if (index == _currentPage) {
      setState(() => _voiceGenerating = false);
      // Play immediately if we're on this page and not paused
      if (!_paused && !_voiceMuted && path != null) {
        _playStepAudio(index);
      }
    }

    // Kick off next step in background
    if (index + 1 < widget.lesson.steps.length) {
      _pregenerateStep(index + 1);
    }
  }

  /// Play voice audio for [stepIndex]. When done, advance page.
  void _playStepAudio(int stepIndex) {
    final path = _voiceFiles[stepIndex];
    if (_voice == null || _voiceMuted || path == null) return;
    _voice!.play(path, onComplete: () {
      if (!mounted || _paused || _transitioning) return;
      if (_currentPage == stepIndex) _advancePage();
    });
  }

  /// Called when user pauses — suspend board timer AND voice.
  void _pauseAll() {
    setState(() => _paused = true);
    _voice?.pause();
  }

  /// Called when user resumes — restart board timer AND voice.
  void _resumeAll() {
    setState(() => _paused = false);
    // Resume audio if available; otherwise it will play next page start
    final path = _voiceFiles[_currentPage];
    if (_voice != null && !_voiceMuted && path != null) {
      _voice!.resume();
    }
  }

  Future<void> _advancePage() async {
    if (_transitioning) return;
    await _voice?.stop();
    final nextPage = _currentPage + 1;
    if (nextPage >= widget.lesson.steps.length) {
      if (mounted) setState(() => _paused = true);
      return;
    }

    _transitioning = true;
    await _fadeCtrl.reverse();
    if (!mounted) return;

    setState(() {
      _currentPage = nextPage;
      _pageTime = 0.0;
      _textTime = 0.0;
      _soundedElements = {};
      _drawNotifier.clearStudent();
      _voiceGenerating = false;
    });

    await _fadeCtrl.forward();
    _transitioning = false;

    // Start audio for new page
    _pregenerateStep(nextPage);
  }

  void _replay() {
    _voice?.stop();
    setState(() {
      _currentPage = 0;
      _pageTime = 0.0;
      _textTime = 0.0;
      _soundedElements = {};
      _paused = false;
      _transitioning = false;
      _voiceGenerating = false;
    });
    _fadeCtrl.value = 1.0;
    _startTimer();
    // Re-generate step 0 audio (clears cache to force fresh start)
    _voiceFiles[0] = null;
    _pregenerateStep(0);
  }

  // ── Drawing input ──────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (_drawMode == _DrawMode.none) return;
    _pointerDown = true;
    if (_drawMode == _DrawMode.pen) {
      _drawNotifier.startStroke(e.localPosition);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointerDown) return;
    if (_drawMode == _DrawMode.pen) {
      _drawNotifier.extendStroke(e.localPosition);
    } else if (_drawMode == _DrawMode.eraser) {
      _drawNotifier.eraseAt(e.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_pointerDown) return;
    _pointerDown = false;
    if (_drawMode == _DrawMode.pen) {
      _drawNotifier.commitStroke();
    } else {
      _drawNotifier.cancelStroke();
    }
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointerDown = false;
    _drawNotifier.cancelStroke();
  }

  Future<void> _captureAndCheck() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _checking = true);
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      await widget.onCheckDrawing?.call(byteData.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _setMode(_DrawMode mode) {
    setState(() {
      _drawMode = mode;
      if (mode == _DrawMode.none) {
        _pointerDown = false;
        _drawNotifier.cancelStroke();
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.lesson.steps.length;
    final step = _currentStep;
    final hasStrokes = _drawNotifier.hasStrokes;

    final cursor = switch (_drawMode) {
      _DrawMode.pen => SystemMouseCursors.precise,
      _DrawMode.eraser => SystemMouseCursors.cell,
      _DrawMode.none => MouseCursor.defer,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0B150B),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ───────────────────────────────────────────────────
            _buildHeader(step, totalSteps),

            // ── Board area (flex 6) ──────────────────────────────────────────
            Expanded(
              flex: 6,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: MouseRegion(
                    cursor: cursor,
                    child: Stack(
                      children: [
                        // AI board animation layer
                        AnimatedBuilder(
                          animation: const AlwaysStoppedAnimation(0),
                          builder: (_, __) => CustomPaint(
                            painter: _BoardPainter(
                              elements: _pageElements,
                              time: _absTime,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        // Repaint when pageTime changes by rebuilding this widget
                        _BoardAnimLayer(
                          elements: _pageElements,
                          absTime: _absTime,
                        ),
                        // Student drawing layer
                        CustomPaint(
                          painter: _StudentPainter(_drawNotifier),
                          child: const SizedBox.expand(),
                        ),
                        // Pointer capture
                        if (_drawMode != _DrawMode.none)
                          Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _onPointerDown,
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerCancel,
                            child: const SizedBox.expand(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Step progress strip ──────────────────────────────────────────
            _buildProgressStrip(totalSteps),

            // ── Teacher text strip ───────────────────────────────────────────
            _buildTextStrip(),

            // ── Toolbar ──────────────────────────────────────────────────────
            _buildToolbar(hasStrokes),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LessonStep step, int totalSteps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1A0D),
        border: Border(bottom: BorderSide(color: Color(0xFF1A3A1A))),
      ),
      child: Row(
        children: [
          // Exit board button — high-contrast, clearly labeled so the user
          // never feels trapped inside the board.
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F3A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF7C6BF8).withValues(alpha: 0.55)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      color: Color(0xFFE5E7EB), size: 15),
                  SizedBox(width: 5),
                  Text('Tahtadan Çık',
                      style: TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              widget.lesson.title.isNotEmpty ? widget.lesson.title : 'Canlı Ders',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Step badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2A1A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.5)),
            ),
            child: Text(
              'Adım ${_currentPage + 1}/$totalSteps: ${step.stepTitle}',
              style: const TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // "Yerel Ses" badge when local TTS is available
          if (_voice != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1A2E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_voiceGenerating)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF60A5FA)),
                    )
                  else
                    Icon(
                      _voiceMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      color: const Color(0xFF60A5FA),
                      size: 12,
                    ),
                  const SizedBox(width: 4),
                  const Text(
                    'Yerel Ses',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Pause/play button
          GestureDetector(
            onTap: () => _paused ? _resumeAll() : _pauseAll(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: const Color(0xFF9B8BFB),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStrip(int totalSteps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFF0A1A0A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSteps, (i) {
              final isCurrent = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isCurrent ? 20 : 8,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF4ADE80)
                      : i < _currentPage
                          ? const Color(0xFF2A4A2A)
                          : const Color(0xFF1A2A1A),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          // Progress bar for current page
          LinearProgressIndicator(
            value: _pageDuration > 0
                ? (_pageTime / _pageDuration).clamp(0.0, 1.0)
                : 0.0,
            backgroundColor: const Color(0xFF1A2A1A),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
            minHeight: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTextStrip() {
    return Container(
      height: 110,
      width: double.infinity,
      color: const Color(0xFF080F08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        child: Text(
          _displayedText,
          style: const TextStyle(
            color: Color(0xFFD1FAE5),
            fontSize: 14,
            height: 1.55,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(bool hasStrokes) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF08081A),
        border: Border(top: BorderSide(color: Color(0xFF1A1A3A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _TBtn(
                  icon: _drawMode == _DrawMode.pen
                      ? Icons.edit_rounded
                      : Icons.edit_outlined,
                  label: _drawMode == _DrawMode.pen ? 'Kalem Açık' : 'Kalem',
                  active: _drawMode == _DrawMode.pen,
                  activeColor: const Color(0xFF4ADE80),
                  onTap: () => _setMode(
                      _drawMode == _DrawMode.pen
                          ? _DrawMode.none
                          : _DrawMode.pen),
                ),
                const SizedBox(width: 6),
                _TBtn(
                  icon: Icons.auto_fix_normal_rounded,
                  label: 'Silgi',
                  active: _drawMode == _DrawMode.eraser,
                  activeColor: const Color(0xFFFB923C),
                  onTap: () => _setMode(
                      _drawMode == _DrawMode.eraser
                          ? _DrawMode.none
                          : _DrawMode.eraser),
                ),
                const SizedBox(width: 6),
                _TBtn(
                  icon: _muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: _muted ? 'Ses Kapalı' : 'Ses Açık',
                  active: !_muted,
                  activeColor: const Color(0xFF60A5FA),
                  onTap: () {
                    setState(() {
                      _muted = !_muted;
                      _chalkSound.muted = _muted;
                    });
                  },
                ),
                if (_voice != null) ...[
                  const SizedBox(width: 6),
                  _TBtn(
                    icon: _voiceMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: _voiceMuted ? 'Ses Yok' : 'Sesli',
                    active: !_voiceMuted,
                    activeColor: const Color(0xFF60A5FA),
                    onTap: () {
                      setState(() => _voiceMuted = !_voiceMuted);
                      if (_voiceMuted) {
                        _voice?.stop();
                      } else {
                        // Re-play current step if audio ready
                        final path = _voiceFiles[_currentPage];
                        if (path != null && !_paused) _playStepAudio(_currentPage);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _SpeedChip(
                    label: '0.75×',
                    selected: _voiceSpeed == 0.75,
                    onTap: () {
                      setState(() => _voiceSpeed = 0.75);
                      _voice?.setPlaybackRate(0.75);
                    },
                  ),
                  const SizedBox(width: 3),
                  _SpeedChip(
                    label: '1.0×',
                    selected: _voiceSpeed == 1.0,
                    onTap: () {
                      setState(() => _voiceSpeed = 1.0);
                      _voice?.setPlaybackRate(1.0);
                    },
                  ),
                  const SizedBox(width: 3),
                  _SpeedChip(
                    label: '1.25×',
                    selected: _voiceSpeed == 1.25,
                    onTap: () {
                      setState(() => _voiceSpeed = 1.25);
                      _voice?.setPlaybackRate(1.25);
                    },
                  ),
                ],
                const Spacer(),
                _SpeedChip(
                  label: 'Yavaş',
                  selected: _speed == _TeachingSpeed.slow,
                  onTap: () => setState(() => _speed = _TeachingSpeed.slow),
                ),
                const SizedBox(width: 3),
                _SpeedChip(
                  label: 'Normal',
                  selected: _speed == _TeachingSpeed.normal,
                  onTap: () => setState(() => _speed = _TeachingSpeed.normal),
                ),
                const SizedBox(width: 3),
                _SpeedChip(
                  label: 'Hızlı',
                  selected: _speed == _TeachingSpeed.fast,
                  onTap: () => setState(() => _speed = _TeachingSpeed.fast),
                ),
                const SizedBox(width: 6),
                _TBtn(
                  icon: Icons.replay_rounded,
                  label: 'Tekrar',
                  active: false,
                  activeColor: const Color(0xFF9B8BFB),
                  onTap: _replay,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF12122A)),
          // Row 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _TBtn(
                  icon: Icons.person_remove_outlined,
                  label: 'Öğrenci Sil',
                  active: false,
                  activeColor: const Color(0xFFF87171),
                  dimmed: !hasStrokes,
                  onTap: hasStrokes
                      ? () {
                          _drawNotifier.clearStudent();
                          setState(() {});
                        }
                      : null,
                ),
                const SizedBox(width: 6),
                _TBtn(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Tahtayı Sil',
                  active: false,
                  activeColor: const Color(0xFFF87171),
                  onTap: () {
                    _drawNotifier.clearStudent();
                    setState(() {
                      _pageTime = 0.0;
                      _textTime = 0.0;
                      _soundedElements = {};
                    });
                  },
                ),
                const Spacer(),
                if (hasStrokes && widget.onCheckDrawing != null)
                  _CheckBtn(
                    checking: _checking,
                    onTap: _checking ? null : _captureAndCheck,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Board animation layer (repainted by setState) ─────────────────────────────

class _BoardAnimLayer extends StatelessWidget {
  final List<WhiteboardElement> elements;
  final double absTime;

  const _BoardAnimLayer({required this.elements, required this.absTime});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BoardPainter(elements: elements, time: absTime),
      child: const SizedBox.expand(),
    );
  }
}

// ── Board painter (full chalk drawing logic) ──────────────────────────────────

class _BoardPainter extends CustomPainter {
  final List<WhiteboardElement> elements;
  final double time;

  static const _purple = Color(0xFF9B8BFB);
  static const _bg = Color(0xFF0E1A0E);
  static const _chalkWhite = Color(0xFFDDD8C4);

  const _BoardPainter({required this.elements, required this.time});

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.time != time || old.elements != elements;

  static double _dur(WBType t) => switch (t) {
        WBType.point => 0.30,
        WBType.step => 0.40,
        WBType.text => 0.65,
        WBType.formula => 0.90,
        WBType.line => 0.85,
        WBType.arrow => 1.10,
        WBType.vector => 1.10,
        WBType.circle => 1.30,
        WBType.rect => 1.30,
        WBType.triangle => 1.60,
        WBType.axes => 2.00,
        WBType.curve => 1.40,
        WBType.parabola => 2.20,
        WBType.sine => 2.50,
      };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    _paintDotGrid(canvas, size);
    _paintMathGrid(canvas, size);

    for (int i = 0; i < elements.length; i++) {
      final el = elements[i];
      if (time < el.delay) continue;
      final rawP = ((time - el.delay) / _dur(el.type)).clamp(0.0, 1.0);
      final p = Curves.easeInOut.transform(rawP);
      _dispatch(canvas, size, el, p, seed: i * 7919);
    }
  }

  void _paintDotGrid(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF0F200F)
      ..strokeWidth = 1.0;
    const sp = 32.0;
    for (double x = 0; x < size.width; x += sp) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final dot = Paint()..color = const Color(0xFF143A14);
    for (double x = sp; x < size.width; x += sp) {
      for (double y = sp; y < size.height; y += sp) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }
  }

  void _paintMathGrid(Canvas canvas, Size size) {
    WhiteboardElement? ax;
    double axP = 0;
    for (final el in elements) {
      if (el.type == WBType.axes && time >= el.delay) {
        axP = ((time - el.delay) / _dur(WBType.axes)).clamp(0.0, 1.0);
        ax = el;
        break;
      }
    }
    if (ax == null || ax.x == null || ax.w == null) return;
    final alpha = ((axP - 0.1) / 0.5).clamp(0.0, 1.0);
    if (alpha <= 0) return;

    final ox = ax.x! * size.width;
    final oy = ax.y! * size.height;
    final w = ax.w! * size.width;
    final h = ax.h! * size.height;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E1E52).withValues(alpha: alpha)
      ..strokeWidth = 0.6;
    const dX = 8, dY = 6;
    for (int i = 1; i < dX; i++) {
      canvas.drawLine(Offset(ox + w * i / dX, oy - h),
          Offset(ox + w * i / dX, oy), gridPaint);
    }
    for (int j = 1; j < dY; j++) {
      canvas.drawLine(
          Offset(ox, oy - h * j / dY), Offset(ox + w, oy - h * j / dY), gridPaint);
    }
  }

  void _dispatch(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    switch (el.type) {
      case WBType.text:
        _drawText(canvas, size, el, p);
      case WBType.formula:
        _drawFormula(canvas, size, el, p);
      case WBType.step:
        _drawStep(canvas, size, el, p);
      case WBType.point:
        _drawPoint(canvas, size, el, p);
      case WBType.line:
        _drawLine(canvas, size, el, p, seed: seed);
      case WBType.arrow:
        _drawArrow(canvas, size, el, p, seed: seed, thick: false);
      case WBType.vector:
        _drawArrow(canvas, size, el, p, seed: seed, thick: true);
      case WBType.circle:
        _drawCircle(canvas, size, el, p);
      case WBType.rect:
        _drawRect(canvas, size, el, p, seed: seed);
      case WBType.axes:
        _drawAxes(canvas, size, el, p);
      case WBType.curve:
        _drawCurve(canvas, size, el, p, seed: seed);
      case WBType.parabola:
        _drawParabola(canvas, size, el, p, seed: seed);
      case WBType.sine:
        _drawSine(canvas, size, el, p, seed: seed);
      case WBType.triangle:
        _drawTriangle(canvas, size, el, p, seed: seed);
    }
  }

  // ── Core path utilities ────────────────────────────────────────────────────

  Path _jitter(Path ideal, int seed, double intensity) {
    if (intensity <= 0) return ideal;
    final rng = math.Random(seed);
    final out = Path();
    bool first = true;

    for (final m in ideal.computeMetrics()) {
      if (m.length < 1) continue;
      final n = (m.length / 7).ceil().clamp(2, 600);
      for (int i = 0; i <= n; i++) {
        final t = (i / n * m.length).clamp(0.0, m.length);
        final tan = m.getTangentForOffset(t);
        if (tan == null) continue;

        final edgeT = i / n;
        final edgeFade = math.sin(edgeT * math.pi);

        final jx = (rng.nextDouble() - 0.5) * intensity * edgeFade;
        final jy = (rng.nextDouble() - 0.5) * intensity * edgeFade;
        final pos = tan.position;

        if (first) {
          out.moveTo(pos.dx + jx, pos.dy + jy);
          first = false;
        } else {
          out.lineTo(pos.dx + jx, pos.dy + jy);
        }
      }
    }
    return first ? ideal : out;
  }

  void _drawPartial(Canvas canvas, Path path, double p, Paint paint) {
    if (p <= 0) return;
    for (final m in path.computeMetrics()) {
      if (m.length < 1) continue;
      canvas.drawPath(m.extractPath(0, m.length * p.clamp(0.0, 1.0)), paint);
    }
  }

  Offset? _tipOffset(Path path, double p) {
    for (final m in path.computeMetrics()) {
      if (m.length < 1) continue;
      return m.getTangentForOffset(m.length * p.clamp(0.0, 1.0))?.position;
    }
    return null;
  }

  void _chalkStroke(Canvas canvas, Path path, double p, Color color, double sw) {
    if (p <= 0) return;

    // 1. Wide chalk dust atmosphere
    _drawPartial(
        canvas,
        path,
        p,
        Paint()
          ..color = color.withValues(alpha: 0.055)
          ..strokeWidth = sw * 4.8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // 2. Three chalk fiber passes
    final base = color.toARGB32() ^ (sw * 1000).toInt();
    _drawChalkFibers(
        canvas, path, p, color.withValues(alpha: 0.72), sw * 0.85, base + 1111);
    _drawChalkFibers(
        canvas, path, p, color.withValues(alpha: 0.42), sw * 0.65, base + 2222);
    _drawChalkFibers(
        canvas, path, p, color.withValues(alpha: 0.22), sw * 1.15, base + 3333);

    // 3. Active writing tip
    _drawChalkTip(canvas, path, p, color);
  }

  void _drawChalkFibers(
      Canvas canvas, Path path, double p, Color color, double sw, int seed) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    for (final m in path.computeMetrics()) {
      if (m.length < 0.5) continue;
      final len = m.length * p.clamp(0.0, 1.0);
      double pos = 0;
      int cap = 250;
      while (pos < len && cap-- > 0) {
        final segLen = 3.0 + rng.nextDouble() * 10.0;
        final gap = 0.3 + rng.nextDouble() * 3.2;
        final end = math.min(pos + segLen, len);
        if (end > pos + 0.3) {
          paint.strokeWidth = sw * (0.65 + rng.nextDouble() * 0.70);
          canvas.drawPath(m.extractPath(pos, end), paint);
        }
        pos = end + gap;
      }
    }
  }

  void _drawChalkTip(Canvas canvas, Path path, double p, Color color) {
    if (p >= 1.0 || p <= 0.01) return;
    final pos = _tipOffset(path, p);
    if (pos == null) return;

    canvas.drawCircle(
        pos,
        16,
        Paint()
          ..color = color.withValues(alpha: 0.09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        pos,
        7,
        Paint()
          ..color = color.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(pos, 1.8, Paint()..color = color.withValues(alpha: 0.82));
  }

  static Path _bezierThrough(List<Offset> pts) {
    assert(pts.length >= 2);
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      if (i < pts.length - 1) {
        final mid = Offset(
            (pts[i].dx + pts[i + 1].dx) / 2,
            (pts[i].dy + pts[i + 1].dy) / 2);
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    return path;
  }

  void _arrowhead(Canvas canvas, Offset from, Offset to, Color color,
      {double sz = 10}) {
    if ((to - from).distance < 1) return;
    final angle = (to - from).direction;
    const spread = 0.44;
    final p1 = to +
        Offset(sz * math.cos(angle + math.pi - spread),
            sz * math.sin(angle + math.pi - spread));
    final p2 = to +
        Offset(sz * math.cos(angle + math.pi + spread),
            sz * math.sin(angle + math.pi + spread));
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  TextPainter _tp(String text, Color color, double fs,
      {bool bold = false, double maxW = double.infinity}) {
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fs,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              height: 1.35,
              letterSpacing: 0.2)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW);
  }

  // ── Element draw methods ────────────────────────────────────────────────────

  void _drawText(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.content == null || el.x == null || el.y == null) return;
    final painter = _tp(el.content!, _chalkWhite.withValues(alpha: p),
        el.fontSize,
        maxW: size.width * 0.88);
    final pos = Offset(el.x! * size.width, el.y! * size.height);
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, pos.dx + painter.width * p + 5, size.height));
    painter.paint(canvas, pos);
    canvas.restore();
  }

  void _drawFormula(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.content == null || el.x == null || el.y == null) return;
    const fc = Color(0xFFEDE0FF);
    final fs = (el.fontSize * 1.15).clamp(16.0, 30.0);
    final painter = _tp(el.content!, fc.withValues(alpha: p), fs,
        bold: true, maxW: size.width * 0.88);
    final pos = Offset(el.x! * size.width, el.y! * size.height);

    const pH = 12.0, pV = 7.0;
    final box = Rect.fromLTWH(
        pos.dx - pH, pos.dy - pV, painter.width + pH * 2, painter.height + pV * 2);

    canvas.drawRRect(
        RRect.fromRectXY(box.inflate(5), 13, 13),
        Paint()
          ..color = _purple.withValues(alpha: p * 0.13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawRRect(RRect.fromRectXY(box, 9, 9),
        Paint()..color = const Color(0xFF0E0825).withValues(alpha: p));
    canvas.drawRRect(
        RRect.fromRectXY(box, 9, 9),
        Paint()
          ..color = _purple.withValues(alpha: p * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, pos.dx + painter.width * p + 5, size.height));
    painter.paint(canvas, pos);
    canvas.restore();
  }

  void _drawStep(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.y == null) return;
    const r = 12.0;
    final c = Offset(el.x! * size.width + r, el.y! * size.height + r);

    canvas.drawCircle(
        c,
        r * p * 1.9,
        Paint()
          ..color = _purple.withValues(alpha: p * 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawCircle(
        c, r * p, Paint()..color = _purple.withValues(alpha: p));

    if (p > 0.5 && el.content != null) {
      final op = ((p - 0.5) * 2).clamp(0.0, 1.0);
      final t = _tp(el.content!, Colors.white.withValues(alpha: op), 11,
          bold: true);
      t.paint(canvas, c - Offset(t.width / 2, t.height / 2));
    }
    if (p > 0.7 && el.label != null) {
      final op = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
      final t = _tp(el.label!, Colors.white.withValues(alpha: op), 13);
      t.paint(canvas, Offset(c.dx + r + 7, c.dy - t.height / 2));
    }
  }

  void _drawPoint(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null) return;
    final c = Offset(el.x! * size.width, el.y! * size.height);

    final scale = p < 0.65
        ? Curves.elasticOut.transform(p / 0.65) * 1.0
        : 1.0;
    final r = (5.0 * scale).clamp(0.0, 8.0);

    canvas.drawCircle(
        c,
        r * 2.8,
        Paint()
          ..color = el.color.withValues(alpha: p * 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(c, r, Paint()..color = el.color.withValues(alpha: p));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = el.color.withValues(alpha: p * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    if (p > 0.6 && el.label != null) {
      final op = ((p - 0.6) / 0.4).clamp(0.0, 1.0);
      final t = _tp(el.label!, el.color.withValues(alpha: op), 11);
      t.paint(canvas, c + const Offset(8, -14));
    }
  }

  void _drawLine(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    if (el.x1 == null) return;
    final s = Offset(el.x1! * size.width, el.y1! * size.height);
    final e = Offset(el.x2! * size.width, el.y2! * size.height);
    final ideal = Path()
      ..moveTo(s.dx, s.dy)
      ..lineTo(e.dx, e.dy);
    _chalkStroke(canvas, _jitter(ideal, seed, 1.2), p, el.color, 1.8);
  }

  void _drawArrow(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed, required bool thick}) {
    if (el.x1 == null) return;
    final s = Offset(el.x1! * size.width, el.y1! * size.height);
    final e = Offset(el.x2! * size.width, el.y2! * size.height);
    final sw = thick ? 3.0 : 2.0;

    final shaftP = (p / 0.88).clamp(0.0, 1.0);
    final ideal = Path()
      ..moveTo(s.dx, s.dy)
      ..lineTo(e.dx, e.dy);
    _chalkStroke(
        canvas, _jitter(ideal, seed, thick ? 1.5 : 1.0), shaftP, el.color, sw);

    if (p > 0.82) {
      final ap = ((p - 0.82) / 0.18).clamp(0.0, 1.0);
      _arrowhead(canvas, s, e, el.color.withValues(alpha: ap),
          sz: (thick ? 13.0 : 10.0) * ap);
    }

    if (p > 0.88 && el.label != null) {
      final op = ((p - 0.88) / 0.12).clamp(0.0, 1.0);
      if (thick) {
        final mid = Offset.lerp(s, e, 0.5)!;
        final angle = (e - s).direction;
        final perp = Offset(-math.sin(angle) * 18, math.cos(angle) * 18);
        final t = _tp(el.label!, el.color.withValues(alpha: op), 13, bold: true);
        t.paint(canvas, mid + perp - Offset(t.width / 2, t.height / 2));
      } else {
        final mid = Offset.lerp(s, e, 0.5)!;
        final t = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
        t.paint(canvas, mid + const Offset(4, -19));
      }
    }
  }

  void _drawCircle(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.cx == null || el.r == null) return;
    final c = Offset(el.cx! * size.width, el.cy! * size.height);
    final r = el.r! * math.min(size.width, size.height);

    final arcPath = Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi);

    _chalkStroke(canvas, arcPath, p, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final op = ((p - 0.92) / 0.08).clamp(0.0, 1.0);
      final t = _tp(el.label!, el.color.withValues(alpha: op), 12);
      t.paint(canvas, c + Offset(r + 7, -t.height / 2));
    }
  }

  void _drawRect(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    if (el.x == null || el.w == null) return;
    final rect = Rect.fromLTWH(el.x! * size.width, el.y! * size.height,
        el.w! * size.width, el.h! * size.height);
    final ideal = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    _chalkStroke(canvas, _jitter(ideal, seed, 0.9), p, el.color, 1.8);
  }

  void _drawAxes(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.w == null) return;
    final ox = el.x! * size.width;
    final oy = el.y! * size.height;
    final w = el.w! * size.width;
    final h = el.h! * size.height;
    final c = el.color;

    final xP = (p / 0.44).clamp(0.0, 1.0);
    final yP = ((p - 0.44) / 0.44).clamp(0.0, 1.0);
    final detailP = ((p - 0.88) / 0.12).clamp(0.0, 1.0);

    final xPath = Path()
      ..moveTo(ox, oy)
      ..lineTo(ox + w, oy);
    _chalkStroke(canvas, xPath, xP, c, 1.6);

    if (p > 0.44) {
      final yPath = Path()
        ..moveTo(ox, oy)
        ..lineTo(ox, oy - h);
      _chalkStroke(canvas, yPath, yP, c, 1.6);
    }

    if (xP >= 1.0) _arrowhead(canvas, Offset(ox, oy), Offset(ox + w, oy), c, sz: 7);
    if (yP >= 1.0) _arrowhead(canvas, Offset(ox, oy), Offset(ox, oy - h), c, sz: 7);

    if (detailP > 0) {
      final tickC = c.withValues(alpha: detailP * 0.75);
      final tp = Paint()
        ..color = tickC
        ..strokeWidth = 1.0;
      const ticks = 4;
      for (int i = 1; i <= ticks; i++) {
        final tx = ox + (w / ticks) * i;
        final ty = oy - (h / ticks) * i;
        canvas.drawLine(Offset(tx, oy - 3), Offset(tx, oy + 3), tp);
        canvas.drawLine(Offset(ox - 3, ty), Offset(ox + 3, ty), tp);
      }
      if (el.label != null) {
        final parts = el.label!.split(',');
        final lc = c.withValues(alpha: detailP * 0.9);
        if (parts.isNotEmpty) {
          _tp(parts[0].trim(), lc, 11)
              .paint(canvas, Offset(ox + w + 5, oy - 7));
        }
        if (parts.length >= 2) {
          _tp(parts[1].trim(), lc, 11)
              .paint(canvas, Offset(ox + 6, oy - h - 17));
        }
      }
    }
  }

  void _drawCurve(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    if (el.points == null || el.points!.length < 2) return;
    final pts = el.points!
        .map((pt) => Offset(pt[0] * size.width, pt[1] * size.height))
        .toList();
    final ideal = _bezierThrough(pts);
    _chalkStroke(canvas, _jitter(ideal, seed, 1.5), p, el.color, 2.2);

    if (p > 0.9 && el.label != null) {
      final op = ((p - 0.9) * 10).clamp(0.0, 1.0);
      final t = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
      t.paint(canvas, pts.last + const Offset(6, -18));
    }
  }

  void _drawParabola(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    final cx = (el.cx ?? 0.5) * size.width;
    final cy = (el.cy ?? 0.5) * size.height;
    final x1 = (el.x1 ?? 0.05) * size.width;
    final x2 = (el.x2 ?? 0.95) * size.width;
    final aScale = (el.a ?? 2.0) * size.height;

    const n = 80;
    final pts = List<Offset>.generate(n + 1, (i) {
      final x = x1 + (x2 - x1) * i / n;
      final dx = (x - cx) / size.width;
      return Offset(x, cy + aScale * dx * dx);
    });

    final ideal = _bezierThrough(pts);
    _chalkStroke(canvas, _jitter(ideal, seed, 1.2), p, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final op = ((p - 0.92) * 12.5).clamp(0.0, 1.0);
      final tip = pts.last;
      final t = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
      t.paint(canvas, tip + const Offset(6, -12));
    }
  }

  void _drawSine(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    final x1 = (el.x1 ?? 0.05) * size.width;
    final x2 = (el.x2 ?? 0.95) * size.width;
    final cy = (el.y ?? 0.5) * size.height;
    final amp = (el.amplitude ?? 0.15) * size.height;
    final freq = el.frequency ?? 2.0;
    final ph = el.phase ?? 0.0;

    const n = 150;
    final pts = List<Offset>.generate(n + 1, (i) {
      final x = x1 + (x2 - x1) * i / n;
      final t = (x - x1) / (x2 - x1);
      return Offset(x, cy - amp * math.sin(t * freq * 2 * math.pi + ph));
    });

    final ideal = _bezierThrough(pts);
    _chalkStroke(canvas, _jitter(ideal, seed, 0.9), p, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final op = ((p - 0.92) * 12.5).clamp(0.0, 1.0);
      final endT = p;
      final endX = x1 + (x2 - x1) * endT;
      final endY = cy - amp * math.sin(endT * freq * 2 * math.pi + ph);
      final t = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
      t.paint(canvas, Offset(endX + 5, endY - 14));
    }
  }

  void _drawTriangle(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    if (el.points == null || el.points!.length < 3) return;
    final v = el.points!
        .map((pt) => Offset(pt[0] * size.width, pt[1] * size.height))
        .toList();

    final ideal = Path()
      ..moveTo(v[0].dx, v[0].dy)
      ..lineTo(v[1].dx, v[1].dy)
      ..lineTo(v[2].dx, v[2].dy)
      ..close();

    _chalkStroke(canvas, _jitter(ideal, seed, 1.5), p, el.color, 2.0);

    if (p > 0.95) {
      final fillP = ((p - 0.95) / 0.05).clamp(0.0, 1.0);
      final fillPath = Path()
        ..moveTo(v[0].dx, v[0].dy)
        ..lineTo(v[1].dx, v[1].dy)
        ..lineTo(v[2].dx, v[2].dy)
        ..close();
      canvas.drawPath(
          fillPath,
          Paint()
            ..color = el.color.withValues(alpha: fillP * 0.07)
            ..style = PaintingStyle.fill);
    }

    if (p > 0.88 && el.label != null) {
      final labels = el.label!.split(',');
      const offs = [Offset(-10, -22), Offset(10, 4), Offset(-12, 4)];
      for (int i = 0; i < math.min(labels.length, 3); i++) {
        final op = ((p - 0.88) / 0.12).clamp(0.0, 1.0);
        final t = _tp(labels[i].trim(), el.color.withValues(alpha: op), 12,
            bold: true);
        t.paint(canvas, v[i] + offs[i]);
      }
    }
  }
}

// ── Student drawing painter ───────────────────────────────────────────────────

class _StudentPainter extends CustomPainter {
  final _DrawingNotifier notifier;
  static const _inkColor = Color(0xFFFBBF24);

  _StudentPainter(this.notifier) : super(repaint: notifier);

  @override
  bool shouldRepaint(_StudentPainter old) => false;

  @override
  void paint(Canvas canvas, Size size) {
    if (notifier.strokes.isEmpty && notifier.currentStroke.isEmpty) return;

    final glow = Paint()
      ..color = _inkColor.withValues(alpha: 0.14)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final ink = Paint()
      ..color = _inkColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in notifier.strokes) {
      _drawStroke(canvas, stroke, glow, ink);
    }
    if (notifier.currentStroke.isNotEmpty) {
      _drawStroke(canvas, notifier.currentStroke, glow, ink);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Paint glow, Paint ink) {
    final path = _buildPath(pts);
    if (path == null) return;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, ink);
  }

  Path? _buildPath(List<Offset> pts) {
    if (pts.length < 2) return null;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      if (i < pts.length - 1) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    return path;
  }
}

// ── Toolbar widget helpers ────────────────────────────────────────────────────

class _TBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final bool dimmed;
  final VoidCallback? onTap;

  const _TBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    this.dimmed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = active
        ? activeColor
        : dimmed
            ? const Color(0xFF3A3A5A)
            : const Color(0xFF9B8BFB);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF12122A),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.65)
                : dimmed
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFF252540),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 13),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CheckBtn extends StatelessWidget {
  final bool checking;
  final VoidCallback? onTap;
  const _CheckBtn({required this.checking, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: checking
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF3D2E8A), Color(0xFF7C6BF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: checking ? const Color(0xFF12122A) : null,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: checking ? const Color(0xFF252540) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (checking)
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Color(0xFF9B8BFB)),
              )
            else
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(
              checking ? 'Kontrol ediliyor…' : 'Çizimimi Kontrol Et',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4ADE80).withValues(alpha: 0.22)
              : const Color(0xFF12241A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected
                ? const Color(0xFF4ADE80).withValues(alpha: 0.8)
                : const Color(0xFF2A4A2A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            // Unselected was 0xFF3A6A3A (dark green on dark green) — unreadable.
            // Lifted to a much higher-luminance neutral green for legibility.
            color: selected ? const Color(0xFF4ADE80) : const Color(0xFFB4D9B4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
