import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/anthropic_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing or malformed — app will show error in chat
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const LiseAIApp());
}

class LiseAIApp extends StatelessWidget {
  const LiseAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lise AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C6BF8),
          surface: Color(0xFF1A1A1A),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final Uint8List? imageBytes;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.imageBytes,
  });
}

// ── Main chat screen ──────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  AnthropicService? _anthropic;

  // History uses dynamic content to support both plain text and vision blocks.
  final List<Map<String, dynamic>> _history = [];

  final List<ChatMessage> _messages = [
    const ChatMessage(
      text: 'Bugün ne öğrenmek istiyorsun? ✨\nFotoğraf veya ekran görüntüsü de gönderebilirsin.',
      isUser: false,
    ),
  ];

  bool _isTyping = false;
  Uint8List? _pendingImage;
  String _pendingMime = 'image/jpeg';
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'your_api_key_here') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showApiKeyError());
    } else {
      _anthropic = AnthropicService(apiKey);
    }
  }

  void _showApiKeyError() {
    setState(() {
      _messages.add(const ChatMessage(
        text: '⚠️ API anahtarı bulunamadı. Lütfen .env dosyasına geçerli bir ANTHROPIC_API_KEY ekle ve uygulamayı yeniden başlat.',
        isUser: false,
        isError: true,
      ));
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Image picking ───────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      setState(() {
        _pendingImage = file.bytes;
        _pendingMime = ext == 'png' ? 'image/png' : 'image/jpeg';
      });
    }
  }

  void _handleDrop(DropDoneDetails details) async {
    for (final file in details.files) {
      final path = file.path.toLowerCase();
      if (path.endsWith('.jpg') || path.endsWith('.jpeg') ||
          path.endsWith('.png') || path.endsWith('.webp') ||
          path.endsWith('.gif')) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pendingImage = Uint8List.fromList(bytes);
          _pendingMime = path.endsWith('.png') ? 'image/png' : 'image/jpeg';
          _isDragging = false;
        });
        return;
      }
    }
    setState(() => _isDragging = false);
  }

  void _clearPendingImage() => setState(() => _pendingImage = null);

  // ── Send message ────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    final hasImage = _pendingImage != null;
    if ((trimmed.isEmpty && !hasImage) || _isTyping) return;

    final imageBytes = _pendingImage;
    final mime = _pendingMime;

    setState(() {
      _messages.add(ChatMessage(
        text: trimmed,
        isUser: true,
        imageBytes: imageBytes,
      ));
      _isTyping = true;
      _pendingImage = null;
    });
    _inputController.clear();
    _scrollToBottom();

    if (_anthropic == null) {
      setState(() => _isTyping = false);
      return;
    }

    if (imageBytes != null) {
      _history.add({
        'role': 'user',
        'content': AnthropicService.buildImageContent(imageBytes, mime, text: trimmed),
      });
    } else {
      _history.add({'role': 'user', 'content': trimmed});
    }

    try {
      final reply = await _anthropic!.sendMessage(_history);
      _history.add({'role': 'assistant', 'content': reply});
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } on AnthropicException catch (e) {
      if (!mounted) return;
      _history.removeLast();
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: '⚠️ ${e.message}', isUser: false, isError: true));
      });
    } catch (_) {
      if (!mounted) return;
      _history.removeLast();
      setState(() {
        _isTyping = false;
        _messages.add(const ChatMessage(
          text: '⚠️ Bağlantı hatası. İnternetini kontrol edip tekrar dene.',
          isUser: false,
          isError: true,
        ));
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildMessageList()),
                  if (_isTyping) _buildTypingIndicator(),
                  if (_pendingImage != null) _buildImagePreview(),
                  _buildInputBar(),
                ],
              ),
              if (_isDragging) _buildDropOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C6BF8), Color(0xFFBB86FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lise AI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _anthropic != null
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFF87171),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _anthropic != null ? 'Çevrimiçi' : 'API anahtarı eksik',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF)),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          _AvatarIcon(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // Thumbnail strip shown above input when an image is staged.
  Widget _buildImagePreview() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _pendingImage!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: _clearPendingImage,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF374151),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Text(
            'Fotoğraf hazır — mesajını yaz veya gönder.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _InputIconButton(
              icon: Icons.image_outlined,
              onTap: _pickImage,
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                enabled: !_isTyping,
                style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: const InputDecoration(
                  hintText: 'Bir şey sor veya fotoğraf gönder...',
                  hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            _SendOrMicButton(
              controller: _inputController,
              isLoading: _isTyping,
              hasPendingImage: _pendingImage != null,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  // Semi-transparent overlay shown while a file is being dragged over the app.
  Widget _buildDropOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF7C6BF8).withOpacity(0.15),
          border: Border.all(color: const Color(0xFF7C6BF8), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, color: Color(0xFF7C6BF8), size: 48),
            SizedBox(height: 12),
            Text(
              'Fotoğrafı buraya bırak',
              style: TextStyle(
                color: Color(0xFF7C6BF8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.isError;
    final hasImage = message.imageBytes != null;
    final hasText = message.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _AvatarIcon(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                gradient: isUser && !hasImage
                    ? const LinearGradient(
                        colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? (hasImage ? const Color(0xFF1E1E2E) : null)
                    : isError
                        ? const Color(0xFF2A1A1A)
                        : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isError
                    ? Border.all(color: const Color(0xFF7F1D1D), width: 0.5)
                    : null,
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    Image.memory(
                      message.imageBytes!,
                      width: 220,
                      fit: BoxFit.cover,
                    ),
                  if (hasText)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 15,
                          color: isUser
                              ? Colors.white
                              : isError
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFE5E7EB),
                          height: 1.45,
                        ),
                      ),
                    )
                  else if (hasImage)
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Avatar icon ────────────────────────────────────────────────────────────────

class _AvatarIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6BF8), Color(0xFFBB86FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
    );
  }
}

// ── Typing dots animation ──────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, _) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C6BF8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Input icon button ──────────────────────────────────────────────────────────

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _InputIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: const Color(0xFF6B7280), size: 22),
      ),
    );
  }
}

// ── Send / mic toggle button ───────────────────────────────────────────────────

class _SendOrMicButton extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool hasPendingImage;
  final ValueChanged<String> onSend;

  const _SendOrMicButton({
    required this.controller,
    required this.isLoading,
    required this.hasPendingImage,
    required this.onSend,
  });

  @override
  State<_SendOrMicButton> createState() => _SendOrMicButtonState();
}

class _SendOrMicButtonState extends State<_SendOrMicButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  bool get _showSend => _hasText || widget.hasPendingImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: widget.isLoading
            ? Container(
                key: const ValueKey('loading'),
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF7C6BF8),
                ),
              )
            : _showSend
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: () => widget.onSend(widget.controller.text),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: () {},
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mic_rounded, color: Color(0xFF9B8BFB), size: 20),
                    ),
                  ),
      ),
    );
  }
}
