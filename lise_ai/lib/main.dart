import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/lesson_flow.dart';
import 'models/lesson_mode.dart';
import 'models/student_profile.dart';
import 'services/anthropic_service.dart';
import 'services/cognitive_profile_engine.dart';
import 'services/lesson_flow_engine.dart';
import 'services/pdf_service.dart';
import 'services/learning_graph_engine.dart';
import 'services/profile_service.dart';
import 'services/realtime_voice_engine.dart';
import 'services/speech_service.dart';
import 'services/teacher_engine.dart';
import 'services/storage_service.dart';
import 'screens/ai_os_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/connectivity_service.dart';
import 'services/crash_reporter.dart';
import 'core/supabase_config.dart';
import 'widgets/analytics_panel.dart';
import 'widgets/math_markdown.dart';
import 'widgets/lesson_board_page.dart';
import 'widgets/pdf_page_picker.dart';
import 'widgets/voice_conversation_page.dart';

// Global connectivity service — started once, shared across app.
final connectivityService = ConnectivityService();

Future<void> main() async {
  // Crash safety: ensureInitialized must be in the same zone as runApp.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Install crash reporter hooks
    FlutterError.onError = CrashReporter.instance.handleFlutterError;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    // Initialize Supabase if credentials were supplied at compile time.
    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Start connectivity monitoring (non-blocking)
    connectivityService.start();

    runApp(const LiseAIApp());
  }, (error, stack) {
    debugPrint('[CrashGuard] Unhandled: $error');
    debugPrintStack(stackTrace: stack, maxFrames: 12);
    CrashReporter.instance.handlePlatformError(error, stack);
  });
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
      home: const _AppRouter(),
    );
  }
}

// ── App router: onboarding gate ───────────────────────────────────────────────

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  final _storage = StorageService();
  bool _loading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      await _storage.init();
      final done = _storage.loadSetting('onboarding_done');
      setState(() {
        _needsOnboarding = done != 'true';
        _loading = false;
      });
    } catch (_) {
      setState(() { _needsOnboarding = false; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050510),
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFF7C6BF8),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_needsOnboarding) {
      return OnboardingScreen(
        storage: _storage,
        onComplete: () => setState(() => _needsOnboarding = false),
      );
    }

    return const AIOperatingSystemScreen();
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
  final bool hasBoardLesson;
  final String? lessonQuestion;
  // PDF attachment metadata (pages are not persisted in Hive)
  final String? pdfName;
  final int? pdfPageCount;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.imageBytes,
    this.hasBoardLesson = false,
    this.lessonQuestion,
    this.pdfName,
    this.pdfPageCount,
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
  late final ProfileService _profileSvc;
  final _teacherEngine = TeacherEngine();
  final _graphEngine = LearningGraphEngine();
  final _cogEngine = CognitiveProfileEngine();
  final _flowEngine = StructuredLessonFlowEngine();
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

  bool _loadingLesson = false;

  // ── PDF state ─────────────────────────────────────────────────────────────
  List<Uint8List> _pendingPdfPages = [];
  String? _pendingPdfName;

  // ── Lesson mode & level ────────────────────────────────────────────────────
  LessonMode _mode = LessonMode.ogretmenGibi;
  StudentLevel _level = StudentLevel.sinif9;

  // ── Speech-to-text ────────────────────────────────────────────────────────
  SpeechService? _speechSvc;
  bool _isListening = false;
  String _interimText = '';

  // ── Daily greeting banner ─────────────────────────────────────────────────
  String? _greetingBanner;

  bool get _isBusy => _isTyping || _streamingText != null;

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
    _profileSvc = ProfileService(_storage);
    await _profileSvc.init();
    await _graphEngine.init(_storage);
    await _cogEngine.init(_storage);
    await _flowEngine.init(_storage);

    // Restore saved mode and level
    final savedMode = _storage.loadSetting('mode');
    final savedLevel = _storage.loadSetting('level');
    if (savedMode != null) {
      _mode = LessonMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => LessonMode.ogretmenGibi,
      );
    }
    if (savedLevel != null) {
      _level = StudentLevel.values.firstWhere(
        (l) => l.name == savedLevel,
        orElse: () => StudentLevel.sinif9,
      );
    }

    final list = await _storage.listConversations();

    if (list.isNotEmpty) {
      await _loadConversation(list.first.id, updateList: false);
      setState(() { _convList = list; _loading = false; });
    } else {
      _startNewConversation(save: false);
      setState(() { _convList = []; _loading = false; });
    }

    // Show daily greeting if applicable
    final greeting = _profileSvc.getDailyGreeting();
    if (greeting != null && mounted) {
      setState(() => _greetingBanner = greeting);
    }

    if (_anthropic == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showApiKeyError());
    }

    // Init speech recognition (non-blocking)
    SpeechService.create().then((svc) {
      if (mounted && svc.isAvailable) {
        setState(() => _speechSvc = svc);
      }
    });
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
    _teacherEngine.reset();
    _flowEngine.reset();
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

    _teacherEngine.reset();
    _flowEngine.reset();
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
    final hasPdf = _pendingPdfPages.isNotEmpty;
    final hasImage = _pendingImage != null;
    if ((trimmed.isEmpty && !hasImage && !hasPdf) || _isBusy) return;

    final imageBytes = _pendingImage;
    final mime = _pendingMime;
    final pdfPages = List<Uint8List>.from(_pendingPdfPages);
    final pdfName = _pendingPdfName;
    _inputController.clear();

    if (hasPdf) {
      await _normalSend(trimmed, pdfPages: pdfPages, pdfName: pdfName);
    } else {
      await _normalSend(trimmed, imageBytes: imageBytes, mime: mime);
    }
  }

  /// Normal streaming flow for all messages.
  Future<void> _normalSend(
    String trimmed, {
    Uint8List? imageBytes,
    String mime = 'image/jpeg',
    List<Uint8List>? pdfPages,
    String? pdfName,
  }) async {
    setState(() {
      _messages.add(ChatMessage(
        text: trimmed,
        isUser: true,
        imageBytes: pdfPages != null && pdfPages.isNotEmpty
            ? pdfPages.first // show first page as bubble thumbnail
            : imageBytes,
        pdfName: pdfName,
        pdfPageCount: pdfPages?.length,
      ));
      _isTyping = true;
      _streamingText = null;
      _pendingImage = null;
      _pendingPdfPages = [];
      _pendingPdfName = null;
    });
    _scrollToBottom();

    if (_anthropic == null) {
      setState(() => _isTyping = false);
      return;
    }

    if (pdfPages != null && pdfPages.isNotEmpty) {
      _history.add({
        'role': 'user',
        'content': AnthropicService.buildMultiImageContent(pdfPages, text: trimmed),
      });
    } else if (imageBytes != null) {
      _history.add({
        'role': 'user',
        'content': AnthropicService.buildImageContent(imageBytes, mime, text: trimmed),
      });
    } else {
      _history.add({'role': 'user', 'content': trimmed});
    }

    // ── Teacher engine analysis (before sending) ───────────────────────────
    final detectedTopic = TopicDetector.detect(trimmed);
    _teacherEngine.analyze(
      history: _history,
      profile: _profileSvc.profile,
      mode: _mode,
      currentTopic: detectedTopic,
    );

    try {
      final accumulated = StringBuffer();
      await for (final token in _anthropic!.streamMessage(
        _history,
        systemPrompt: _buildSystemPrompt(topic: detectedTopic),
        maxTokens: _mode.maxTokens,
      )) {
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

      // Notify engine of response
      _teacherEngine.onAssistantResponse(fullReply);
      final signal = _teacherEngine.lastSignal;

      // Record interaction for student memory with engine-derived estimates
      final topic = detectedTopic ??
          TopicDetector.detect(fullReply.substring(0, fullReply.length.clamp(0, 400))) ??
          'Genel';
      _profileSvc.recordInteraction(InteractionRecord(
        timestamp: DateTime.now(),
        topic: topic,
        mode: _mode.name,
        usedHints: _mode == LessonMode.sadaceIpucu || signal.hasConfusion,
        usedBoard: _mode == LessonMode.tahtadaCoz ||
            _mode == LessonMode.sesliDers ||
            signal.shouldTriggerBoard,
        successEstimate: signal.successEstimate,
      ));

      // Update learning graph mastery
      if (topic != 'Genel') {
        _graphEngine.recordStudy(
          topic: topic,
          successEstimate: signal.successEstimate,
          usedHints: _mode == LessonMode.sadaceIpucu || signal.hasConfusion,
        );
      }

      // Update cognitive profile
      final usedHints = _mode == LessonMode.sadaceIpucu || signal.hasConfusion;
      final usedBoard = _mode == LessonMode.tahtadaCoz ||
          _mode == LessonMode.sesliDers ||
          signal.shouldTriggerBoard;
      await _cogEngine.processInteraction(
        userMessage: trimmed,
        assistantReply: fullReply,
        usedBoard: usedBoard,
        usedHints: usedHints,
      );

      // Advance structured lesson flow
      await _flowEngine.advance(
        signal: signal,
        topic: detectedTopic,
        mode: _mode,
        level: _level,
        cogProfile: _cogEngine.profile,
        weakTopics: _profileSvc.profile.weakTopics,
        graphEngine: _graphEngine,
      );
      if (mounted) setState(() {}); // refresh phase strip

      if (!mounted) return;
      final alwaysBoard = _mode.alwaysShowBoard;
      final isMathy = alwaysBoard ||
          signal.shouldTriggerBoard ||
          ((_isMathPhysics(trimmed) ||
                  (pdfPages != null && pdfPages.isNotEmpty) ||
                  _isMathPhysics(
                      fullReply.substring(0, fullReply.length.clamp(0, 300)))) &&
              imageBytes == null);
      setState(() {
        _streamingText = null;
        _messages.add(ChatMessage(
          text: fullReply,
          isUser: false,
          hasBoardLesson: isMathy,
          lessonQuestion: isMathy ? trimmed : null,
        ));
      });
      await _persistCurrent();
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

  // ── Mode & level ──────────────────────────────────────────────────────────

  void _setMode(LessonMode mode) {
    setState(() => _mode = mode);
    _storage.saveSetting('mode', mode.name);
  }

  void _setLevel(StudentLevel level) {
    setState(() => _level = level);
    _storage.saveSetting('level', level.name);
  }

  String _buildSystemPrompt({String? topic}) =>
      AnthropicService.buildSystemPrompt(_mode, _level) +
      _profileSvc.buildMemorySummary() +
      _teacherEngine.buildOrchestrationPrompt() +
      _graphEngine.buildContextPrompt(
          currentTopic: topic, mode: _mode, level: _level) +
      _cogEngine.buildProfilePrompt() +
      _flowEngine.buildFlowPrompt();

  String get _currentSystemPrompt => _buildSystemPrompt();

  // ── Live lesson (Realtime Voice) ──────────────────────────────────────────

  Future<void> _startLiveLesson() async {
    if (_anthropic == null || _isBusy) return;
    final sessionHistory = await pushVoiceConversation(
      context,
      ctx: VoiceSessionContext(
        anthropic: _anthropic!,
        profileSvc: _profileSvc,
        cogEngine: _cogEngine,
        flowEngine: _flowEngine,
        graphEngine: _graphEngine,
        mode: _mode,
        level: _level,
        history: List.from(_history),
      ),
    );
    // Merge session turns back into main history
    if (sessionHistory != null && sessionHistory.isNotEmpty && mounted) {
      setState(() => _history = sessionHistory);
    }
  }

  // ── Mic / STT ─────────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    final svc = _speechSvc;
    if (svc == null) return;

    if (_isListening) {
      await svc.stopListening();
      if (mounted) setState(() { _isListening = false; _interimText = ''; });
      return;
    }

    final started = await svc.startListening(
      locale: 'tr_TR',
      onResult: (text, isFinal) {
        if (!mounted) return;
        // Place recognized text into input field (user can edit after)
        _inputController.text = text;
        _inputController.selection =
            TextSelection.fromPosition(TextPosition(offset: text.length));
        setState(() => _interimText = isFinal ? '' : text);
        if (isFinal) setState(() => _isListening = false);
      },
      onDone: () {
        if (mounted) setState(() { _isListening = false; _interimText = ''; });
      },
    );

    if (started && mounted) setState(() => _isListening = true);
  }

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
      final stream = _anthropic!.streamMessage(
        _history,
        systemPrompt: _currentSystemPrompt,
        maxTokens: _mode.maxTokens,
      );
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

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    final pdf = await PdfService.fromBytes(file.bytes!, file.name);
    if (pdf == null || !mounted) return;

    final pages = await showPdfPagePicker(context, pdf);
    await pdf.close();

    if (pages == null || pages.isEmpty || !mounted) return;
    setState(() {
      _pendingPdfPages = pages;
      _pendingPdfName = file.name;
      _pendingImage = null; // clear any pending image
    });
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
              : Stack(
                  children: [
                    Column(
                      children: [
                        if (_greetingBanner != null) _buildGreetingBanner(),
                        if (_flowEngine.isActive) _buildPhaseStrip(),
                        Expanded(child: _buildMessageList()),
                        if (_isTyping) _buildTypingIndicator(),
                        if (_pendingImage != null) _buildImagePreview(),
                        if (_pendingPdfPages.isNotEmpty) _buildPdfPreview(),
                        _buildSelectorBar(),
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
        IconButton(
          tooltip: 'Canlı Ders Başlat',
          icon: const Icon(Icons.record_voice_over_rounded,
              color: Color(0xFF4ADE80), size: 20),
          onPressed: (_isBusy || _anthropic == null) ? null : _startLiveLesson,
        ),
        IconButton(
          tooltip: 'İlerleme',
          icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFF9CA3AF), size: 20),
          onPressed: () => showAnalyticsPanel(context, _profileSvc, _graphEngine, _cogEngine, _level),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MessageBubble(message: msg),
            if (!msg.isUser && msg.hasBoardLesson && _anthropic != null)
              _buildBoardButton(msg),
          ],
        );
      },
    );
  }

  Widget _buildBoardButton(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(left: 46, top: 4, bottom: 6),
      child: GestureDetector(
        onTap: _loadingLesson
            ? null
            : () async {
                setState(() => _loadingLesson = true);
                try {
                  final lesson = await _anthropic!
                      .generateLesson(msg.lessonQuestion!, msg.text);
                  if (!mounted) return;
                  if (lesson != null &&
                      lesson.steps.isNotEmpty &&
                      lesson.elements.isNotEmpty) {
                    await pushLessonBoard(context, lesson,
                        onCheckDrawing: _onCheckDrawing);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ders hazırlanamadı. Tekrar dene.'),
                          backgroundColor: Color(0xFF2A1A1A),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: const Color(0xFF2A1A1A),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _loadingLesson = false);
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF130C2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7C6BF8).withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loadingLesson)
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Color(0xFF9B8BFB)),
                )
              else
                Icon(
                _mode == LessonMode.sesliDers
                    ? Icons.record_voice_over_rounded
                    : Icons.auto_graph_rounded,
                size: 13,
                color: const Color(0xFF9B8BFB),
              ),
              const SizedBox(width: 5),
              Text(
                _loadingLesson
                    ? 'Ders hazırlanıyor…'
                    : _mode == LessonMode.sesliDers
                        ? 'Sesli Dersi Başlat'
                        : 'Tahtada Anlat',
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

  // ── Phase strip ───────────────────────────────────────────────────────────

  Widget _buildPhaseStrip() {
    final phases = StructuredPhase.values;
    final currentIdx = _flowEngine.currentPhase.index;
    final topic = _flowEngine.currentTopic;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1F2937), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Phase dots
          ...phases.map((phase) {
            final idx = phase.index;
            final isCurrent = idx == currentIdx;
            final isPast = idx < currentIdx;
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 44 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF7C6BF8)
                      : isPast
                          ? const Color(0xFF374151)
                          : const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: isCurrent
                    ? null
                    : null,
              ),
            );
          }),
          const SizedBox(width: 8),
          // Phase label
          Text(
            _flowEngine.currentPhase.label,
            style: const TextStyle(
              color: Color(0xFF7C6BFB),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (topic != null) ...[
            const Text(' · ', style: TextStyle(color: Color(0xFF374151), fontSize: 11)),
            Flexible(
              child: Text(
                topic,
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Greeting banner ───────────────────────────────────────────────────────

  Widget _buildGreetingBanner() {
    return GestureDetector(
      onTap: () => setState(() => _greetingBanner = null),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1435), Color(0xFF0D1020)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(bottom: BorderSide(color: Color(0xFF2A2040), width: 0.5)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                _greetingBanner!,
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.close_rounded, color: Color(0xFF4B5563), size: 16),
          ],
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

  Widget _buildPdfPreview() {
    final name = _pendingPdfName ?? 'document.pdf';
    final count = _pendingPdfPages.length;
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          // First page thumbnail
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _pendingPdfPages.first,
                  width: 48,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              // Page count badge
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              // Remove button
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _pendingPdfPages = [];
                    _pendingPdfName = null;
                  }),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: Color(0xFF374151), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count sayfa seçildi — mesaj yaz veya gönder',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode / level selector bar ─────────────────────────────────────────────

  Widget _buildSelectorBar() {
    return Container(
      color: const Color(0xFF080808),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: StudentLevel.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final l = StudentLevel.values[i];
                final sel = _level == l;
                return GestureDetector(
                  onTap: () => _setLevel(l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1E2A1E)
                          : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    child: Text(
                      l.label,
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Mode chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: LessonMode.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final m = LessonMode.values[i];
                final sel = _mode == m;
                return GestureDetector(
                  onTap: () => _setMode(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1A1435)
                          : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF7C6BF8)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m.icon,
                          size: 12,
                          color: sel
                              ? const Color(0xFF9B8BFB)
                              : const Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          m.shortLabel,
                          style: TextStyle(
                            color: sel
                                ? const Color(0xFF9B8BFB)
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Listening indicator strip
          if (_isListening)
            _ListeningBar(interim: _interimText),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isListening
                    ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _InputIconButton(
                    icon: Icons.image_outlined,
                    onTap: _isBusy ? () {} : _pickImage),
                _InputIconButton(
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: _isBusy ? () {} : _pickPdf),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    enabled: !_isBusy,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white, height: 1.4),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Sizi dinliyorum…'
                          : 'Bir şey sor veya fotoğraf gönder…',
                      hintStyle: TextStyle(
                        color: _isListening
                            ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                            : const Color(0xFF4B5563),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
                _SendOrMicButton(
                  controller: _inputController,
                  isLoading: _isBusy,
                  hasPendingImage: _pendingImage != null || _pendingPdfPages.isNotEmpty,
                  onSend: _sendMessage,
                  isListening: _isListening,
                  onMicTap: _speechSvc != null ? _toggleMic : null,
                ),
              ],
            ),
          ),
        ],
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
    final hasPdf = message.pdfPageCount != null;
    final hasImage = message.imageBytes != null && !hasPdf; // don't show raw page if PDF label shown
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
                  if (hasPdf)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${message.pdfName ?? 'PDF'} • ${message.pdfPageCount} sayfa',
                              style: const TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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
  final bool isListening;
  final VoidCallback? onMicTap;

  const _SendOrMicButton({
    required this.controller,
    required this.isLoading,
    required this.hasPendingImage,
    required this.onSend,
    this.isListening = false,
    this.onMicTap,
  });

  @override
  State<_SendOrMicButton> createState() => _SendOrMicButtonState();
}

class _SendOrMicButtonState extends State<_SendOrMicButton>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final v = widget.controller.text.trim().isNotEmpty;
    if (v != _hasText) setState(() => _hasText = v);
  }

  bool get _showSend =>
      (_hasText || widget.hasPendingImage) && !widget.isListening;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: widget.isLoading
            ? Container(
                key: const ValueKey('loading'),
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12)),
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7C6BF8)),
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
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: widget.onMicTap,
                    child: widget.isListening
                        ? AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Color.lerp(const Color(0xFF2A1010),
                                    const Color(0xFF4A1515), _pulseAnim.value),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color.lerp(
                                      const Color(0xFFEF4444),
                                      const Color(0xFFFF6B6B),
                                      _pulseAnim.value)!,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(Icons.stop_rounded,
                                  color: Color(0xFFEF4444), size: 18),
                            ),
                          )
                        : Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: widget.onMicTap != null
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.mic_rounded,
                                color: widget.onMicTap != null
                                    ? const Color(0xFF9B8BFB)
                                    : const Color(0xFF3A3A3A),
                                size: 20),
                          ),
                  ),
      ),
    );
  }
}

// ── Listening bar (shown above input while mic is active) ─────────────────────

class _ListeningBar extends StatefulWidget {
  final String interim;
  const _ListeningBar({this.interim = ''});

  @override
  State<_ListeningBar> createState() => _ListeningBarState();
}

class _ListeningBarState extends State<_ListeningBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 6),
      child: Row(
        children: [
          // Animated wave bars
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                children: List.generate(4, (i) {
                  final phase = ((_ctrl.value + i * 0.25) % 1.0);
                  final h = 4.0 + 10.0 * math.sin(phase * 2 * math.pi).abs();
                  return Container(
                    width: 3,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 10),
          const Text(
            'Dinleniyor…',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.interim.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.interim,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
