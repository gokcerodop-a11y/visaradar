import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lesson_mode.dart';
import '../services/anthropic_service.dart';
import '../services/live_lesson_service.dart';
import '../services/profile_service.dart';
import 'lesson_board_page.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>?> pushLiveLesson(
  BuildContext context, {
  required AnthropicService anthropic,
  required List<Map<String, dynamic>> history,
  required LessonMode mode,
  required StudentLevel level,
  required ProfileService profileSvc,
}) {
  return Navigator.push<List<Map<String, dynamic>>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LiveLessonPage(
        anthropic: anthropic,
        initialHistory: history,
        mode: mode,
        level: level,
        profileSvc: profileSvc,
      ),
    ),
  );
}

// ── Simple message model ───────────────────────────────────────────────────────

class _Msg {
  String text;
  final bool isUser;
  bool isPartial;
  bool isError;

  _Msg({
    required this.text,
    required this.isUser,
    this.isPartial = false,
    this.isError = false,
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class LiveLessonPage extends StatefulWidget {
  final AnthropicService anthropic;
  final List<Map<String, dynamic>> initialHistory;
  final LessonMode mode;
  final StudentLevel level;
  final ProfileService profileSvc;

  const LiveLessonPage({
    super.key,
    required this.anthropic,
    required this.initialHistory,
    required this.mode,
    required this.level,
    required this.profileSvc,
  });

  @override
  State<LiveLessonPage> createState() => _LiveLessonPageState();
}

class _LiveLessonPageState extends State<LiveLessonPage>
    with TickerProviderStateMixin {
  // ── Service ──────────────────────────────────────────────────────────────
  LiveLessonService? _svc;
  bool _initializing = true;

  // ── Conversation state ────────────────────────────────────────────────────
  final List<_Msg> _messages = [];
  String _partialTranscript = '';
  LiveTeacherState _teacherState = LiveTeacherState.bekliyor;
  bool _showBoardButton = false;
  String? _boardQuestion;
  String? _boardReply;

  // ── Input ─────────────────────────────────────────────────────────────────
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _textMode = false;
  Uint8List? _pendingImage;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _stateCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat();
    _stateCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _init();
  }

  Future<void> _init() async {
    final svc = await LiveLessonService.create(
      anthropic: widget.anthropic,
      profileSvc: widget.profileSvc,
      mode: widget.mode,
      level: widget.level,
      history: widget.initialHistory,
    );

    if (!mounted) {
      await svc.dispose();
      return;
    }

    _svc = svc;
    _subscribe();

    setState(() => _initializing = false);

    // Opening greeting from teacher
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _messages.add(_Msg(
        text: _openingGreeting(),
        isUser: false,
        isPartial: false,
      ));
      setState(() {});
      _scrollToBottom();
    }

    await svc.start();
  }

  String _openingGreeting() {
    const greetings = [
      'Merhaba! Bugün hangi konuyu çalışmak istiyorsun? Dilediğin zaman başlayabilirsin.',
      'Hoş geldin! Canında hangi konu var? Soru sorabilir, fotoğraf yükleyebilirsin.',
      'Hazır mısın? Bugün seni dinliyorum — ne öğrenmek istiyorsan sor!',
    ];
    return greetings[DateTime.now().microsecond % greetings.length];
  }

  void _subscribe() {
    _svc!.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        case TeacherStateEvent(:final state):
          setState(() {
            _teacherState = state;
            // Finalize partial user transcript on teacher takeover
            if (state == LiveTeacherState.dusunuyor &&
                _partialTranscript.isNotEmpty) {
              _messages.add(_Msg(text: _partialTranscript, isUser: true));
              _partialTranscript = '';
            }
            // Finalize streaming teacher bubble
            if (state == LiveTeacherState.dinliyor ||
                state == LiveTeacherState.bekliyor) {
              _finalizeTeacherBubble();
            }
          });
          _scrollToBottom();

        case UserTranscriptEvent(:final text, :final isFinal):
          setState(() {
            if (isFinal) {
              _partialTranscript = '';
              // Bubble was added via state change; nothing extra needed
            } else {
              _partialTranscript = text;
            }
          });

        case TeacherChunkEvent(:final chunk, :final newBubble):
          setState(() {
            if (newBubble ||
                _messages.isEmpty ||
                !_messages.last.isPartial ||
                _messages.last.isUser) {
              _messages.add(_Msg(text: chunk, isUser: false, isPartial: true));
            } else {
              _messages.last.text += chunk;
            }
          });
          _scrollToBottomFast();

        case TeacherBubbleFinalizedEvent():
          setState(() => _finalizeTeacherBubble());

        case BoardTriggerEvent(:final question, :final reply):
          setState(() {
            _showBoardButton = true;
            _boardQuestion = question;
            _boardReply = reply;
          });

        case LiveErrorEvent(:final message):
          setState(() {
            _messages.add(
                _Msg(text: '⚠️ $message', isUser: false, isError: true));
          });

        case SessionEndedEvent():
          if (mounted) _onSessionEnded();
      }
    });
  }

  void _finalizeTeacherBubble() {
    for (final m in _messages) {
      if (!m.isUser) m.isPartial = false;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() => _textMode = false);
    _messages.add(_Msg(text: text, isUser: true));
    _scrollToBottom();
    _svc?.sendText(text);
  }

  void _interrupt() => _svc?.interrupt();

  Future<void> _pickImage() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _pendingImage = result.files.single.bytes);
  }

  void _sendWithImage() {
    final img = _pendingImage;
    if (img == null) return;
    final text = _textCtrl.text.trim().isEmpty
        ? 'Bu görseli analiz et ve açıkla.'
        : _textCtrl.text.trim();
    _textCtrl.clear();
    setState(() {
      _pendingImage = null;
      _textMode = false;
    });
    _messages.add(_Msg(text: text, isUser: true));
    _scrollToBottom();
    // For image, convert to sendText with a note (simplified for live mode)
    _svc?.sendText('$text [Görsel yüklendi]');
  }

  Future<void> _openBoard() async {
    final q = _boardQuestion;
    final r = _boardReply;
    if (q == null || r == null) return;

    final lesson = await widget.anthropic.generateLesson(q, r);
    if (!mounted) return;
    if (lesson != null &&
        lesson.steps.isNotEmpty &&
        lesson.elements.isNotEmpty) {
      await pushLessonBoard(context, lesson);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tahta hazırlanamadı. Tekrar dene.'),
            backgroundColor: Color(0xFF2A1A1A)),
      );
    }
  }

  void _endSession() async {
    await _svc?.endSession();
  }

  void _onSessionEnded() {
    final history = _svc?.history ?? [];
    Navigator.of(context).pop(history.isNotEmpty ? history : null);
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomFast() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _stateCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _svc?.dispose();
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

  Widget _buildInit() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF7C6BF8))),
          SizedBox(height: 14),
          Text('Canlı ders başlatılıyor…',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildMessageList()),
        if (_partialTranscript.isNotEmpty) _buildTranscriptStrip(),
        if (_teacherState == LiveTeacherState.dinliyor) _buildListeningWave(),
        if (_showBoardButton) _buildBoardTrigger(),
        if (_pendingImage != null) _buildImagePreview(),
        _buildInputBar(),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _endSession,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF9CA3AF), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Canlı Ders',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(widget.level.label,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          _TeacherStateBadge(
            state: _teacherState,
            pulseCtrl: _pulseCtrl,
            waveCtrl: _waveCtrl,
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _LiveBubble(msg: _messages[i]),
    );
  }

  // ── Partial transcript strip ───────────────────────────────────────────────

  Widget _buildTranscriptStrip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Color(0xFF4ADE80), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _partialTranscript,
              style:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Listening waveform ────────────────────────────────────────────────────

  Widget _buildListeningWave() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) {
                final phase = (_waveCtrl.value + i * 0.14) % 1.0;
                final h = 6.0 + 20.0 * math.sin(phase * 2 * math.pi).abs();
                return Container(
                  width: 4,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFF4ADE80),
                      const Color(0xFF7C6BF8),
                      i / 6,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  // ── Board trigger ─────────────────────────────────────────────────────────

  Widget _buildBoardTrigger() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: GestureDetector(
        onTap: _openBoard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1435), Color(0xFF0D0D20)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF7C6BF8).withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Opacity(
                  opacity: 0.6 + 0.4 * _pulseCtrl.value,
                  child: child,
                ),
                child: const Icon(Icons.auto_graph_rounded,
                    color: Color(0xFF9B8BFB), size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Tahtada Göster',
                  style: TextStyle(
                      color: Color(0xFF9B8BFB),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _showBoardButton = false;
                  _boardQuestion = null;
                  _boardReply = null;
                }),
                child: const Icon(Icons.close_rounded,
                    color: Color(0xFF4B5563), size: 16),
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
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_pendingImage!,
                    width: 56, height: 56, fit: BoxFit.cover),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _pendingImage = null),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: Color(0xFF374151), shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, size: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Text('Fotoğraf hazır',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          const Spacer(),
          GestureDetector(
            onTap: _sendWithImage,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C6BF8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Gönder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final isTeacherTalking = _teacherState == LiveTeacherState.acikliyor ||
        _teacherState == LiveTeacherState.tahtayaGeciyor ||
        _teacherState == LiveTeacherState.soruSoruyor;
    final isListening = _teacherState == LiveTeacherState.dinliyor;

    return Container(
      color: const Color(0xFF080808),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text mode input
          if (_textMode) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(
                          fontSize: 15, color: Colors.white, height: 1.4),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendText(),
                      decoration: const InputDecoration(
                        hintText: 'Mesajını yaz…',
                        hintStyle: TextStyle(color: Color(0xFF4B5563)),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  _SmallIconBtn(
                    icon: Icons.send_rounded,
                    color: const Color(0xFF7C6BF8),
                    onTap: _sendText,
                  ),
                  _SmallIconBtn(
                    icon: Icons.close_rounded,
                    color: const Color(0xFF4B5563),
                    onTap: () => setState(() {
                      _textMode = false;
                      _focusNode.unfocus();
                    }),
                  ),
                ],
              ),
            ),
          ],

          // Main button row
          Row(
            children: [
              // Image
              _SmallRoundBtn(
                icon: Icons.image_outlined,
                onTap: _pickImage,
                tooltip: 'Fotoğraf',
              ),
              const SizedBox(width: 8),
              // Keyboard toggle
              _SmallRoundBtn(
                icon: Icons.keyboard_alt_outlined,
                onTap: () {
                  setState(() => _textMode = !_textMode);
                  if (!_textMode) _focusNode.unfocus();
                },
                tooltip: 'Yaz',
                active: _textMode,
              ),
              const SizedBox(width: 8),

              // Central mic / interrupt button
              Expanded(
                child: GestureDetector(
                  onTap: isTeacherTalking ? _interrupt : null,
                  child: _CentralButton(
                    state: _teacherState,
                    pulseCtrl: _pulseCtrl,
                    hasVoice: _svc?.hasVoice ?? false,
                    hasSpeech: _svc?.hasSpeech ?? false,
                  ),
                ),
              ),

              const SizedBox(width: 8),
              // End session
              _SmallRoundBtn(
                icon: Icons.stop_circle_outlined,
                onTap: _endSession,
                tooltip: 'Bitir',
                color: const Color(0xFFF87171),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Teacher state badge ────────────────────────────────────────────────────────

class _TeacherStateBadge extends StatelessWidget {
  final LiveTeacherState state;
  final AnimationController pulseCtrl;
  final AnimationController waveCtrl;

  const _TeacherStateBadge({
    required this.state,
    required this.pulseCtrl,
    required this.waveCtrl,
  });

  Color get _color => switch (state) {
        LiveTeacherState.dinliyor        => const Color(0xFF4ADE80),
        LiveTeacherState.dusunuyor       => const Color(0xFFFBBF24),
        LiveTeacherState.acikliyor       => const Color(0xFF60A5FA),
        LiveTeacherState.tahtayaGeciyor  => const Color(0xFF7C6BF8),
        LiveTeacherState.soruSoruyor     => const Color(0xFFF97316),
        LiveTeacherState.bekliyor        => const Color(0xFF4B5563),
      };

  IconData get _icon => switch (state) {
        LiveTeacherState.dinliyor        => Icons.mic_rounded,
        LiveTeacherState.dusunuyor       => Icons.psychology_rounded,
        LiveTeacherState.acikliyor       => Icons.record_voice_over_rounded,
        LiveTeacherState.tahtayaGeciyor  => Icons.draw_rounded,
        LiveTeacherState.soruSoruyor     => Icons.help_outline_rounded,
        LiveTeacherState.bekliyor        => Icons.pause_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final glow = state == LiveTeacherState.dinliyor ||
            state == LiveTeacherState.acikliyor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _color.withValues(
                  alpha: glow ? 0.5 + 0.3 * pulseCtrl.value : 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: _color, size: 13),
              const SizedBox(width: 5),
              Text(
                state.label,
                style: TextStyle(
                  color: _color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Central mic / interrupt button ─────────────────────────────────────────────

class _CentralButton extends StatelessWidget {
  final LiveTeacherState state;
  final AnimationController pulseCtrl;
  final bool hasVoice;
  final bool hasSpeech;

  const _CentralButton({
    required this.state,
    required this.pulseCtrl,
    required this.hasVoice,
    required this.hasSpeech,
  });

  @override
  Widget build(BuildContext context) {
    final isTeacherTalking = state == LiveTeacherState.acikliyor ||
        state == LiveTeacherState.tahtayaGeciyor ||
        state == LiveTeacherState.soruSoruyor;
    final isListening = state == LiveTeacherState.dinliyor;
    final isThinking = state == LiveTeacherState.dusunuyor;

    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        Color bg;
        Color border;
        Widget child;

        if (isTeacherTalking) {
          bg = Color.lerp(const Color(0xFF1A0A3A),
              const Color(0xFF2A1A5A), pulseCtrl.value)!;
          border = Color.lerp(const Color(0xFF7C6BF8),
              const Color(0xFF9B8BFB), pulseCtrl.value)!;
          child = const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.front_hand_rounded,
                  color: Color(0xFF9B8BFB), size: 16),
              SizedBox(width: 6),
              Text('Kes',
                  style: TextStyle(
                      color: Color(0xFF9B8BFB),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          );
        } else if (isListening) {
          bg = Color.lerp(const Color(0xFF0A1A0A),
              const Color(0xFF0F2A0F), pulseCtrl.value)!;
          border = Color.lerp(const Color(0xFF4ADE80),
              const Color(0xFF6AEE9F), pulseCtrl.value)!;
          child = const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_rounded, color: Color(0xFF4ADE80), size: 16),
              SizedBox(width: 6),
              Text('Dinliyor',
                  style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          );
        } else if (isThinking) {
          bg = const Color(0xFF1A1700);
          border = const Color(0xFFFBBF24);
          child = const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Color(0xFFFBBF24))),
              SizedBox(width: 8),
              Text('Düşünüyor…',
                  style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          );
        } else {
          // bekliyor
          bg = const Color(0xFF111111);
          border = const Color(0xFF2A2A2A);
          child = hasSpeech
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_none_rounded,
                        color: Color(0xFF4B5563), size: 16),
                    SizedBox(width: 6),
                    Text('Konuş',
                        style: TextStyle(
                            color: Color(0xFF4B5563), fontSize: 13)),
                  ],
                )
              : const Text('Dinliyor…',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 13));
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 46,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: child,
        );
      },
    );
  }
}

// ── Live message bubble ────────────────────────────────────────────────────────

class _LiveBubble extends StatelessWidget {
  final _Msg msg;

  const _LiveBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final isError = msg.isError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C6BF8), Color(0xFFBB86FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 13),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
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
                        : msg.isPartial
                            ? const Color(0xFF1A1A2A)
                            : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isError
                    ? Border.all(
                        color: const Color(0xFF7F1D1D), width: 0.5)
                    : msg.isPartial
                        ? Border.all(
                            color: const Color(0xFF7C6BF8)
                                .withValues(alpha: 0.3))
                        : null,
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : isError
                          ? const Color(0xFFFCA5A5)
                          : msg.isPartial
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFFE5E7EB),
                  fontSize: 14,
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

// ── Small icon buttons ─────────────────────────────────────────────────────────

class _SmallRoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;
  final Color? color;

  const _SmallRoundBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? const Color(0xFF7C6BF8) : const Color(0xFF6B7280));
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF1A1435)
                : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active
                    ? const Color(0xFF7C6BF8).withValues(alpha: 0.5)
                    : const Color(0xFF1F2937)),
          ),
          child: Icon(icon, color: c, size: 18),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallIconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
