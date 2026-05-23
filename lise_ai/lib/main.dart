import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'models/whiteboard_element.dart';
import 'services/anthropic_service.dart';
import 'services/storage_service.dart';
import 'widgets/math_markdown.dart';
import 'widgets/whiteboard_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

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
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF111111)),
      ),
      home: const ChatScreen(),
    );
  }
}

// ── Markdown style (shared) ───────────────────────────────────────────────────

MarkdownStyleSheet _mdStyle(BuildContext context) => MarkdownStyleSheet(
      p: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 15, height: 1.5),
      h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
      h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
      h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      em: const TextStyle(color: Color(0xFFE5E7EB), fontStyle: FontStyle.italic),
      code: const TextStyle(
        color: Color(0xFFBB86FC),
        backgroundColor: Color(0xFF1A1A2E),
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF7C6BF8), width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      listBullet: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 15),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF374151))),
      ),
    );

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

// ── Chat screen ───────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final _storage = StorageService();
  AnthropicService? _anthropic;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── State ─────────────────────────────────────────────────────────────────
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _history = [];
  List<ConversationMeta> _convList = [];

  String? _currentConvId;
  bool _loading = true;

  // Typing dots phase (before first streaming token)
  bool _isTyping = false;
  // Streaming phase: null = not streaming, non-null = text received so far
  String? _streamingText;

  Uint8List? _pendingImage;
  String _pendingMime = 'image/jpeg';
  bool _isDragging = false;

  // ── Whiteboard ────────────────────────────────────────────────────────────
  WhiteboardState _wbState = WhiteboardState.closed;
  WhiteboardData? _wbData;
  int _replayKey = 0;
  String _lastUserQuery = '';

  bool get _isBusy => _isTyping || _streamingText != null;
  bool get _wbVisible => _wbState != WhiteboardState.closed;

  static bool _isMathPhysics(String text) {
    const keywords = [
      // Turkish math/physics
      'türev', 'integral', 'denklem', 'fonksiyon', 'limit', 'geometri',
      'trigonometri', 'karekök', 'matris', 'vektör', 'ispat', 'teorem',
      'kuvvet', 'hız', 'ivme', 'enerji', 'momentum', 'elektrik',
      'manyetik', 'dalga', 'frekans', 'periyot', 'basınç', 'yoğunluk',
      'matematik', 'fizik', 'hesapla', 'çöz', 'koordinat',
      'üçgen', 'açı', 'alan', 'hacim', 'sin', 'cos', 'tan', 'log',
      'çarpım', 'bölüm', 'toplam', 'fark', 'oran', 'orantı',
      'parabol', 'sinüs', 'kosinüs', 'hipotenüs', 'çap', 'yarıçap',
      'newton', 'joule', 'watt', 'ohm', 'volt', 'amper',
      // Visual/whiteboard trigger words
      'çiz', 'çizim', 'grafik', 'tahta', 'şekil', 'diyagram',
      'adım adım', 'görsel', 'göster', 'anlat', 'nasıl çalışır',
      // English
      'derivative', 'integral', 'equation', 'function', 'graph', 'formula',
      'force', 'velocity', 'acceleration', 'energy', 'parabola', 'sine',
      'triangle', 'circle', 'vector', 'matrix', 'coordinate', 'geometry',
      'draw', 'diagram', 'plot', 'calculate', 'solve',
    ];
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
    if (apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
      _anthropic = AnthropicService(apiKey);
    }

    await _storage.init();
    final list = await _storage.listConversations();

    if (list.isNotEmpty) {
      await _loadConversation(list.first.id, updateList: false);
      setState(() { _convList = list; _loading = false; });
    } else {
      _startNewConversation(save: false);
      setState(() { _convList = []; _loading = false; });
    }

    if (_anthropic == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showApiKeyError());
    }
  }

  @override
  void dispose() {
    _anthropic?.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Conversation management ───────────────────────────────────────────────

  void _startNewConversation({bool save = true}) {
    final id = _storage.generateId();
    const welcome = ChatMessage(
      text: 'Bugün ne öğrenmek istiyorsun? ✨\nFotoğraf veya ekran görüntüsü de gönderebilirsin.',
      isUser: false,
    );
    setState(() {
      _currentConvId = id;
      _messages = [welcome];
      _history = [];
      _pendingImage = null;
      _streamingText = null;
      _isTyping = false;
    });
    if (save) { _persistCurrent(); _refreshList(); }
  }

  Future<void> _loadConversation(String id, {bool updateList = true}) async {
    final conv = await _storage.loadConversation(id);
    if (conv == null) return;

    final messages = conv.messages.map((m) => ChatMessage(
          text: m.text, isUser: m.isUser, isError: m.isError, imageBytes: m.imageBytes)).toList();

    final history = <Map<String, dynamic>>[];
    for (final m in conv.messages) {
      if (m.isError) continue;
      if (!m.isUser && m.text.contains('Bugün ne öğrenmek')) continue;
      if (m.isUser && m.imageBytes != null) {
        history.add({'role': 'user', 'content': AnthropicService.buildImageContent(m.imageBytes!, 'image/jpeg', text: m.text)});
      } else {
        history.add({'role': m.isUser ? 'user' : 'assistant', 'content': m.text});
      }
    }

    setState(() {
      _currentConvId = id;
      _messages = messages;
      _history = history;
      _pendingImage = null;
      _streamingText = null;
      _isTyping = false;
    });

    if (updateList) await _refreshList();
    _scrollToBottom();
  }

  Future<void> _deleteCurrentConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu sohbet kalıcı olarak silinecek. Emin misin?',
            style: TextStyle(color: Color(0xFF9CA3AF))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal', style: TextStyle(color: Color(0xFF9CA3AF)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirm != true || _currentConvId == null) return;

    await _storage.deleteConversation(_currentConvId!);
    final list = await _storage.listConversations();
    if (list.isNotEmpty) {
      await _loadConversation(list.first.id, updateList: false);
      setState(() => _convList = list);
    } else {
      setState(() => _convList = []);
      _startNewConversation(save: false);
    }
  }

  Future<void> _refreshList() async {
    final list = await _storage.listConversations();
    if (mounted) setState(() => _convList = list);
  }

  Future<void> _persistCurrent() async {
    if (_currentConvId == null) return;
    final title = _messages.firstWhere((m) => m.isUser,
        orElse: () => const ChatMessage(text: 'Yeni Sohbet', isUser: true)).text;
    final truncated = title.length > 40 ? '${title.substring(0, 40)}…' : title;

    await _storage.saveConversation(StoredConversation(
      id: _currentConvId!,
      title: truncated,
      createdAt: DateTime.fromMillisecondsSinceEpoch(int.parse(_currentConvId!)),
      messages: _messages.map((m) => StoredMessage(
            text: m.text, isUser: m.isUser, isError: m.isError,
            imageBytes: m.imageBytes, timestamp: DateTime.now())).toList(),
    ));
    await _refreshList();
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  void _showApiKeyError() {
    setState(() {
      _messages.add(const ChatMessage(
        text: '⚠️ API anahtarı bulunamadı. Lütfen .env dosyasına geçerli bir ANTHROPIC_API_KEY ekle ve uygulamayı yeniden başlat.',
        isUser: false, isError: true,
      ));
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    final hasImage = _pendingImage != null;
    if ((trimmed.isEmpty && !hasImage) || _isBusy) return;

    final imageBytes = _pendingImage;
    final mime = _pendingMime;

    setState(() {
      _messages.add(ChatMessage(text: trimmed, isUser: true, imageBytes: imageBytes));
      _isTyping = true;
      _streamingText = null;
      _pendingImage = null;
    });
    _inputController.clear();
    _scrollToBottom();

    if (_anthropic == null) {
      setState(() => _isTyping = false);
      return;
    }

    if (imageBytes != null) {
      _history.add({'role': 'user', 'content': AnthropicService.buildImageContent(imageBytes, mime, text: trimmed)});
    } else {
      _history.add({'role': 'user', 'content': trimmed});
    }

    try {
      final stream = _anthropic!.streamMessage(_history);
      final accumulated = StringBuffer();

      await for (final token in stream) {
        if (!mounted) return;
        accumulated.write(token);
        setState(() {
          _isTyping = false;       // hide dots, show streaming bubble
          _streamingText = accumulated.toString();
        });
        _scrollToBottomStreaming();
      }

      final fullReply = accumulated.toString();
      _history.add({'role': 'assistant', 'content': fullReply});

      if (!mounted) return;
      setState(() {
        _streamingText = null;
        _messages.add(ChatMessage(text: fullReply, isUser: false));
      });

      _lastUserQuery = trimmed;
      await _persistCurrent();

      // Auto-trigger whiteboard for math/physics/visual questions
      if (_isMathPhysics(trimmed) && mounted) {
        await _triggerWhiteboard(trimmed, fullReply);
      }

    } on AnthropicException catch (e) {
      if (!mounted) return;
      _history.removeLast();
      setState(() {
        _isTyping = false;
        _streamingText = null;
        _messages.add(ChatMessage(text: '⚠️ ${e.message}', isUser: false, isError: true));
      });
    } catch (_) {
      if (!mounted) return;
      _history.removeLast();
      setState(() {
        _isTyping = false;
        _streamingText = null;
        _messages.add(const ChatMessage(
          text: '⚠️ Bağlantı hatası. İnternetini kontrol edip tekrar dene.',
          isUser: false, isError: true,
        ));
      });
    }

    _scrollToBottom();
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomStreaming() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ── Check student drawing ─────────────────────────────────────────────────

  Future<void> _onCheckDrawing(Uint8List pngBytes) async {
    if (_anthropic == null || _isBusy) return;
    const prompt =
        'Öğrencinin tahtadaki çözümünü kontrol et, hataları Türkçe açıkla.';

    setState(() {
      _messages.add(ChatMessage(
          text: prompt, isUser: true, imageBytes: pngBytes));
      _isTyping = true;
      _streamingText = null;
    });
    _scrollToBottom();

    _history.add({
      'role': 'user',
      'content': AnthropicService.buildImageContent(
          pngBytes, 'image/png',
          text: prompt),
    });

    try {
      final stream = _anthropic!.streamMessage(_history);
      final accumulated = StringBuffer();

      await for (final token in stream) {
        if (!mounted) return;
        accumulated.write(token);
        setState(() {
          _isTyping = false;
          _streamingText = accumulated.toString();
        });
        _scrollToBottomStreaming();
      }

      final fullReply = accumulated.toString();
      _history.add({'role': 'assistant', 'content': fullReply});

      if (!mounted) return;
      setState(() {
        _streamingText = null;
        _messages.add(ChatMessage(text: fullReply, isUser: false));
      });
      await _persistCurrent();
    } on AnthropicException catch (e) {
      if (!mounted) return;
      _history.removeLast();
      setState(() {
        _isTyping = false;
        _streamingText = null;
        _messages.add(ChatMessage(
            text: '⚠️ ${e.message}', isUser: false, isError: true));
      });
    } catch (_) {
      if (!mounted) return;
      _history.removeLast();
      setState(() {
        _isTyping = false;
        _streamingText = null;
        _messages.add(const ChatMessage(
          text: '⚠️ Bağlantı hatası. İnternetini kontrol edip tekrar dene.',
          isUser: false,
          isError: true,
        ));
      });
    }
  }

  // ── Whiteboard ────────────────────────────────────────────────────────────

  Future<void> _triggerWhiteboard(String userQ, String aiReply) async {
    if (!mounted) return;
    debugPrint('[WB] Starting generation for: "$userQ"');
    setState(() => _wbState = WhiteboardState.loading);

    if (_anthropic == null) {
      debugPrint('[WB] No API key — using fallback animation');
      setState(() {
        _wbData = WhiteboardData.defaultAnimation();
        _wbState = WhiteboardState.ready;
        _replayKey++;
      });
      return;
    }

    try {
      final wb = await _anthropic!.generateWhiteboard(userQ, aiReply);
      if (!mounted) return;
      if (wb != null) {
        debugPrint('[WB] Success: ${wb.elements.length} elements, title="${wb.title}"');
        setState(() {
          _wbData = wb;
          _wbState = WhiteboardState.ready;
          _replayKey++;
        });
      } else {
        debugPrint('[WB] Generation returned null — using fallback animation');
        setState(() {
          _wbData = WhiteboardData.defaultAnimation();
          _wbState = WhiteboardState.ready;
          _replayKey++;
        });
      }
    } catch (e) {
      debugPrint('[WB] Error during generation: $e — using fallback animation');
      if (!mounted) return;
      setState(() {
        _wbData = WhiteboardData.defaultAnimation();
        _wbState = WhiteboardState.ready;
        _replayKey++;
      });
    }
  }

  void _onWhiteboardToggle() {
    if (_wbVisible) {
      setState(() => _wbState = WhiteboardState.closed);
      return;
    }
    // Open board — show existing data or empty board (never auto-load default)
    debugPrint('[WB] Manual open — data=${_wbData != null ? "exists" : "empty"}');
    setState(() => _wbState = WhiteboardState.ready);
  }

  void _onClearBoard() {
    debugPrint('[WB] Tahtayı Sil tapped');
    setState(() {
      _wbData = null;
      _replayKey++;
    });
  }

  // ── Image ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
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
      final p = file.path.toLowerCase();
      if (p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.webp')) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pendingImage = Uint8List.fromList(bytes);
          _pendingMime = p.endsWith('.png') ? 'image/png' : 'image/jpeg';
          _isDragging = false;
        });
        return;
      }
    }
    setState(() => _isDragging = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0D0D0D),
        drawer: _buildDrawer(),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: _loading
              ? _buildLoadingState()
              : Row(
                  children: [
                    Expanded(
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOut,
                      width: _wbVisible ? 440 : 0,
                      child: _wbVisible
                          ? ClipRect(
                              child: WhiteboardPanel(
                                key: ValueKey(_replayKey),
                                state: _wbState,
                                data: _wbData,
                                onClose: () => setState(() => _wbState = WhiteboardState.closed),
                                onReplay: () => setState(() => _replayKey++),
                                onClearBoard: _onClearBoard,
                                onCheckDrawing: _onCheckDrawing,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Color(0xFF9CA3AF)),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lise AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _anthropic != null ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _anthropic != null
                  ? (_streamingText != null ? 'Yanıtlanıyor…' : 'Çevrimiçi')
                  : 'API anahtarı eksik',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ]),
        ],
      ),
      actions: [
        // Always-visible Tahta button
        _wbState == WhiteboardState.loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF7C6BF8)),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: _onWhiteboardToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _wbVisible
                          ? const Color(0xFF7C6BF8)
                          : const Color(0xFF7C6BF8).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF7C6BF8).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _wbVisible
                              ? Icons.splitscreen_rounded
                              : Icons.auto_graph_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tahta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        IconButton(
          tooltip: 'Yeni Sohbet',
          icon: const Icon(Icons.edit_outlined, color: Color(0xFF9CA3AF), size: 20),
          onPressed: _isBusy ? null : () => _startNewConversation(),
        ),
        IconButton(
          tooltip: 'Sohbeti Sil',
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9CA3AF), size: 20),
          onPressed: _isBusy ? null : _deleteCurrentConversation,
        ),
      ],
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF111111),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C6BF8), Color(0xFFBB86FC)]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Sohbetler',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Divider(color: Color(0xFF1F1F1F), height: 1),
          Expanded(
            child: _convList.isEmpty
                ? const Center(child: Text('Henüz sohbet yok',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _convList.length,
                    itemBuilder: (ctx, i) {
                      final meta = _convList[i];
                      final isActive = meta.id == _currentConvId;
                      return _DrawerConvItem(
                        meta: meta,
                        isActive: isActive,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!isActive) _loadConversation(meta.id);
                        },
                        onDelete: () async {
                          Navigator.pop(ctx);
                          if (isActive) {
                            await _deleteCurrentConversation();
                          } else {
                            await _storage.deleteConversation(meta.id);
                            await _refreshList();
                          }
                        },
                      );
                    },
                  ),
          ),
          const Divider(color: Color(0xFF1F1F1F), height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () { Navigator.pop(context); _startNewConversation(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Yeni Sohbet',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    final hasStreaming = _streamingText != null;
    final itemCount = _messages.length + (hasStreaming ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        if (hasStreaming && i == _messages.length) {
          return _StreamingBubble(text: _streamingText!);
        }
        final msg = _messages[i];
        // Show "Tahtada anlat" chip below the last AI message when applicable
        final isLastAi = !msg.isUser &&
            !msg.isError &&
            i == _messages.length - 1 &&
            !hasStreaming &&
            _isMathPhysics(_lastUserQuery);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MessageBubble(message: msg),
            if (isLastAi) _buildWhiteboardChip(),
          ],
        );
      },
    );
  }

  Widget _buildWhiteboardChip() {
    return Padding(
      padding: const EdgeInsets.only(left: 46, top: 2, bottom: 6),
      child: GestureDetector(
        onTap: _wbVisible
            ? () => setState(() => _wbState = WhiteboardState.closed)
            : _onWhiteboardToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: _wbVisible
                ? const Color(0xFF1E1A40)
                : const Color(0xFF130C2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7C6BF8).withValues(alpha: _wbVisible ? 0.7 : 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _wbVisible ? Icons.close_rounded : Icons.auto_graph_rounded,
                size: 13,
                color: const Color(0xFF9B8BFB),
              ),
              const SizedBox(width: 5),
              Text(
                _wbVisible ? 'Tahtayı kapat' : 'Tahtada anlat',
                style: const TextStyle(
                  color: Color(0xFF9B8BFB),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────

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
              color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C6BF8))),
          SizedBox(height: 14),
          Text('Sohbet yükleniyor…', style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
        ],
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_pendingImage!, width: 64, height: 64, fit: BoxFit.cover),
            ),
            Positioned(
              top: -6, right: -6,
              child: GestureDetector(
                onTap: () => setState(() => _pendingImage = null),
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(color: Color(0xFF374151), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        const Text('Fotoğraf hazır — mesajını yaz veya gönder.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ]),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

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
            _InputIconButton(icon: Icons.image_outlined, onTap: _isBusy ? () {} : _pickImage),
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                enabled: !_isBusy,
                style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: const InputDecoration(
                  hintText: 'Bir şey sor veya fotoğraf gönder…',
                  hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            _SendOrMicButton(
              controller: _inputController,
              isLoading: _isBusy,
              hasPendingImage: _pendingImage != null,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  // ── Drop overlay ──────────────────────────────────────────────────────────

  Widget _buildDropOverlay() {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF7C6BF8).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF7C6BF8), width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, color: Color(0xFF7C6BF8), size: 48),
            SizedBox(height: 12),
            Text('Fotoğrafı buraya bırak',
                style: TextStyle(color: Color(0xFF7C6BF8), fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Streaming bubble (live typewriter) ────────────────────────────────────────

class _StreamingBubble extends StatelessWidget {
  final String text;

  const _StreamingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AvatarIcon(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (text.isNotEmpty)
                    MathMarkdown(
                      data: text,
                      isStreaming: true,
                      styleSheet: _mdStyle(context),
                    ),
                  const SizedBox(height: 4),
                  const _BlinkingCursor(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blinking cursor ────────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF7C6BF8),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── Drawer conversation item ───────────────────────────────────────────────────

class _DrawerConvItem extends StatelessWidget {
  final ConversationMeta meta;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DrawerConvItem({
    required this.meta, required this.isActive,
    required this.onTap, required this.onDelete,
  });

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    const m = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return '${dt.day} ${m[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E1A3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: const Color(0xFF7C6BF8).withOpacity(0.3)) : null,
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFFD1D5DB),
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    )),
                const SizedBox(height: 2),
                Text(_fmt(meta.createdAt),
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.delete_outline_rounded, size: 16,
                  color: isActive ? const Color(0xFF7C6BF8) : const Color(0xFF4B5563)),
            ),
          ),
        ]),
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
          if (!isUser) ...[_AvatarIcon(), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                gradient: isUser && !hasImage
                    ? const LinearGradient(
                        colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: isUser
                    ? (hasImage ? const Color(0xFF1E1E2E) : null)
                    : isError ? const Color(0xFF2A1A1A) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isError ? Border.all(color: const Color(0xFF7F1D1D), width: 0.5) : null,
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    Image.memory(message.imageBytes!, width: 220, fit: BoxFit.cover),
                  if (hasText)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: isUser || isError
                          ? Text(message.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: isUser ? Colors.white : const Color(0xFFFCA5A5),
                                height: 1.45,
                              ))
                          : MathMarkdown(
                              data: message.text,
                              styleSheet: _mdStyle(context),
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

// ── Avatar ─────────────────────────────────────────────────────────────────────

class _AvatarIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6BF8), Color(0xFFBB86FC)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
    );
  }
}

// ── Typing dots ────────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
      Future.delayed(Duration(milliseconds: i * 160), () { if (mounted) c.repeat(reverse: true); });
      return c;
    });
    _anims = _controllers.map((c) =>
        Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => AnimatedBuilder(
        animation: _anims[i],
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _anims[i].value),
          child: Container(
            width: 7, height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(color: const Color(0xFF7C6BF8), borderRadius: BorderRadius.circular(4)),
          ),
        ),
      )),
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
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: const Color(0xFF6B7280), size: 22),
      ),
    );
  }
}

// ── Send / mic button ──────────────────────────────────────────────────────────

class _SendOrMicButton extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool hasPendingImage;
  final ValueChanged<String> onSend;

  const _SendOrMicButton({
    required this.controller, required this.isLoading,
    required this.hasPendingImage, required this.onSend,
  });

  @override
  State<_SendOrMicButton> createState() => _SendOrMicButtonState();
}

class _SendOrMicButtonState extends State<_SendOrMicButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final v = widget.controller.text.trim().isNotEmpty;
    if (v != _hasText) setState(() => _hasText = v);
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
                width: 38, height: 38,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C6BF8)),
              )
            : _showSend
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: () => widget.onSend(widget.controller.text),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C6BF8), Color(0xFF9B8BFB)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: () {},
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.mic_rounded, color: Color(0xFF9B8BFB), size: 20),
                    ),
                  ),
      ),
    );
  }
}
