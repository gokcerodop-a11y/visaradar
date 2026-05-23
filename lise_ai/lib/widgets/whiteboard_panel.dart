import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/lesson_timeline.dart';
import '../models/whiteboard_element.dart';
import '../services/chalk_sound.dart';

// ── Public panel widget ───────────────────────────────────────────────────────

enum WhiteboardState { closed, loading, ready }

class WhiteboardPanel extends StatelessWidget {
  final WhiteboardState state;
  final WhiteboardData? data;
  final LessonTimeline? lesson;
  final VoidCallback onClose;
  final VoidCallback onReplay;
  final VoidCallback? onClearBoard;
  final Future<void> Function(Uint8List pngBytes)? onCheckDrawing;

  const WhiteboardPanel({
    super.key,
    required this.state,
    required this.data,
    this.lesson,
    required this.onClose,
    required this.onReplay,
    this.onClearBoard,
    this.onCheckDrawing,
  });

  // Empty whiteboard data for blank board state
  static const _empty = WhiteboardData(title: '', elements: []);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF060612),
        border: Border(left: BorderSide(color: Color(0xFF1A1A3A), width: 1)),
      ),
      child: Column(
        children: [
          _Header(
            title: data?.title.isNotEmpty == true ? data!.title : 'Tahta',
            onClose: onClose,
            state: state,
            lesson: lesson,
          ),
          Expanded(
            child: switch (state) {
              WhiteboardState.loading => const _LoadingView(),
              WhiteboardState.ready  => _WhiteboardCanvas(
                  data: data ?? _empty,
                  lesson: lesson,
                  onReplay: onReplay,
                  onClearBoard: onClearBoard,
                  onCheckDrawing: onCheckDrawing,
                ),
              WhiteboardState.closed => const SizedBox(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final WhiteboardState state;
  final LessonTimeline? lesson;

  const _Header({
    required this.title,
    required this.onClose,
    required this.state,
    this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B1E),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A3A))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3D2E8A), Color(0xFF7C6BF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_graph_rounded,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title.isNotEmpty ? title : 'Tahta',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lesson != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2A1A),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text('Canlı Ders',
                    style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF6B7280), size: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading view ───────────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              size: const Size(72, 72),
              painter: _SpinnerPainter(_ctrl.value),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Tahta hazırlanıyor…',
              style: TextStyle(
                  color: Color(0xFF9B8BFB),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Claude adımları çiziyor',
              style: TextStyle(color: Color(0xFF374151), fontSize: 11)),
        ],
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double t;
  _SpinnerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 28.0;
    canvas.drawCircle(c, r,
        Paint()
          ..color = const Color(0xFF1A1A3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      t * 2 * math.pi - math.pi / 2,
      math.pi * 1.3,
      false,
      Paint()
        ..color = const Color(0xFF7C6BF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, 9, Paint()..color = const Color(0xFF0B0B1E));
    final icon = TextPainter(
      text: const TextSpan(
          text: '✦',
          style: TextStyle(color: Color(0xFF7C6BF8), fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, c - Offset(icon.width / 2, icon.height / 2));
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.t != t;
}

// ── Draw mode ─────────────────────────────────────────────────────────────────

enum _DrawMode { none, pen, eraser }

// ── Drawing notifier (ChangeNotifier for zero-setState drawing repaints) ──────

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

  /// Point-proximity eraser: splits strokes at points within [_eraseRadius].
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

// ── Whiteboard canvas ──────────────────────────────────────────────────────────

class _WhiteboardCanvas extends StatefulWidget {
  final WhiteboardData data;
  final LessonTimeline? lesson;
  final VoidCallback? onReplay;
  final VoidCallback? onClearBoard;
  final Future<void> Function(Uint8List)? onCheckDrawing;

  const _WhiteboardCanvas({
    required this.data,
    this.lesson,
    this.onReplay,
    this.onClearBoard,
    this.onCheckDrawing,
  });

  @override
  State<_WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<_WhiteboardCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _time;

  _DrawMode _drawMode = _DrawMode.none;
  final _drawNotifier = _DrawingNotifier();
  bool _pointerDown = false;
  bool _checking = false;
  final _repaintKey = GlobalKey();

  final _chalkSound = ChalkSoundService();
  Set<int> _soundedElements = {};
  final _stepIndexNotifier = ValueNotifier<int>(0);
  bool _muted = false;

  bool get _penActive => _drawMode != _DrawMode.none;

  @override
  void initState() {
    super.initState();
    _chalkSound.init();
    _startAnimation();
  }

  void _startAnimation() {
    _soundedElements = {};
    _stepIndexNotifier.value = 0;
    final dur = widget.data.totalDuration;
    _ctrl = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: (dur * 1000).round().clamp(1000, 60000)),
    )..forward();
    _time = Tween<double>(begin: 0, end: dur)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(_WhiteboardCanvas old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _ctrl.dispose();
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _stepIndexNotifier.dispose();
    _drawNotifier.dispose();
    super.dispose();
  }

  void _checkLessonProgress() {
    final t = _time.value;

    // Sound: fire one chalk sound per element when it first starts drawing
    for (int i = 0; i < widget.data.elements.length; i++) {
      if (t >= widget.data.elements[i].delay && !_soundedElements.contains(i)) {
        _soundedElements.add(i);
        _chalkSound.playStroke();
      }
    }

    // Lesson step advancement
    if (widget.lesson != null) {
      int newStep = 0;
      for (int i = widget.lesson!.steps.length - 1; i >= 0; i--) {
        if (t >= widget.lesson!.stepStartTime(i)) {
          newStep = i;
          break;
        }
      }
      if (newStep != _stepIndexNotifier.value) {
        _stepIndexNotifier.value = newStep;
      }
    }
  }

  // ── Raw pointer events (no setState on move — notifier repaints only) ─────

  void _onPointerDown(PointerDownEvent e) {
    if (_drawMode == _DrawMode.none) return;
    debugPrint('[Draw] PointerDown mode=$_drawMode pos=${e.localPosition}');
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
    debugPrint(
        '[Draw] PointerUp pts=${_drawNotifier.currentStroke.length}');
    if (_drawMode == _DrawMode.pen) {
      _drawNotifier.commitStroke();
    } else {
      _drawNotifier.cancelStroke();
    }
    setState(() {}); // refresh toolbar hasStrokes state
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
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      await widget.onCheckDrawing?.call(byteData.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _setMode(_DrawMode mode) {
    debugPrint('[Draw] Mode → $mode');
    setState(() {
      _drawMode = mode;
      if (mode == _DrawMode.none) {
        _pointerDown = false;
        _drawNotifier.cancelStroke();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cursor = switch (_drawMode) {
      _DrawMode.pen    => SystemMouseCursors.precise,
      _DrawMode.eraser => SystemMouseCursors.cell,
      _DrawMode.none   => MouseCursor.defer,
    };

    return Column(
      children: [
        // ── Lesson step text (only in lesson mode) ──────────────────────────
        if (widget.lesson != null && widget.lesson!.steps.isNotEmpty)
          ValueListenableBuilder<int>(
            valueListenable: _stepIndexNotifier,
            builder: (_, idx, __) {
              final step = widget.lesson!.steps[idx.clamp(0, widget.lesson!.steps.length - 1)];
              return _StepTextPanel(text: step.text, stepIndex: idx);
            },
          ),
        // ── Canvas area ─────────────────────────────────────────────────────
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: MouseRegion(
              cursor: cursor,
              child: Stack(
                children: [
                  // ① AI animation layer
                  AnimatedBuilder(
                    animation: _time,
                    builder: (_, __) {
                      _checkLessonProgress();
                      return CustomPaint(
                        painter: _WhiteboardPainter(
                            elements: widget.data.elements,
                            time: _time.value),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                  // ② Student drawing layer — repaints via notifier only
                  CustomPaint(
                    painter: _StudentPainter(_drawNotifier),
                    child: const SizedBox.expand(),
                  ),
                  // ③ Raw pointer capture (pen/eraser modes)
                  if (_penActive)
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
        // ── Always-visible toolbar ──────────────────────────────────────────
        _buildToolbar(),
      ],
    );
  }

  Widget _buildToolbar() {
    final hasStrokes = _drawNotifier.hasStrokes;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Color(0xFF08081A),
        border: Border(top: BorderSide(color: Color(0xFF1A1A3A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 — drawing mode toggles
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _TBtn(
                  icon: _drawMode == _DrawMode.pen
                      ? Icons.edit_rounded
                      : Icons.edit_outlined,
                  label: _drawMode == _DrawMode.pen
                      ? 'Kalem Açık'
                      : 'Kalem Kapalı',
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
                  icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  label: _muted ? 'Ses Kapalı' : 'Ses Açık',
                  active: !_muted,
                  activeColor: const Color(0xFF60A5FA),
                  onTap: () {
                    setState(() {
                      _muted = !_muted;
                      _chalkSound.muted = _muted;
                    });
                    debugPrint('[Sound] Muted: $_muted');
                  },
                ),
                const Spacer(),
                _TBtn(
                  icon: Icons.replay_rounded,
                  label: 'Tekrar Oynat',
                  active: false,
                  activeColor: const Color(0xFF9B8BFB),
                  onTap: widget.onReplay,
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1, color: Color(0xFF12122A)),
          // Row 2 — board actions
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          debugPrint('[Draw] Clear student strokes');
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
                    debugPrint('[Draw] Clear board');
                    _drawNotifier.clearStudent();
                    widget.onClearBoard?.call();
                    setState(() {});
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

// ── Step text panel ────────────────────────────────────────────────────────────

class _StepTextPanel extends StatelessWidget {
  final String text;
  final int stepIndex;
  const _StepTextPanel({required this.text, required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(stepIndex),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D28),
          border: Border(bottom: BorderSide(color: Color(0xFF1E1E44))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3, right: 8),
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80), shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(text,
                style: const TextStyle(
                  color: Color(0xFFD4E0FF),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _WhiteboardPainter extends CustomPainter {
  final List<WhiteboardElement> elements;
  final double time;

  static const _purple = Color(0xFF9B8BFB);
  static const _bg     = Color(0xFF060612);

  const _WhiteboardPainter({required this.elements, required this.time});

  @override
  bool shouldRepaint(_WhiteboardPainter old) => old.time != time;

  // ── Per-element draw duration (seconds) ────────────────────────────────────

  static double _dur(WBType t) => switch (t) {
    WBType.point    => 0.30,
    WBType.step     => 0.40,
    WBType.text     => 0.65,
    WBType.formula  => 0.90,
    WBType.line     => 0.85,
    WBType.arrow    => 1.10,
    WBType.vector   => 1.10,
    WBType.circle   => 1.30,
    WBType.rect     => 1.30,
    WBType.triangle => 1.60,
    WBType.axes     => 2.00,
    WBType.curve    => 1.40,
    WBType.parabola => 2.20,
    WBType.sine     => 2.50,
  };

  // ── Top-level paint ────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    _paintDotGrid(canvas, size);
    _paintMathGrid(canvas, size);

    for (int i = 0; i < elements.length; i++) {
      final el = elements[i];
      if (time < el.delay) continue;
      final rawP = ((time - el.delay) / _dur(el.type)).clamp(0.0, 1.0);
      // Ease-in-out: starts slow, speeds up, ends slow — like a real hand.
      final p = Curves.easeInOut.transform(rawP);
      _dispatch(canvas, size, el, p, seed: i * 7919);
    }
  }

  // ── Background layers ──────────────────────────────────────────────────────

  void _paintDotGrid(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF0D0D24)
      ..strokeWidth = 1.0;
    const sp = 32.0;
    for (double x = 0; x < size.width; x += sp) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final dot = Paint()..color = const Color(0xFF12123A);
    for (double x = sp; x < size.width; x += sp) {
      for (double y = sp; y < size.height; y += sp) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }
  }

  /// Draws a math-style grid inside the first axes element that has appeared.
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
    final w  = ax.w! * size.width;
    final h  = ax.h! * size.height;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E1E52).withValues(alpha: alpha)
      ..strokeWidth = 0.6;
    const dX = 8, dY = 6;
    for (int i = 1; i < dX; i++) {
      canvas.drawLine(Offset(ox + w * i / dX, oy - h),
                      Offset(ox + w * i / dX, oy), gridPaint);
    }
    for (int j = 1; j < dY; j++) {
      canvas.drawLine(Offset(ox, oy - h * j / dY),
                      Offset(ox + w, oy - h * j / dY), gridPaint);
    }
  }

  // ── Dispatch ───────────────────────────────────────────────────────────────

  void _dispatch(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    switch (el.type) {
      case WBType.text:     _drawText(canvas, size, el, p);
      case WBType.formula:  _drawFormula(canvas, size, el, p);
      case WBType.step:     _drawStep(canvas, size, el, p);
      case WBType.point:    _drawPoint(canvas, size, el, p);
      case WBType.line:     _drawLine(canvas, size, el, p, seed: seed);
      case WBType.arrow:    _drawArrow(canvas, size, el, p, seed: seed, thick: false);
      case WBType.vector:   _drawArrow(canvas, size, el, p, seed: seed, thick: true);
      case WBType.circle:   _drawCircle(canvas, size, el, p);
      case WBType.rect:     _drawRect(canvas, size, el, p, seed: seed);
      case WBType.axes:     _drawAxes(canvas, size, el, p);
      case WBType.curve:    _drawCurve(canvas, size, el, p, seed: seed);
      case WBType.parabola: _drawParabola(canvas, size, el, p, seed: seed);
      case WBType.sine:     _drawSine(canvas, size, el, p, seed: seed);
      case WBType.triangle: _drawTriangle(canvas, size, el, p, seed: seed);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Core path utilities
  // ══════════════════════════════════════════════════════════════════════════

  /// Resample [ideal] into a jittered polyline using a seeded RNG.
  /// Intensity = max px deviation per sample point.
  /// Endpoints are kept clean (jitter fades to near-zero at start/end).
  Path _jitter(Path ideal, int seed, double intensity) {
    if (intensity <= 0) return ideal;
    final rng = math.Random(seed);
    final out = Path();
    bool first = true;

    for (final m in ideal.computeMetrics()) {
      if (m.length < 1) continue;
      // Sample every ~7 px along the path
      final n = (m.length / 7).ceil().clamp(2, 600);
      for (int i = 0; i <= n; i++) {
        final t   = (i / n * m.length).clamp(0.0, m.length);
        final tan = m.getTangentForOffset(t);
        if (tan == null) continue;

        // Edge fade: no jitter at the very start/end
        final edgeT   = i / n; // 0→1
        final edgeFade = math.sin(edgeT * math.pi); // 0→1→0

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

  /// Extract and draw only the first [p] fraction of [path] using PathMetrics.
  void _drawPartial(Canvas canvas, Path path, double p, Paint paint) {
    if (p <= 0) return;
    for (final m in path.computeMetrics()) {
      if (m.length < 1) continue;
      canvas.drawPath(m.extractPath(0, m.length * p.clamp(0.0, 1.0)), paint);
    }
  }

  /// Find the current draw-tip position in [path] at fraction [p].
  Offset? _tipOffset(Path path, double p) {
    for (final m in path.computeMetrics()) {
      if (m.length < 1) continue;
      return m.getTangentForOffset(m.length * p.clamp(0.0, 1.0))?.position;
    }
    return null;
  }

  /// Draw a glowing chalk/pen tip at the current draw position.
  void _drawTip(Canvas canvas, Path path, double p, Color color) {
    if (p >= 1.0 || p <= 0.01) return;
    final pos = _tipOffset(path, p);
    if (pos == null) return;

    // Outer soft glow
    canvas.drawCircle(pos, 11,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    // Medium ring
    canvas.drawCircle(pos, 5,
        Paint()
          ..color = color.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    // Bright center dot
    canvas.drawCircle(pos, 2.8,
        Paint()..color = color.withValues(alpha: 0.95));
  }

  /// Full chalk stroke: glow pass → crisp stroke pass → live tip.
  void _chalkStroke(Canvas canvas, Path path, double p, Color color, double sw) {
    if (p <= 0) return;
    // Soft glow behind stroke
    _drawPartial(
      canvas, path, p,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..strokeWidth = sw * 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Crisp stroke
    _drawPartial(
      canvas, path, p,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    // Tip glow
    _drawTip(canvas, path, p, color);
  }

  // ── Build smooth bezier path through a list of Offsets ────────────────────

  static Path _bezierThrough(List<Offset> pts) {
    assert(pts.length >= 2);
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      if (i < pts.length - 1) {
        // Use the current point as control point, midpoint as anchor.
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

  // ── Arrowhead helper ──────────────────────────────────────────────────────

  void _arrowhead(Canvas canvas, Offset from, Offset to, Color color,
      {double sz = 10}) {
    if ((to - from).distance < 1) return;
    final angle = (to - from).direction;
    const spread = 0.44;
    final p1 = to + Offset(sz * math.cos(angle + math.pi - spread),
        sz * math.sin(angle + math.pi - spread));
    final p2 = to + Offset(sz * math.cos(angle + math.pi + spread),
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

  // ══════════════════════════════════════════════════════════════════════════
  //  Element draw methods
  // ══════════════════════════════════════════════════════════════════════════

  // ── Text ──────────────────────────────────────────────────────────────────

  void _drawText(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.content == null || el.x == null || el.y == null) return;
    final painter = _tp(el.content!, Colors.white.withValues(alpha: p),
        el.fontSize, maxW: size.width * 0.88);
    final pos = Offset(el.x! * size.width, el.y! * size.height);
    // Chalk left-to-right reveal
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, pos.dx + painter.width * p + 5, size.height));
    painter.paint(canvas, pos);
    canvas.restore();
  }

  // ── Formula ───────────────────────────────────────────────────────────────

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

    // Glow halo
    canvas.drawRRect(RRect.fromRectXY(box.inflate(5), 13, 13),
        Paint()
          ..color = _purple.withValues(alpha: p * 0.13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    // Dark pill
    canvas.drawRRect(RRect.fromRectXY(box, 9, 9),
        Paint()..color = const Color(0xFF0E0825).withValues(alpha: p));
    // Purple border
    canvas.drawRRect(RRect.fromRectXY(box, 9, 9),
        Paint()
          ..color = _purple.withValues(alpha: p * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // Left-to-right chalk reveal
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, pos.dx + painter.width * p + 5, size.height));
    painter.paint(canvas, pos);
    canvas.restore();
  }

  // ── Step marker ───────────────────────────────────────────────────────────

  void _drawStep(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.y == null) return;
    const r = 12.0;
    final c = Offset(el.x! * size.width + r, el.y! * size.height + r);

    canvas.drawCircle(c, r * p * 1.9,
        Paint()
          ..color = _purple.withValues(alpha: p * 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawCircle(c, r * p, Paint()..color = _purple.withValues(alpha: p));

    if (p > 0.5 && el.content != null) {
      final op = ((p - 0.5) * 2).clamp(0.0, 1.0);
      final t = _tp(el.content!, Colors.white.withValues(alpha: op), 11, bold: true);
      t.paint(canvas, c - Offset(t.width / 2, t.height / 2));
    }
    if (p > 0.7 && el.label != null) {
      final op = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
      final t = _tp(el.label!, Colors.white.withValues(alpha: op), 13);
      t.paint(canvas, Offset(c.dx + r + 7, c.dy - t.height / 2));
    }
  }

  // ── Point ─────────────────────────────────────────────────────────────────

  void _drawPoint(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null) return;
    final c = Offset(el.x! * size.width, el.y! * size.height);

    // Elastic pop: overshoot slightly then settle
    final scale = p < 0.65
        ? Curves.elasticOut.transform(p / 0.65) * 1.0
        : 1.0;
    final r = (5.0 * scale).clamp(0.0, 8.0);

    // Bloom
    canvas.drawCircle(c, r * 2.8,
        Paint()
          ..color = el.color.withValues(alpha: p * 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Fill
    canvas.drawCircle(c, r, Paint()..color = el.color.withValues(alpha: p));
    // Ring
    canvas.drawCircle(c, r,
        Paint()
          ..color = el.color.withValues(alpha: p * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Label
    if (p > 0.6 && el.label != null) {
      final op = ((p - 0.6) / 0.4).clamp(0.0, 1.0);
      final t = _tp(el.label!, el.color.withValues(alpha: op), 11);
      t.paint(canvas, c + const Offset(8, -14));
    }
  }

  // ── Line ──────────────────────────────────────────────────────────────────

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

  // ── Arrow / Vector ────────────────────────────────────────────────────────

  void _drawArrow(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed, required bool thick}) {
    if (el.x1 == null) return;
    final s   = Offset(el.x1! * size.width, el.y1! * size.height);
    final e   = Offset(el.x2! * size.width, el.y2! * size.height);
    final sw  = thick ? 3.0 : 2.0;

    // 0→0.88: draw shaft; 0.88→1.0: arrowhead appears
    final shaftP = (p / 0.88).clamp(0.0, 1.0);
    final ideal  = Path()..moveTo(s.dx, s.dy)..lineTo(e.dx, e.dy);
    _chalkStroke(canvas, _jitter(ideal, seed, thick ? 1.5 : 1.0), shaftP, el.color, sw);

    if (p > 0.82) {
      final ap = ((p - 0.82) / 0.18).clamp(0.0, 1.0);
      _arrowhead(canvas, s, e, el.color.withValues(alpha: ap),
          sz: (thick ? 13.0 : 10.0) * ap);
    }

    if (p > 0.88 && el.label != null) {
      final op = ((p - 0.88) / 0.12).clamp(0.0, 1.0);
      if (thick) {
        final mid   = Offset.lerp(s, e, 0.5)!;
        final angle = (e - s).direction;
        final perp  = Offset(-math.sin(angle) * 18, math.cos(angle) * 18);
        final t = _tp(el.label!, el.color.withValues(alpha: op), 13, bold: true);
        t.paint(canvas, mid + perp - Offset(t.width / 2, t.height / 2));
      } else {
        final mid = Offset.lerp(s, e, 0.5)!;
        final t   = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
        t.paint(canvas, mid + const Offset(4, -19));
      }
    }
  }

  // ── Circle ────────────────────────────────────────────────────────────────

  void _drawCircle(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.cx == null || el.r == null) return;
    final c = Offset(el.cx! * size.width, el.cy! * size.height);
    final r = el.r! * math.min(size.width, size.height);

    final arcPath = Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
          2 * math.pi);

    _chalkStroke(canvas, arcPath, p, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final op = ((p - 0.92) / 0.08).clamp(0.0, 1.0);
      final t  = _tp(el.label!, el.color.withValues(alpha: op), 12);
      t.paint(canvas, c + Offset(r + 7, -t.height / 2));
    }
  }

  // ── Rect ──────────────────────────────────────────────────────────────────

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

  // ── Coordinate axes ───────────────────────────────────────────────────────

  void _drawAxes(Canvas canvas, Size size, WhiteboardElement el, double p) {
    if (el.x == null || el.w == null) return;
    final ox = el.x! * size.width;
    final oy = el.y! * size.height;
    final w  = el.w! * size.width;
    final h  = el.h! * size.height;
    final c  = el.color;

    // Phase 1 (0→0.44): X axis
    // Phase 2 (0.44→0.88): Y axis
    // Phase 3 (0.88→1.0): ticks + labels
    final xP      = (p / 0.44).clamp(0.0, 1.0);
    final yP      = ((p - 0.44) / 0.44).clamp(0.0, 1.0);
    final detailP = ((p - 0.88) / 0.12).clamp(0.0, 1.0);

    final xPath = Path()..moveTo(ox, oy)..lineTo(ox + w, oy);
    _chalkStroke(canvas, xPath, xP, c, 1.6);

    if (p > 0.44) {
      final yPath = Path()..moveTo(ox, oy)..lineTo(ox, oy - h);
      _chalkStroke(canvas, yPath, yP, c, 1.6);
    }

    if (xP >= 1.0) _arrowhead(canvas, Offset(ox, oy), Offset(ox + w, oy), c, sz: 7);
    if (yP >= 1.0) _arrowhead(canvas, Offset(ox, oy), Offset(ox, oy - h), c, sz: 7);

    if (detailP > 0) {
      final tickC = c.withValues(alpha: detailP * 0.75);
      final tp = Paint()..color = tickC..strokeWidth = 1.0;
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
          _tp(parts[0].trim(), lc, 11).paint(canvas, Offset(ox + w + 5, oy - 7));
        }
        if (parts.length >= 2) {
          _tp(parts[1].trim(), lc, 11).paint(canvas, Offset(ox + 6, oy - h - 17));
        }
      }
    }
  }

  // ── Curve (smooth polyline) ───────────────────────────────────────────────

  void _drawCurve(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    if (el.points == null || el.points!.length < 2) return;
    final pts =
        el.points!.map((pt) => Offset(pt[0] * size.width, pt[1] * size.height)).toList();
    final ideal = _bezierThrough(pts);
    _chalkStroke(canvas, _jitter(ideal, seed, 1.5), p, el.color, 2.2);

    if (p > 0.9 && el.label != null) {
      final op = ((p - 0.9) * 10).clamp(0.0, 1.0);
      final t  = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
      t.paint(canvas, pts.last + const Offset(6, -18));
    }
  }

  // ── Parabola ──────────────────────────────────────────────────────────────

  void _drawParabola(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    final cx     = (el.cx ?? 0.5) * size.width;
    final cy     = (el.cy ?? 0.5) * size.height;
    final x1     = (el.x1 ?? 0.05) * size.width;
    final x2     = (el.x2 ?? 0.95) * size.width;
    final aScale = (el.a ?? 2.0) * size.height;

    // 80 control points → smooth bezier curve
    const n = 80;
    final pts = List<Offset>.generate(n + 1, (i) {
      final x  = x1 + (x2 - x1) * i / n;
      final dx = (x - cx) / size.width;
      return Offset(x, cy + aScale * dx * dx);
    });

    final ideal = _bezierThrough(pts);
    _chalkStroke(canvas, _jitter(ideal, seed, 1.2), p, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final op  = ((p - 0.92) * 12.5).clamp(0.0, 1.0);
      final tip = pts.last;
      final t   = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
      t.paint(canvas, tip + const Offset(6, -12));
    }
  }

  // ── Sine / cosine wave ────────────────────────────────────────────────────

  void _drawSine(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    final x1   = (el.x1 ?? 0.05) * size.width;
    final x2   = (el.x2 ?? 0.95) * size.width;
    final cy   = (el.y ?? 0.5) * size.height;
    final amp  = (el.amplitude ?? 0.15) * size.height;
    final freq = el.frequency ?? 2.0;
    final ph   = el.phase ?? 0.0;

    // 150 control points — high-fidelity sine
    const n = 150;
    final pts = List<Offset>.generate(n + 1, (i) {
      final x = x1 + (x2 - x1) * i / n;
      final t = (x - x1) / (x2 - x1);
      return Offset(x, cy - amp * math.sin(t * freq * 2 * math.pi + ph));
    });

    final ideal = _bezierThrough(pts);
    _chalkStroke(canvas, _jitter(ideal, seed, 0.9), p, el.color, 2.2);

    if (p > 0.92 && el.label != null) {
      final op   = ((p - 0.92) * 12.5).clamp(0.0, 1.0);
      final endT = p;
      final endX = x1 + (x2 - x1) * endT;
      final endY = cy - amp * math.sin(endT * freq * 2 * math.pi + ph);
      final t    = _tp(el.label!, el.color.withValues(alpha: op), 12, bold: true);
      t.paint(canvas, Offset(endX + 5, endY - 14));
    }
  }

  // ── Triangle ──────────────────────────────────────────────────────────────

  void _drawTriangle(Canvas canvas, Size size, WhiteboardElement el, double p,
      {required int seed}) {
    if (el.points == null || el.points!.length < 3) return;
    final v = el.points!
        .map((pt) => Offset(pt[0] * size.width, pt[1] * size.height))
        .toList();

    // Perimeter path so we can draw progressively
    final ideal = Path()
      ..moveTo(v[0].dx, v[0].dy)
      ..lineTo(v[1].dx, v[1].dy)
      ..lineTo(v[2].dx, v[2].dy)
      ..close();

    _chalkStroke(canvas, _jitter(ideal, seed, 1.5), p, el.color, 2.0);

    // Transparent fill once fully drawn
    if (p > 0.95) {
      final fillP = ((p - 0.95) / 0.05).clamp(0.0, 1.0);
      final fillPath = Path()
        ..moveTo(v[0].dx, v[0].dy)
        ..lineTo(v[1].dx, v[1].dy)
        ..lineTo(v[2].dx, v[2].dy)
        ..close();
      canvas.drawPath(fillPath,
          Paint()
            ..color = el.color.withValues(alpha: fillP * 0.07)
            ..style = PaintingStyle.fill);
    }

    // Vertex labels
    if (p > 0.88 && el.label != null) {
      final labels = el.label!.split(',');
      const offs   = [Offset(-10, -22), Offset(10, 4), Offset(-12, 4)];
      for (int i = 0; i < math.min(labels.length, 3); i++) {
        final op = ((p - 0.88) / 0.12).clamp(0.0, 1.0);
        final t  = _tp(labels[i].trim(), el.color.withValues(alpha: op), 12, bold: true);
        t.paint(canvas, v[i] + offs[i]);
      }
    }
  }
}

// ── Student drawing painter ───────────────────────────────────────────────────
// Listens to _DrawingNotifier; repaints independently of widget tree.

class _StudentPainter extends CustomPainter {
  final _DrawingNotifier notifier;
  static const _inkColor = Color(0xFFFBBF24); // amber-yellow

  _StudentPainter(this.notifier) : super(repaint: notifier);

  @override
  bool shouldRepaint(_StudentPainter old) => false; // repaint via notifier

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

// ── Toolbar button widgets ────────────────────────────────────────────────────

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
              color: checking
                  ? const Color(0xFF252540)
                  : Colors.transparent),
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
