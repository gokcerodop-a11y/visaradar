import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/lesson_mode.dart';
import '../services/realtime_voice_engine.dart';
import 'lesson_board_page.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>?> pushVoiceConversation(
  BuildContext context, {
  required VoiceSessionContext ctx,
}) {
  return Navigator.push<List<Map<String, dynamic>>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VoiceConversationPage(ctx: ctx),
    ),
  );
}

// ── Bubble model ──────────────────────────────────────────────────────────────

class _Bubble {
  String text;
  final bool isUser;
  bool isPartial;
  bool isError;

  _Bubble({
    required this.text,
    required this.isUser,
    this.isPartial = false,
    this.isError = false,
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class VoiceConversationPage extends StatefulWidget {
  final VoiceSessionContext ctx;

  const VoiceConversationPage({super.key, required this.ctx});

  @override
  State<VoiceConversationPage> createState() => _VoiceConversationPageState();
}

class _VoiceConversationPageState extends State<VoiceConversationPage>
    with TickerProviderStateMixin {

  // ── Engine ────────────────────────────────────────────────────────────────
  RealtimeVoiceEngine? _engine;
  bool _initializing = true;

  // ── Conversation ──────────────────────────────────────────────────────────
  final List<_Bubble> _bubbles = [];
  String _partialTranscript = '';
  ConversationState _csState = ConversationState.idle;
  bool _showBoardButton = false;
  String? _boardQuestion;
  String? _boardReply;

  // ── Text input ────────────────────────────────────────────────────────────
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _textMode = false;
  Uint8List? _pendingImage;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _orbCtrl; // slow-breathing orb
  late final AnimationController _waveCtrl; // fast wave for speaking
  late final AnimationController _flashCtrl; // interrupt flash

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat();
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _init();
  }

  Future<void> _init() async {
    final engine = await RealtimeVoiceEngine.create(widget.ctx);

    if (!mounted) {
      await engine.dispose();
      return;
    }

    _engine = engine;
    _subscribe();
    setState(() => _initializing = false);

    // Opening greeting
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      _bubbles.add(_Bubble(
        text: _greeting(),
        isUser: false,
      ));
      setState(() {});
    }

    await engine.start();
  }

  String _greeting() {
    final mode = widget.ctx.mode;
    if (mode == LessonMode.sinavKocu) {
      return 'Sınav moduna hoş geldin! Hangi konudan soru çözelim?';
    }
    if (mode == LessonMode.hizliCevap) {
      return 'Hazırım! Sorunuzu bekliyorum.';
    }
    return 'Merhaba! Hangi konuyu çalışmak istiyorsun?';
  }

  // ── Event subscription ────────────────────────────────────────────────────

  void _subscribe() {
    _engine!.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        case StateChangedEvent(:final state):
          setState(() {
            _csState = state;
            if (state == ConversationState.interrupted) {
              _flashCtrl.forward(from: 0);
            }
            if (state == ConversationState.thinking &&
                _partialTranscript.isNotEmpty) {
              _addBubble(_partialTranscript, isUser: true);
              _partialTranscript = '';
            }
            if (state == ConversationState.listening) {
              _finalizePartialBubble();
            }
          });

        case TranscriptEvent(:final text, :final isFinal):
          setState(() {
            if (isFinal) {
              _partialTranscript = '';
            } else {
              _partialTranscript = text;
            }
          });

        case AssistantChunkEvent(:final chunk, :final isNewBubble):
          setState(() {
            if (isNewBubble ||
                _bubbles.isEmpty ||
                !_bubbles.last.isPartial ||
                _bubbles.last.isUser) {
              _bubbles.add(_Bubble(text: chunk, isUser: false, isPartial: true));
            } else {
              _bubbles.last.text += chunk;
            }
          });
          _scrollToBottom(fast: true);

        case AssistantFinalizedEvent():
          setState(() => _finalizePartialBubble());

        case BoardTriggerEvent(:final question, :final reply):
          setState(() {
            _showBoardButton = true;
            _boardQuestion = question;
            _boardReply = reply;
          });

        case RealtimeErrorEvent(:final message):
          setState(() {
            _bubbles.add(_Bubble(text: '⚠️ $message', isUser: false, isError: true));
          });

        case SessionEndedEvent():
          if (mounted) _popBack();
      }
    });
  }

  void _addBubble(String text, {required bool isUser}) {
    _bubbles.add(_Bubble(text: text, isUser: isUser));
    _scrollToBottom();
  }

  void _finalizePartialBubble() {
    for (final b in _bubbles) {
      b.isPartial = false;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() {
      _textMode = false;
      _addBubble(text, isUser: true);
    });
    _engine?.sendText(text);
  }

  void _handleOrbTap() {
    if (_csState == ConversationState.speaking) {
      _engine?.interrupt();
    } else if (_csState == ConversationState.paused) {
      _engine?.resume();
    } else if (_csState == ConversationState.listening) {
      _engine?.pause();
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() => _pendingImage = result.files.single.bytes);
    }
  }

  Future<void> _openBoard() async {
    final q = _boardQuestion;
    final r = _boardReply;
    if (q == null || r == null) return;

    final lesson = await widget.ctx.anthropic.generateLesson(q, r);
    if (!mounted) return;
    if (lesson != null &&
        lesson.steps.isNotEmpty &&
        lesson.elements.isNotEmpty) {
      await pushLessonBoard(context, lesson);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tahta hazırlanamadı.'),
        backgroundColor: Color(0xFF2A1A1A),
      ));
    }
  }

  Future<void> _endSession() async {
    await _engine?.endSession();
  }

  void _popBack() {
    final history = _engine?.history ?? [];
    Navigator.of(context).pop(history.isNotEmpty ? history : null);
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom({bool fast = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (fast) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        } else {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _orbCtrl.dispose();
    _waveCtrl.dispose();
    _flashCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _engine?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: _initializing ? _buildInit() : _buildBody(),
      ),
    );
  }

  Widget _buildInit() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7C6BF8))),
            SizedBox(height: 12),
            Text('Hazırlanıyor…',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
          ],
        ),
      );

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        // Compact conversation history (last few bubbles)
        if (_bubbles.isNotEmpty)
          Expanded(
            flex: 3,
            child: _buildBubbleList(),
          ),
        // Partial transcript
        if (_partialTranscript.isNotEmpty) _buildTranscriptStrip(),
        // Central orb
        Expanded(
          flex: _bubbles.isEmpty ? 5 : 3,
          child: Center(child: _buildOrb()),
        ),
        // State label
        _buildStateLabel(),
        // Board trigger
        if (_showBoardButton) _buildBoardTrigger(),
        // Pending image
        if (_pendingImage != null) _buildImagePreview(),
        // Text input
        if (_textMode) _buildTextInput(),
        // Bottom controls
        _buildBottomBar(),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111111))),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _endSession,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gerçek Zamanlı Ders',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(
                  '${widget.ctx.level.label} · ${widget.ctx.mode.label}',
                  style:
                      const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
                ),
              ],
            ),
          ),
          // Voice backend indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (_engine?.hasVoice ?? false)
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: (_engine?.hasVoice ?? false)
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF4B5563),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  (_engine?.hasSpeech ?? false) ? 'STT' : 'Metin',
                  style:
                      const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bubble list ───────────────────────────────────────────────────────────

  Widget _buildBubbleList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      itemCount: _bubbles.length,
      itemBuilder: (_, i) => _BubbleWidget(bubble: _bubbles[i]),
    );
  }

  // ── Transcript strip ──────────────────────────────────────────────────────

  Widget _buildTranscriptStrip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Color(0xFF4ADE80), size: 12),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _partialTranscript,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Central orb ───────────────────────────────────────────────────────────

  Widget _buildOrb() {
    return GestureDetector(
      onTap: _handleOrbTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_orbCtrl, _waveCtrl, _flashCtrl]),
        builder: (_, __) {
          return CustomPaint(
            size: const Size(140, 140),
            painter: _OrbPainter(
              state: _csState,
              breathe: _orbCtrl.value,
              wave: _waveCtrl.value,
              flash: _flashCtrl.value,
            ),
          );
        },
      ),
    );
  }

  // ── State label ───────────────────────────────────────────────────────────

  Widget _buildStateLabel() {
    final hint = switch (_csState) {
      ConversationState.speaking   => 'Orb\'a dokun → Kes',
      ConversationState.listening  => 'Dinliyor — konuş',
      ConversationState.thinking   => 'Yanıt hazırlanıyor…',
      ConversationState.interrupted => 'Yeniden başlıyor…',
      ConversationState.paused     => 'Duraklatıldı — dokun → devam',
      ConversationState.idle       => '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          hint,
          key: ValueKey(_csState),
          style: TextStyle(
            color: _stateColor(_csState).withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _stateColor(ConversationState s) => switch (s) {
        ConversationState.listening   => const Color(0xFF60A5FA),
        ConversationState.thinking    => const Color(0xFFA78BFA),
        ConversationState.speaking    => const Color(0xFF4ADE80),
        ConversationState.interrupted => const Color(0xFFF87171),
        ConversationState.paused      => const Color(0xFF6B7280),
        ConversationState.idle        => const Color(0xFF374151),
      };

  // ── Board trigger ─────────────────────────────────────────────────────────

  Widget _buildBoardTrigger() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: GestureDetector(
        onTap: _openBoard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A1435), Color(0xFF0D0D20)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF7C6BF8).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _orbCtrl,
                builder: (_, child) => Opacity(
                  opacity: 0.6 + 0.4 * _orbCtrl.value,
                  child: child,
                ),
                child: const Icon(Icons.auto_graph_rounded,
                    color: Color(0xFF9B8BFB), size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Tahtada Göster',
                  style: TextStyle(
                      color: Color(0xFF9B8BFB),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _showBoardButton = false;
                  _boardQuestion = null;
                  _boardReply = null;
                }),
                child: const Icon(Icons.close_rounded,
                    color: Color(0xFF4B5563), size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_pendingImage!,
                width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Fotoğraf hazır',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          ),
          GestureDetector(
            onTap: () => setState(() => _pendingImage = null),
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF4B5563), size: 16),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final img = _pendingImage;
              if (img == null) return;
              setState(() => _pendingImage = null);
              _engine?.sendText('Bu görseli analiz et ve açıkla. [Görsel yüklendi]');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C6BF8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Gönder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Text input ────────────────────────────────────────────────────────────

  Widget _buildTextInput() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: const InputDecoration(
                hintText: 'Yaz…',
                hintStyle: TextStyle(color: Color(0xFF4B5563)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: _sendText,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.send_rounded,
                  color: Color(0xFF7C6BF8), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconBtn(
            icon: Icons.image_outlined,
            onTap: _pickImage,
            tooltip: 'Fotoğraf',
          ),
          _IconBtn(
            icon: Icons.keyboard_alt_outlined,
            onTap: () => setState(() => _textMode = !_textMode),
            tooltip: 'Yaz',
            active: _textMode,
          ),
          // Pause/Resume
          _IconBtn(
            icon: _csState == ConversationState.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            onTap: () => _csState == ConversationState.paused
                ? _engine?.resume()
                : _engine?.pause(),
            tooltip: _csState == ConversationState.paused ? 'Devam' : 'Duraklat',
          ),
          _IconBtn(
            icon: Icons.stop_circle_outlined,
            onTap: _endSession,
            tooltip: 'Bitir',
            color: const Color(0xFFF87171),
          ),
        ],
      ),
    );
  }
}

// ── Orb painter ───────────────────────────────────────────────────────────────

class _OrbPainter extends CustomPainter {
  final ConversationState state;
  final double breathe; // 0-1 slow pulse
  final double wave;   // 0-1 fast wave
  final double flash;  // 0-1 interrupt flash

  const _OrbPainter({
    required this.state,
    required this.breathe,
    required this.wave,
    required this.flash,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final (core, glow) = _colors;

    // ── Outer glow rings ──────────────────────────────────────────────────

    if (state == ConversationState.speaking) {
      // Green wave rings — undulate like a sound wave
      for (int i = 4; i >= 1; i--) {
        final phase = (wave + i * 0.18) % 1.0;
        final expand = math.sin(phase * 2 * math.pi).abs();
        final ringR = maxR * (0.9 + i * 0.12 * expand);
        final opacity = 0.04 + 0.06 * (1 - i / 5.0) * expand;
        canvas.drawCircle(center, ringR,
            Paint()..color = glow.withValues(alpha: opacity));
      }
    } else if (state == ConversationState.listening) {
      // Blue pulsing rings
      for (int i = 3; i >= 1; i--) {
        final ringR = maxR * (0.85 + i * 0.10 * breathe);
        final opacity = 0.06 * (1 - i / 4.0) * breathe;
        canvas.drawCircle(center, ringR,
            Paint()..color = glow.withValues(alpha: opacity));
      }
    } else if (state == ConversationState.thinking) {
      // Purple slow rotation ring
      for (int i = 2; i >= 1; i--) {
        final ringR = maxR * (0.80 + i * 0.08 * (0.5 + 0.5 * breathe));
        final opacity = 0.08 * breathe;
        canvas.drawCircle(center, ringR,
            Paint()..color = glow.withValues(alpha: opacity));
      }
    }

    // ── Interrupted flash ─────────────────────────────────────────────────
    if (flash > 0) {
      final flashOpacity = flash * 0.3 * math.sin(flash * math.pi);
      canvas.drawCircle(center, maxR * 1.2,
          Paint()..color = const Color(0xFFF87171).withValues(alpha: flashOpacity));
    }

    // ── Orb glow halo ─────────────────────────────────────────────────────
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glow.withValues(alpha: 0.18 + 0.10 * breathe),
          glow.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR * 1.1));
    canvas.drawCircle(center, maxR * 1.1, haloPaint);

    // ── Inner orb ────────────────────────────────────────────────────────
    final innerR = maxR * (0.68 + 0.06 * breathe);
    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.1,
        colors: [
          core.withValues(alpha: 0.9),
          glow.withValues(alpha: 0.95),
          glow.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerR));
    canvas.drawCircle(center, innerR, orbPaint);

    // ── Inner highlight ───────────────────────────────────────────────────
    final hlPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: innerR));
    canvas.drawCircle(center, innerR, hlPaint);

    // ── Speaking waves on orb surface ────────────────────────────────────
    if (state == ConversationState.speaking) {
      for (int i = 0; i < 7; i++) {
        final phase = (wave + i / 7.0) % 1.0;
        final barH = innerR * 0.4 * math.sin(phase * 2 * math.pi).abs() + 2;
        final x = center.dx - innerR * 0.55 + i * (innerR * 1.1 / 6);
        final barRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, center.dy), width: 2.5, height: barH),
          const Radius.circular(2),
        );
        canvas.drawRRect(
          barRect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Icon overlay ──────────────────────────────────────────────────────
    _paintIcon(canvas, center, innerR);
  }

  void _paintIcon(Canvas canvas, Offset center, double r) {
    // Simple dot indicator in center based on state
    final dotColor = switch (state) {
      ConversationState.speaking    => Colors.white.withValues(alpha: 0.0), // waves instead
      ConversationState.thinking    => Colors.white.withValues(alpha: 0.5),
      ConversationState.interrupted => const Color(0xFFFCA5A5).withValues(alpha: 0.8),
      ConversationState.paused      => Colors.white.withValues(alpha: 0.5),
      _                             => Colors.white.withValues(alpha: 0.3),
    };

    if (state == ConversationState.thinking) {
      // Small rotating dots
      for (int i = 0; i < 3; i++) {
        final angle = wave * 2 * math.pi + i * 2 * math.pi / 3;
        final pos = center + Offset(math.cos(angle) * r * 0.22, math.sin(angle) * r * 0.22);
        canvas.drawCircle(pos, 3.5, Paint()..color = dotColor);
      }
    } else if (state == ConversationState.paused) {
      // Pause bars
      final p = Paint()..color = dotColor;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center - Offset(6, 0), width: 4, height: 14),
          const Radius.circular(2)), p);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center + Offset(6, 0), width: 4, height: 14),
          const Radius.circular(2)), p);
    }
  }

  (Color core, Color glow) get _colors => switch (state) {
        ConversationState.listening   => (const Color(0xFF1E3A5F), const Color(0xFF3B82F6)),
        ConversationState.thinking    => (const Color(0xFF2D1A4D), const Color(0xFFA78BFA)),
        ConversationState.speaking    => (const Color(0xFF0F3020), const Color(0xFF4ADE80)),
        ConversationState.interrupted => (const Color(0xFF3A1010), const Color(0xFFF87171)),
        ConversationState.paused      => (const Color(0xFF1A1A1A), const Color(0xFF4B5563)),
        ConversationState.idle        => (const Color(0xFF111111), const Color(0xFF374151)),
      };

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.state != state ||
      old.breathe != breathe ||
      old.wave != wave ||
      old.flash != flash;
}

// ── Bubble widget ─────────────────────────────────────────────────────────────

class _BubbleWidget extends StatelessWidget {
  final _Bubble bubble;
  const _BubbleWidget({required this.bubble});

  @override
  Widget build(BuildContext context) {
    final isUser = bubble.isUser;
    final isError = bubble.isError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C6BF8), Color(0xFFBB86FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(7),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 11),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: isUser && !isError
                    ? const LinearGradient(
                        colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                color: isUser
                    ? null
                    : isError
                        ? const Color(0xFF2A1A1A)
                        : bubble.isPartial
                            ? const Color(0xFF131320)
                            : const Color(0xFF111111),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 3),
                  bottomRight: Radius.circular(isUser ? 3 : 16),
                ),
                border: bubble.isPartial && !isUser
                    ? Border.all(
                        color: const Color(0xFF7C6BF8).withValues(alpha: 0.25))
                    : null,
              ),
              child: Text(
                bubble.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : isError
                          ? const Color(0xFFFCA5A5)
                          : bubble.isPartial
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFFE5E7EB),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final Color? color;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (active ? const Color(0xFF7C6BF8) : const Color(0xFF6B7280));
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color:
              active ? const Color(0xFF1A1435) : const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: active
                  ? const Color(0xFF7C6BF8).withValues(alpha: 0.4)
                  : const Color(0xFF1F2937)),
        ),
        child: Icon(icon, color: c, size: 18),
      ),
    );
    return tooltip != null
        ? Tooltip(message: tooltip!, child: btn)
        : btn;
  }
}
