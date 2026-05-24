import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/image_context_model.dart';

// ── VisualOverlay ─────────────────────────────────────────────────────────────
//
// Draggable floating image thumbnail with:
//   • Mode badge (Çözüm / Öğretim / Hata)
//   • Compare toggle (uploaded ↔ AI description)
//   • Spotlight mode (dim + focus oval)
//   • Animated teacher cursor
//   • Zoom / dismiss controls

class VisualOverlay extends StatefulWidget {
  final ImageContext ctx;
  final VoidCallback onDismiss;
  final VoidCallback onOpenBoard;
  final ValueChanged<bool> onCompareModeChanged;
  final ValueChanged<bool> onSpotlightModeChanged;
  final ValueChanged<Offset> onPositionChanged;

  const VisualOverlay({
    super.key,
    required this.ctx,
    required this.onDismiss,
    required this.onOpenBoard,
    required this.onCompareModeChanged,
    required this.onSpotlightModeChanged,
    required this.onPositionChanged,
  });

  @override
  State<VisualOverlay> createState() => _VisualOverlayState();
}

class _VisualOverlayState extends State<VisualOverlay>
    with SingleTickerProviderStateMixin {
  late Offset _pos;
  late AnimationController _cursorCtrl;
  late Animation<Offset> _cursorAnim;
  Offset _cursorTarget = const Offset(0.5, 0.5);

  // Overlay display size
  static const double _w = 200;
  static const double _h = 150;
  static const double _headerH = 28;

  @override
  void initState() {
    super.initState();
    _pos = widget.ctx.overlayPosition;
    _cursorCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _cursorAnim = Tween<Offset>(
      begin: const Offset(0.5, 0.5),
      end: const Offset(0.5, 0.5),
    ).animate(CurvedAnimation(parent: _cursorCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(VisualOverlay old) {
    super.didUpdateWidget(old);
    final newCursor = widget.ctx.teacherCursorPos;
    if (newCursor != null && newCursor != _cursorTarget) {
      _animateCursor(newCursor);
    }
  }

  void _animateCursor(Offset target) {
    final begin = _cursorAnim.value;
    _cursorTarget = target;
    _cursorAnim = Tween<Offset>(begin: begin, end: target).animate(
        CurvedAnimation(parent: _cursorCtrl, curve: Curves.easeInOut));
    _cursorCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          final size = MediaQuery.of(context).size;
          setState(() {
            _pos = Offset(
              (_pos.dx + d.delta.dx).clamp(0, size.width - _w),
              (_pos.dy + d.delta.dy).clamp(0, size.height - _h - _headerH - 80),
            );
          });
          widget.onPositionChanged(_pos);
        },
        child: Material(
          color: Colors.transparent,
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final result = widget.ctx.analysisResult;
    final modeColor = result?.modeColor ?? const Color(0xFF7C6BF8);
    final modeLabel = result?.modeLabel ?? 'Analiz Ediliyor…';

    return Container(
      width: _w,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: modeColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: modeColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: drag handle + mode badge + close ──────────────────────
          _buildHeader(modeLabel, modeColor),

          // ── Image area ────────────────────────────────────────────────────
          _buildImageArea(modeColor),

          // ── Action bar ────────────────────────────────────────────────────
          _buildActionBar(modeColor),
        ],
      ),
    );
  }

  Widget _buildHeader(String modeLabel, Color modeColor) {
    return Container(
      height: _headerH,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: modeColor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              modeLabel,
              style: TextStyle(
                  color: modeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF4B5563), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea(Color modeColor) {
    return Stack(
      children: [
        // Image or compare view
        widget.ctx.isCompareMode
            ? _buildCompareView()
            : _buildSingleImage(),

        // Spotlight overlay
        if (widget.ctx.isSpotlightMode) _buildSpotlight(modeColor),

        // Teacher cursor
        AnimatedBuilder(
          animation: _cursorAnim,
          builder: (_, __) => _buildCursor(_cursorAnim.value, modeColor),
        ),
      ],
    );
  }

  Widget _buildSingleImage() {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        width: _w,
        height: _h,
        child: Image.memory(
          widget.ctx.imageBytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _buildCompareView() {
    final description = widget.ctx.aiCorrectedDescription;
    return SizedBox(
      width: _w,
      height: _h,
      child: Row(
        children: [
          // Left: original
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.ctx.imageBytes,
                    fit: BoxFit.cover, gaplessPlayback: true),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    padding: const EdgeInsets.all(3),
                    child: const Text('Yüklenen',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(width: 1, color: const Color(0xFF374151)),

          // Right: AI version
          Expanded(
            child: Container(
              color: const Color(0xFF050510),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_fix_high_rounded,
                      color: Color(0xFF7C6BF8), size: 18),
                  const SizedBox(height: 4),
                  Text(
                    description ?? 'AI düzeltmesi hazırlanıyor…',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 7.5, height: 1.4),
                    textAlign: TextAlign.center,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlight(Color modeColor) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _SpotlightPainter(
          spotRegion: widget.ctx.spotlightRegion,
          color: modeColor,
        ),
      ),
    );
  }

  Widget _buildCursor(Offset norm, Color modeColor) {
    if (widget.ctx.teacherCursorPos == null) return const SizedBox.shrink();
    final x = norm.dx * _w;
    final y = norm.dy * _h;
    return Positioned(
      left: x - 10,
      top: y - 10,
      child: _AnimatedCursorDot(color: modeColor),
    );
  }

  Widget _buildActionBar(Color modeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Board redraw
          _ActionBtn(
            icon: Icons.auto_graph_rounded,
            label: 'Tahtada',
            color: modeColor,
            onTap: widget.onOpenBoard,
          ),
          // Compare toggle
          _ActionBtn(
            icon: Icons.compare_rounded,
            label: 'Karşılaştır',
            color: widget.ctx.isCompareMode
                ? modeColor
                : const Color(0xFF4B5563),
            onTap: () =>
                widget.onCompareModeChanged(!widget.ctx.isCompareMode),
          ),
          // Spotlight toggle
          _ActionBtn(
            icon: Icons.highlight_rounded,
            label: 'Odak',
            color: widget.ctx.isSpotlightMode
                ? modeColor
                : const Color(0xFF4B5563),
            onTap: () =>
                widget.onSpotlightModeChanged(!widget.ctx.isSpotlightMode),
          ),
        ],
      ),
    );
  }
}

// ── Spotlight painter ─────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? spotRegion;
  final Color color;

  const _SpotlightPainter({required this.spotRegion, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.60),
    );

    // Bright spot (oval)
    final spot = spotRegion != null
        ? Rect.fromLTWH(
            spotRegion!.left * size.width,
            spotRegion!.top * size.height,
            spotRegion!.width * size.width,
            spotRegion!.height * size.height,
          )
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.55,
            height: size.height * 0.40,
          );

    // Cut out the spotlight region
    canvas.saveLayer(null, Paint());
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: 0.60));
    canvas.drawOval(spot, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Glow ring
    canvas.drawOval(
      spot.inflate(2),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotRegion != spotRegion || old.color != color;
}

// ── Animated cursor dot ───────────────────────────────────────────────────────

class _AnimatedCursorDot extends StatefulWidget {
  final Color color;
  const _AnimatedCursorDot({required this.color});

  @override
  State<_AnimatedCursorDot> createState() => _AnimatedCursorDotState();
}

class _AnimatedCursorDotState extends State<_AnimatedCursorDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final scale = 0.8 + 0.4 * _ctrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.25),
              border: Border.all(color: widget.color, width: 1.5),
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: widget.color),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Visual mode badge (standalone, for top of screen) ────────────────────────

class VisualModeBadge extends StatelessWidget {
  final ImageAnalysisResult result;
  final VoidCallback onDismiss;

  const VisualModeBadge({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: result.modeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: result.modeColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          _modeIcon(result.suggestedMode, result.modeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.modeLabel,
                  style: TextStyle(
                      color: result.modeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                if (result.topicHint != null)
                  Text(
                    result.topicHint!,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (result.detectedMistakes.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${result.detectedMistakes.length} hata',
                style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF4B5563), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _modeIcon(VisualMode mode, Color color) {
    final icon = switch (mode) {
      VisualMode.solutionMode  => Icons.calculate_outlined,
      VisualMode.teachingMode  => Icons.school_outlined,
      VisualMode.errorAnalysis => Icons.error_outline_rounded,
    };
    return Icon(icon, color: color, size: 20);
  }
}

// ── Analysis loading indicator ────────────────────────────────────────────────

class VisualAnalyzingBadge extends StatefulWidget {
  const VisualAnalyzingBadge({super.key});

  @override
  State<VisualAnalyzingBadge> createState() => _VisualAnalyzingBadgeState();
}

class _VisualAnalyzingBadgeState extends State<VisualAnalyzingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C6BF8).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF7C6BF8).withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF7C6BF8), size: 16),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Görsel analiz ediliyor…',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
