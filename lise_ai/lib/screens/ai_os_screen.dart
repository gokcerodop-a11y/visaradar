import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/cognitive_profile.dart';
import '../models/image_context_model.dart';
import '../models/lesson_mode.dart';
import '../models/student_profile.dart';
import '../models/teacher_identity.dart';
import '../services/anthropic_service.dart';
import '../services/board_redraw_service.dart';
import '../services/cognitive_profile_engine.dart';
import '../services/learning_graph_engine.dart';
import '../services/learning_journal_service.dart';
import '../services/lesson_flow_engine.dart';
import '../services/pdf_service.dart';
import '../services/profile_service.dart';
import '../services/realtime_voice_engine.dart';
import '../services/session_continuity_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import '../models/speech_tag.dart';
import '../services/ambient_engine.dart';
import '../services/attention_engine.dart';
import '../services/exam_camp_service.dart';
import '../services/human_pacing_engine.dart';
import '../services/lesson_transition_service.dart';
import '../services/streaming_teacher_session.dart';
import '../services/teacher_engine.dart';
import '../services/teacher_identity_service.dart';
import '../services/teacher_voice_service.dart';
import '../services/ui_state_engine.dart';
import '../services/visual_reasoning_engine.dart';
import '../services/voice_command_detector.dart';
import '../services/work_analysis_service.dart';
import '../services/short_term_memory.dart';
import '../services/working_memory.dart';
import '../services/long_term_memory.dart';
import '../services/episodic_memory.dart';
import '../services/semantic_memory.dart';
import '../services/memory_retrieval_engine.dart';
import '../services/memory_summarizer.dart';
import '../services/memory_prompt_layer.dart';
import 'visual_teaching_screen.dart';
import '../widgets/ambient_layer.dart';
import '../widgets/atmosphere_layer.dart';
import '../widgets/exam_camp_overlay.dart';
import '../widgets/lesson_board_page.dart';
import '../widgets/live_subtitle_engine.dart';
import '../widgets/orb_renderer.dart';
import '../widgets/pdf_page_picker.dart';
import '../widgets/session_recap_card.dart';
import '../widgets/visual_overlay.dart';

// ── AIOperatingSystemScreen ───────────────────────────────────────────────────

class AIOperatingSystemScreen extends StatefulWidget {
  const AIOperatingSystemScreen({super.key});

  @override
  State<AIOperatingSystemScreen> createState() => _AOSState();
}

class _AOSState extends State<AIOperatingSystemScreen>
    with TickerProviderStateMixin {

  // ── Services ──────────────────────────────────────────────────────────────
  final _storage = StorageService();
  late final ProfileService _profileSvc;
  final _teacherEngine = TeacherEngine();
  final _graphEngine = LearningGraphEngine();
  final _cogEngine = CognitiveProfileEngine();
  final _flowEngine = StructuredLessonFlowEngine();
  final _identitySvc = TeacherIdentityService();
  final _continuitySvc = SessionContinuityService();
  final _journalSvc = LearningJournalService();
  final _ambientEngine = AmbientEngine();
  final _attentionEngine = AttentionEngine();
  final _examCampSvc = ExamCampService();
  final _transitionSvc = LessonTransitionService();
  AnthropicService? _anthropic;
  VisualReasoningEngine? _visualEngine;
  BoardRedrawService? _boardRedrawSvc;
  WorkAnalysisService? _workAnalysisSvc;
  MemorySummarizer? _memorySummarizer; // used in _onSessionEnd for async summarization

  // ── Cognitive memory system ────────────────────────────────────────────────
  final _shortTermMem = ShortTermMemory();
  final _workingMem = WorkingMemory();
  final _longTermMem = LongTermMemory();
  final _episodicMem = EpisodicMemory();
  final _semanticMem = SemanticMemory();
  final _memRetrieval = MemoryRetrievalEngine();

  // ── UI state engine ───────────────────────────────────────────────────────
  final _ui = UIStateEngine();

  // ── Student level ─────────────────────────────────────────────────────────
  StudentLevel _level = StudentLevel.sinif9;

  // ── History ───────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _history = [];

  // ── Subtitles ─────────────────────────────────────────────────────────────
  final List<LiveSubtitleItem> _subtitles = [];
  late final LiveSubtitleController _subtitleCtrl;
  String _partialTranscript = '';

  // ── Voice engine (active when in voice mode) ──────────────────────────────
  RealtimeVoiceEngine? _voiceEngine;
  StreamSubscription<RealtimeEvent>? _voiceSub;

  // ── Teacher voice + streaming session (non-voice modes) ───────────────────
  TeacherVoiceService? _voiceSvc;
  StreamingTeacherSession? _activeSession;
  StreamSubscription<TeacherSessionEvent>? _sessionSub;

  // ── STT (for non-voice modes) ─────────────────────────────────────────────
  SpeechService? _speechSvc;
  bool _isListening = false;

  // ── Text streaming ────────────────────────────────────────────────────────
  bool _isStreaming = false;
  final _streamBuf = StringBuffer();

  // ── Input ─────────────────────────────────────────────────────────────────
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  bool _showInput = false;

  // ── PDF / image ───────────────────────────────────────────────────────────
  List<Uint8List> _pendingPdfPages = [];
  String? _pendingPdfName;
  Uint8List? _pendingImage;
  bool _isDragging = false;

  // ── Visual reasoning session state ────────────────────────────────────────
  ImageContext? _imageCtx;
  bool _isAnalyzingImage = false;

  // ── Session recap card ────────────────────────────────────────────────────
  bool _showRecapCard = false;

  // ── Immersive environment state ───────────────────────────────────────────
  bool _focusModeActive = false;
  bool _examCampActive = false;
  Timer? _ambientTick;

  // ── Whiteboard ────────────────────────────────────────────────────────────
  String? _boardQuestion;
  String? _boardReply;
  bool _showBoardBadge = false;

  // ── Init ──────────────────────────────────────────────────────────────────
  bool _loading = true;

  // ── Animation controllers (isolated from logic) ───────────────────────────
  late final AnimationController _breatheCtrl;  // 1.4s slow orb breath
  late final AnimationController _waveCtrl;     // 700ms fast wave
  late final AnimationController _flashCtrl;    // 450ms interrupt flash
  late final AnimationController _particleCtrl; // continuous tick for particles

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat();
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
    _subtitleCtrl = LiveSubtitleController(
      onWordAdvanced: () { if (mounted) setState(() {}); },
    );
    // Ambient engine tick: fades transient effects (success/urgency pulses)
    _ambientTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _ambientEngine.tick();
      if (mounted) setState(() {});
    });
    _initServices();
  }

  Future<void> _initServices() async {
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
    if (apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
      _anthropic = AnthropicService(apiKey);
      _visualEngine = VisualReasoningEngine(_anthropic!);
      _boardRedrawSvc = BoardRedrawService(_anthropic!);
      _workAnalysisSvc = WorkAnalysisService(_anthropic!);
      _memorySummarizer = MemorySummarizer(_anthropic!);
    }

    _voiceSvc = await TeacherVoiceService.create();

    await _storage.init();
    _profileSvc = ProfileService(_storage);
    await _profileSvc.init();
    await _graphEngine.init(_storage);
    await _cogEngine.init(_storage);
    await _flowEngine.init(_storage);
    await _identitySvc.init(_storage);
    await _continuitySvc.init(_storage);
    await _journalSvc.init(_storage);
    await _longTermMem.init(_storage);
    await _episodicMem.init(_storage);
    await _semanticMem.init(_storage);

    // Restore saved mode/level
    final savedMode = _storage.loadSetting('ui_mode');
    final savedLevel = _storage.loadSetting('level');
    if (savedMode != null) {
      final found = UIMode.values.firstWhere((m) => m.name == savedMode,
          orElse: () => UIMode.ogretmen);
      _ui.mode = found;
    }
    if (savedLevel != null) {
      _level = StudentLevel.values.firstWhere((l) => l.name == savedLevel,
          orElse: () => StudentLevel.sinif9);
    }

    // Sync motivation from cognitive profile
    _ui.motivation = _cogEngine.profile.motivationState;

    SpeechService.create().then((svc) {
      if (mounted && svc.isAvailable) {
        setState(() => _speechSvc = svc);
      }
    });

    if (mounted) {
      // Auto-detect atmosphere mode from time + session history
      final autoMode = AmbientEngine.suggestMode(
        now: DateTime.now(),
        isExamSession: false,
        avgConfidence: _continuitySvc.data.avgConfidence,
        frustrationStreak: _continuitySvc.data.frustrationStreak,
      );
      _ambientEngine.setMode(autoMode);

      setState(() => _loading = false);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // Show return greeting or recap card
      final returnGreeting =
          _continuitySvc.getReturnGreeting(_identitySvc.identity);

      if (_continuitySvc.data.hasReturnContent && !mounted) return;

      if (returnGreeting != null) {
        setState(() => _showRecapCard = true);
        _addSubtitle(returnGreeting, isUser: false);
      } else {
        final teacher = _identitySvc.identity;
        _addSubtitle(
          '${teacher.phrases.openingHooks.first}! Bugün ne öğrenmek istiyorsun?',
          isUser: false,
        );
      }

      // Check pending homework
      final hwCheck = _journalSvc.buildHomeworkCheckPrompt(_identitySvc.identity);
      if (hwCheck != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) _addSubtitle(hwCheck, isUser: false);
      }
    }
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _waveCtrl.dispose();
    _flashCtrl.dispose();
    _particleCtrl.dispose();
    _subtitleCtrl.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _anthropic?.dispose();
    _voiceSub?.cancel();
    _voiceEngine?.dispose();
    _sessionSub?.cancel();
    _activeSession?.dispose();
    _voiceSvc?.dispose();
    _speechSvc?.dispose();
    _examCampSvc.dispose();
    _ambientTick?.cancel();
    super.dispose();
  }

  // ── Mode switching ─────────────────────────────────────────────────────────

  Future<void> _setMode(UIMode mode) async {
    if (_ui.mode == mode) return;

    // Deactivate voice engine if leaving voice mode
    if (_ui.mode.isVoiceMode) await _deactivateVoiceEngine();
    // Stop STT if listening
    if (_isListening) await _stopListening();

    setState(() {
      _ui.mode = mode;
      _ui.orbState = OrbVisualState.idle;
      _showInput = false;
    });
    _storage.saveSetting('ui_mode', mode.name);

    // Auto-activate voice engine when switching to voice mode
    if (mode.isVoiceMode && mounted) {
      await _activateVoiceEngine();
    }
  }

  // ── Voice engine lifecycle ─────────────────────────────────────────────────

  Future<void> _activateVoiceEngine() async {
    if (_anthropic == null) return;
    setState(() => _ui.orbState = OrbVisualState.thinking);

    _voiceEngine = await RealtimeVoiceEngine.create(VoiceSessionContext(
      anthropic: _anthropic!,
      profileSvc: _profileSvc,
      cogEngine: _cogEngine,
      flowEngine: _flowEngine,
      graphEngine: _graphEngine,
      mode: _ui.lessonMode,
      level: _level,
      history: List.from(_history),
    ));

    _voiceSub = _voiceEngine!.events.listen(_onVoiceEvent);
    await _voiceEngine!.start();
  }

  Future<void> _deactivateVoiceEngine() async {
    await _voiceSub?.cancel();
    _voiceSub = null;
    final eng = _voiceEngine;
    _voiceEngine = null;
    if (eng != null) {
      // Merge voice history into main history
      for (final turn in eng.history) {
        if (!_history.contains(turn)) _history.add(turn);
      }
      await eng.dispose();
    }
  }

  void _onVoiceEvent(RealtimeEvent event) {
    if (!mounted) return;
    switch (event) {
      case StateChangedEvent(:final state):
        setState(() {
          _ui.orbState = _mapVoiceState(state);
          if (state == ConversationState.interrupted) {
            _flashCtrl.forward(from: 0);
          }
          if (state == ConversationState.thinking &&
              _partialTranscript.isNotEmpty) {
            _addSubtitle(_partialTranscript, isUser: true);
            _partialTranscript = '';
          }
        });

      case TranscriptEvent(:final text, :final isFinal):
        setState(() {
          _partialTranscript = isFinal ? '' : text;
        });

      case AssistantChunkEvent(:final chunk, isNewBubble: _):
        _streamBuf.write(chunk);
        _sentenceFlushToSubtitles();

      case AssistantFinalizedEvent():
        final rem = _streamBuf.toString().trim();
        if (rem.isNotEmpty) _addSubtitle(rem, isUser: false);
        _streamBuf.clear();
        setState(() => _ui.orbState = OrbVisualState.idle);

      case BoardTriggerEvent(:final question, :final reply):
        setState(() {
          _showBoardBadge = true;
          _boardQuestion = question;
          _boardReply = reply;
        });

      case RealtimeErrorEvent(:final message):
        _addSubtitle('⚠️ $message', isUser: false);

      case SessionEndedEvent():
        _deactivateVoiceEngine();
        setState(() => _ui.orbState = OrbVisualState.idle);
    }
  }

  OrbVisualState _mapVoiceState(ConversationState s) => switch (s) {
        ConversationState.idle        => OrbVisualState.idle,
        ConversationState.listening   => OrbVisualState.listening,
        ConversationState.thinking    => OrbVisualState.thinking,
        ConversationState.speaking    => OrbVisualState.speaking,
        ConversationState.interrupted => OrbVisualState.interrupted,
        ConversationState.paused      => OrbVisualState.paused,
      };

  // ── STT (non-voice modes) ──────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    if (_ui.mode.isVoiceMode) return; // voice engine handles its own STT
    final svc = _speechSvc;
    if (svc == null) return;

    if (_isListening) {
      await _stopListening();
      return;
    }

    setState(() {
      _isListening = true;
      _ui.orbState = OrbVisualState.listening;
    });

    await svc.startListening(
      locale: 'tr_TR',
      onResult: (text, isFinal) {
        if (!mounted) return;
        if (isFinal && text.trim().isNotEmpty) {
          final transcript = text.trim();
          _inputCtrl.text = transcript;
          // Intercept voice commands before forwarding to Claude
          final cmd = VoiceCommandDetector.detect(transcript);
          if (cmd != null && VoiceCommandDetector.isStandaloneCommand(transcript)) {
            _stopListening().then((_) => _handleVoiceCommand(cmd));
          } else {
            _stopListening().then((_) => _sendText(transcript));
          }
        } else {
          setState(() => _partialTranscript = text);
        }
      },
      onDone: () {
        if (mounted) setState(() { _isListening = false; _partialTranscript = ''; });
      },
    );
  }

  Future<void> _stopListening() async {
    if (_speechSvc?.isListening == true) await _speechSvc!.stopListening();
    if (mounted) setState(() { _isListening = false; _partialTranscript = ''; });
  }

  // ── Text send ──────────────────────────────────────────────────────────────

  void _onSendTapped() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _pendingPdfPages.isEmpty && _pendingImage == null) return;
    _inputCtrl.clear();
    setState(() => _showInput = false);
    _inputFocus.unfocus();
    _sendText(text);
  }

  Future<void> _sendText(String text) async {
    if (_ui.mode.isVoiceMode) {
      // Inject into voice engine
      _voiceEngine?.sendText(text);
      return;
    }
    if (_anthropic == null || _isStreaming) return;

    // ── Attention engine: record input ─────────────────────────────────────
    _attentionEngine.recordUserInput(text, timestamp: DateTime.now());
    if (_workingMem.wasInterrupted) _workingMem.resume();

    // ── Short-term memory: record user turn ────────────────────────────────
    _shortTermMem.addTurn(ShortTermTurn(
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
      topic: TopicDetector.detect(text),
    ));
    final attentionSig = _attentionEngine.currentSignal;
    if (attentionSig.focusModeRecommended != _focusModeActive) {
      setState(() => _focusModeActive = attentionSig.focusModeRecommended);
    }

    _addSubtitle(text.isNotEmpty ? text : '(Dosya)', isUser: true);

    // Visual reference detection: enrich text when student refers to image
    String effectiveText = text;
    if (_imageCtx != null && _visualEngine != null && text.isNotEmpty) {
      effectiveText = _visualEngine!.buildVisualPrompt(_imageCtx!, text);
      if (effectiveText != text) {
        _imageCtx!.addDiscussion(text);
      }
    }

    // Build history entry
    if (_pendingPdfPages.isNotEmpty) {
      _history.add({
        'role': 'user',
        'content': AnthropicService.buildMultiImageContent(
            _pendingPdfPages, text: effectiveText),
      });
    } else if (_pendingImage != null) {
      final mime = _imageCtx?.mimeType ?? 'image/jpeg';
      _history.add({
        'role': 'user',
        'content': AnthropicService.buildImageContent(
            _pendingImage!, mime, text: effectiveText),
      });
    } else {
      _history.add({'role': 'user', 'content': effectiveText});
    }

    setState(() {
      _pendingPdfPages = [];
      _pendingPdfName = null;
      _pendingImage = null;
    });

    final detectedTopic = TopicDetector.detect(text);
    _teacherEngine.analyze(
      history: _history,
      profile: _profileSvc.profile,
      mode: _ui.lessonMode,
      currentTopic: detectedTopic,
    );

    setState(() {
      _isStreaming = true;
      _streamBuf.clear();
      _ui.orbState = OrbVisualState.thinking;
    });

    // ── StreamingTeacherSession ──────────────────────────────────────────────
    final voice = _voiceSvc ?? await TeacherVoiceService.create();
    final session = StreamingTeacherSession(
      anthropic: _anthropic!,
      voice: voice,
      identity: _identitySvc.identity,
      lessonMode: _ui.lessonMode,
      emotionalSpeedModifier: _identitySvc.emotionalState.animSpeedModifier,
    );
    _activeSession = session;
    _sessionSub = session.events.listen(_onSessionEvent);

    try {
      await session.explain(
        history: _history,
        systemPrompt: _buildSystemPrompt(topic: detectedTopic),
        maxTokens: _ui.lessonMode.maxTokens,
      );
    } catch (_) {
      if (mounted) _addSubtitle('⚠️ Bağlantı hatası.', isUser: false);
    }

    _sessionSub?.cancel();
    _sessionSub = null;
    _activeSession = null;

    if (!mounted) {
      session.dispose();
      return;
    }

    final fullReply = session.fullReply;
    final cleanReply = SpeechTagParser.strip(fullReply);
    if (cleanReply.isNotEmpty) {
      _history.add({'role': 'assistant', 'content': cleanReply});
    }
    session.dispose();

    _teacherEngine.onAssistantResponse(cleanReply);
    final signal = _teacherEngine.lastSignal;

    final topic = detectedTopic ??
        TopicDetector.detect(
            cleanReply.substring(0, cleanReply.length.clamp(0, 400))) ??
        'Genel';

    _profileSvc.recordInteraction(InteractionRecord(
      timestamp: DateTime.now(),
      topic: topic,
      mode: _ui.lessonMode.name,
      usedHints: signal.hasConfusion,
      usedBoard: signal.shouldTriggerBoard ||
          fullReply.contains('[board_sync]'),
      successEstimate: signal.successEstimate,
    ));

    if (topic != 'Genel') {
      _graphEngine.recordStudy(
        topic: topic,
        successEstimate: signal.successEstimate,
        usedHints: signal.hasConfusion,
      );
    }

    await _cogEngine.processInteraction(
      userMessage: text,
      assistantReply: cleanReply,
      usedBoard: signal.shouldTriggerBoard,
      usedHints: signal.hasConfusion,
    );

    await _flowEngine.advance(
      signal: signal,
      topic: detectedTopic,
      mode: _ui.lessonMode,
      level: _level,
      cogProfile: _cogEngine.profile,
      weakTopics: _profileSvc.profile.weakTopics,
      graphEngine: _graphEngine,
    );

    // ── Teacher identity: update emotional state ──────────────────────────
    final cogProfile = _cogEngine.profile;
    _identitySvc.computeEmotionalState(
      frustrationStreak: _continuitySvc.data.frustrationStreak,
      confidenceTrend: _continuitySvc.data.avgConfidence,
      studentIsDistracted: text.trim().split(' ').length < 3,
      studentIsAnxious: cogProfile.motivationState == MotivationState.anxious,
      isAdvancedStudent: _level == StudentLevel.sinif12 ||
          _level == StudentLevel.ayt,
    );

    // ── Session continuity ─────────────────────────────────────────────────
    final isFrustrated =
        cogProfile.motivationState == MotivationState.frustrated;
    await _continuitySvc.recordInteraction(
      topic: topic != 'Genel' ? topic : null,
      successEstimate: signal.successEstimate,
      hadFrustration: isFrustrated,
    );

    if (signal.successEstimate < 0.35 && topic != 'Genel') {
      await _continuitySvc.recordMistake(topic);
    }

    // ── Learning journal ───────────────────────────────────────────────────
    if (topic != 'Genel') {
      await _journalSvc.recordInteraction(
        topic: topic,
        successEstimate: signal.successEstimate,
        usedHints: signal.hasConfusion,
        frustrationStreak: _continuitySvc.data.frustrationStreak,
      );
    }

    // Extract homework marker from AI reply
    final hwItem =
        _continuitySvc.extractHomework(cleanReply, topic);
    if (hwItem != null) {
      await _journalSvc.addHomework(hwItem);
    }

    // ── Atmosphere + attention reactions ──────────────────────────────────
    if (signal.successEstimate >= 0.85) {
      _ambientEngine.triggerSuccessPulse();
    }
    _ambientEngine.reactToEmotionalState(_identitySvc.emotionalState);
    _ambientEngine.reactToTopicDifficulty(1.0 - signal.successEstimate);

    // Exam camp: record answer based on success estimate
    if (_examCampSvc.isActive) {
      _examCampSvc.recordAnswer(correct: signal.successEstimate >= 0.65);
    }

    // Attention-driven break suggestion (inject as subtitle)
    final attnSig = _attentionEngine.currentSignal;
    if (attnSig.shouldSuggestBreak && mounted) {
      final phrase = attnSig.adjustment.teacherPhrase;
      if (phrase != null) _addSubtitle(phrase, isUser: false);
    }

    // Natural lesson transition detection (result used by Claude via prompt context)
    if (cleanReply.isNotEmpty) {
      _transitionSvc.detectTransitionFromReply(cleanReply);
    }

    // ── Cognitive memory recording ─────────────────────────────────────────
    _shortTermMem.addTurn(ShortTermTurn(
      role: 'assistant',
      text: cleanReply.length > 300 ? cleanReply.substring(0, 300) : cleanReply,
      timestamp: DateTime.now(),
      topic: topic != 'Genel' ? topic : null,
    ));
    _shortTermMem.recentEmotionalState = _identitySvc.emotionalState;
    _shortTermMem.currentPacing = _attentionEngine.currentSignal.adjustment;

    // Long-term: update mastery and record mistakes
    if (topic != 'Genel') {
      final mastery = signal.successEstimate >= 0.65
          ? signal.successEstimate * 0.05
          : -0.03;
      await _longTermMem.updateSubjectMastery(topic, mastery);

      if (signal.successEstimate < 0.4 && signal.hasConfusion) {
        await _longTermMem.recordMistake(topic, example: text.length > 80 ? null : text);
      }
    }
    await _longTermMem.recordMotivation(signal.successEstimate);

    // Episodic: record notable moments
    if (signal.successEstimate >= 0.90 && topic != 'Genel') {
      await _episodicMem.recordEpisode(Episode(
        id: 'ep_${DateTime.now().millisecondsSinceEpoch}',
        type: EpisodeType.confidenceBoost,
        title: topic,
        description: 'Başarıyla açıkladı: "${text.length > 60 ? text.substring(0, 60) : text}"',
        topic: topic,
        timestamp: DateTime.now(),
        emotionalValence: 0.8,
      ));
    } else if (signal.hasConfusion && _shortTermMem.currentConfusion != null) {
      await _episodicMem.recordEpisode(Episode(
        id: 'ep_conf_${DateTime.now().millisecondsSinceEpoch}',
        type: EpisodeType.struggle,
        title: topic != 'Genel' ? topic : 'Konu belirsiz',
        description: 'Karışıklık: "${_shortTermMem.currentConfusion}"',
        topic: topic != 'Genel' ? topic : null,
        timestamp: DateTime.now(),
        emotionalValence: -0.4,
      ));
    }

    // Working memory: update active goal if topic shifted
    if (topic != 'Genel' && _workingMem.currentGoal == null) {
      _workingMem.setGoal('$topic konusunu kavramak');
    }
    if (signal.hasConfusion && topic != 'Genel') {
      _workingMem.addUnresolvedConcept(topic);
    } else if (signal.successEstimate >= 0.75 && topic != 'Genel') {
      _workingMem.resolveConcept(topic);
    }

    // Async session summarization every 10 turns (background, non-blocking)
    final summarizer = _memorySummarizer;
    if (summarizer != null && _shortTermMem.recentTurns.length % 10 == 0 &&
        _shortTermMem.recentTurns.length > 0) {
      summarizer.summarizeSession(
        _shortTermMem.recentTurns,
        _longTermMem,
        topic: topic != 'Genel' ? topic : null,
      ).then((summary) {
        if (!mounted) return;
        // Surface unresolved concepts from summary into working memory
        for (final concept in summary.unresolvedConcepts) {
          _workingMem.addUnresolvedConcept(concept);
        }
        for (final concept in summary.resolvedConcepts) {
          _workingMem.resolveConcept(concept);
        }
      });
    }

    // Update motivation-adaptive UI (orb color follows teacher emotional state)
    setState(() {
      _ui.motivation = cogProfile.motivationState;
      _isStreaming = false;
      _ui.orbState = OrbVisualState.idle;
    });

    // Board trigger from signal (board_sync tag handled by session events)
    if (signal.shouldTriggerBoard && mounted) {
      setState(() {
        _showBoardBadge = true;
        _boardQuestion = text;
        _boardReply = cleanReply;
      });
    }
  }

  // ── Session event handler ──────────────────────────────────────────────────

  void _onSessionEvent(TeacherSessionEvent event) {
    if (!mounted) return;
    switch (event) {
      case TeacherStateChanged(:final state):
        setState(() => _ui.orbState = _mapTeacherState(state));

      case SentenceStarted(:final sentence):
        final dur = Duration(
          milliseconds: HumanPacingEngine.fromIdentity(_identitySvc.identity)
              .estimatedDurationMs(sentence.displayText),
        );
        setState(() {
          // Deactivate previous active item
          if (_subtitles.isNotEmpty && _subtitles.first.isActive) {
            _subtitles[0] = _subtitles[0].copyWith(isActive: false);
          }
          _subtitles.insert(
            0,
            LiveSubtitleItem(
              text: sentence.displayText,
              isUser: false,
              tag: sentence.primaryTag,
              isActive: true,
            ),
          );
          if (_subtitles.length > 8) _subtitles.removeLast();
        });
        _subtitleCtrl.startReveal(sentence, dur);

      case SentenceCompleted():
        setState(() {
          if (_subtitles.isNotEmpty) {
            _subtitles[0] = _subtitles[0].copyWith(isActive: false);
          }
        });
        _subtitleCtrl.revealAll();

      case BoardSyncTriggered():
        setState(() => _showBoardBadge = true);
        _workingMem.addReasoningStep('Tahta açıldı — görsel açıklama başladı');

      case SessionInterrupted(:final contextualReply):
        setState(() {
          _isStreaming = false;
          _ui.orbState = OrbVisualState.idle;
        });
        _attentionEngine.recordInterruption();
        _workingMem.markInterrupted();
        _addSubtitle(contextualReply, isUser: false);

      case VoiceCommandApplied(:final command):
        if (command == VoiceCommand.switchToBoard && _showBoardBadge) {
          _openBoard();
        }

      case SessionCompleted():
        break;
    }
  }

  OrbVisualState _mapTeacherState(TeacherLiveState s) => switch (s) {
        TeacherLiveState.idle        => OrbVisualState.idle,
        TeacherLiveState.listening   => OrbVisualState.listening,
        TeacherLiveState.thinking    => OrbVisualState.thinking,
        TeacherLiveState.explaining  => OrbVisualState.speaking,
        TeacherLiveState.drawing     => OrbVisualState.teaching,
        TeacherLiveState.waiting     => OrbVisualState.listening,
        TeacherLiveState.encouraging => OrbVisualState.speaking,
        TeacherLiveState.correcting  => OrbVisualState.speaking,
      };

  void _handleVoiceCommand(VoiceCommand cmd) {
    final session = _activeSession;
    if (session != null) {
      if (cmd.isInterruption) {
        session.interrupt(reason: cmd);
      } else {
        session.applyVoiceCommand(cmd);
      }
    }
    _addSubtitle(cmd.acknowledgement, isUser: false);
  }

  // ── Sentence splitter (voice engine path only) ─────────────────────────────

  static final _sentenceEnd = RegExp(r'(?<=[.!?…])\s+(?=\p{L})', unicode: true);

  void _sentenceFlushToSubtitles() {
    final text = _streamBuf.toString();
    final parts = text.split(_sentenceEnd);
    if (parts.length < 2) return;
    for (int i = 0; i < parts.length - 1; i++) {
      final s = _cleanText(parts[i].trim());
      if (s.isNotEmpty) _addSubtitle(s, isUser: false);
    }
    _streamBuf.clear();
    _streamBuf.write(parts.last);
  }

  String _cleanText(String text) => text
      .replaceAll('[TAHTA]', '')
      .replaceAll('[SORU]', '')
      .replaceAll(RegExp(r'\*+'), '')
      .replaceAll(RegExp(r'#+\s*'), '')
      .trim();

  void _addSubtitle(String text, {required bool isUser}) {
    if (text.isEmpty) return;
    setState(() {
      _subtitles.insert(0, LiveSubtitleItem(text: text, isUser: isUser));
      if (_subtitles.length > 8) _subtitles.removeLast();
    });
  }

  // ── System prompt ──────────────────────────────────────────────────────────

  String _buildSystemPrompt({String? topic}) =>
      AnthropicService.buildSystemPrompt(_ui.lessonMode, _level) +
      _identitySvc.buildFullPrompt() +
      _continuitySvc.buildContinuityPrompt() +
      _journalSvc.buildPrompt() +
      _profileSvc.buildMemorySummary() +
      _teacherEngine.buildOrchestrationPrompt() +
      _graphEngine.buildContextPrompt(
          currentTopic: topic, mode: _ui.lessonMode, level: _level) +
      _cogEngine.buildProfilePrompt() +
      _flowEngine.buildFlowPrompt() +
      StreamingTeacherSession.buildPacingPromptBlock(_identitySvc.identity) +
      SpeechTagParser.systemPromptBlock +
      _transitionSvc.buildContinuityReferenceBlock(
        continuity: _continuitySvc.data,
        journal: _journalSvc.journal,
        teacher: _identitySvc.identity,
      ) +
      _attentionEngine.buildAttentionPromptBlock() +
      _examCampSvc.buildExamCampPromptBlock() +
      MemoryPromptLayer.build(
        shortTerm: _shortTermMem,
        workingMemory: _workingMem,
        longTerm: _longTermMem,
        episodic: _episodicMem,
        semantic: _semanticMem,
        retrieval: _memRetrieval,
        currentTopic: topic ?? _shortTermMem.activeProblem?.substring(0, 30) ?? '',
      ) +
      (_imageCtx?.buildContextBlock() ?? '');

  // ── Whiteboard ────────────────────────────────────────────────────────────

  Future<void> _openBoard() async {
    final q = _boardQuestion;
    final r = _boardReply;
    if (q == null || r == null || _anthropic == null) return;

    final lesson = await _anthropic!.generateLesson(q, r);
    if (!mounted) return;

    if (lesson != null && lesson.steps.isNotEmpty && lesson.elements.isNotEmpty) {
      setState(() => _showBoardBadge = false);
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LessonBoardPage(lesson: lesson),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 480),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tahta hazırlanamadı.'),
            backgroundColor: Color(0xFF2A1A1A)),
      );
    }
  }

  // ── File picking ──────────────────────────────────────────────────────────

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
      _pendingImage = null;
      _showInput = true;
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final mime = _mimeFromPath(result.files.single.path ?? '');
      setState(() {
        _pendingImage = bytes;
        _pendingPdfPages = [];
        _showInput = true;
      });
      await _analyzeImage(bytes, mime);
    }
  }

  void _handleDrop(DropDoneDetails details) async {
    for (final file in details.files) {
      final p = file.path.toLowerCase();
      if (p.endsWith('.jpg') ||
          p.endsWith('.jpeg') ||
          p.endsWith('.png') ||
          p.endsWith('.webp')) {
        final bytes = Uint8List.fromList(await file.readAsBytes());
        final mime = _mimeFromPath(p);
        setState(() {
          _pendingImage = bytes;
          _pendingPdfPages = [];
          _isDragging = false;
          _showInput = true;
        });
        await _analyzeImage(bytes, mime);
        return;
      }
    }
    setState(() => _isDragging = false);
  }

  static String _mimeFromPath(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // ── Visual analysis pipeline ───────────────────────────────────────────────

  Future<void> _analyzeImage(Uint8List bytes, String mime) async {
    if (_visualEngine == null) return;

    setState(() {
      _isAnalyzingImage = true;
      _imageCtx = ImageContext(imageBytes: bytes, mimeType: mime);
    });

    final result = await _visualEngine!.analyzeImage(bytes, mime);

    if (!mounted) return;
    setState(() {
      _isAnalyzingImage = false;
      _imageCtx!.analysisResult = result;
    });

    // Auto-switch mode based on visual content type
    _autoSwitchModeForVisual(result);

    // Announce to student
    final hint = result.topicHint ?? result.subject.name;
    _addSubtitle(
      '${result.modeLabel}: $hint tespit edildi. '
      '"${result.teachingSuggestion ?? "Görseli inceliyorum…"}"',
      isUser: false,
    );
  }

  void _autoSwitchModeForVisual(ImageAnalysisResult result) {
    final newMode = switch (result.suggestedMode) {
      VisualMode.solutionMode  => UIMode.soruCoz,
      VisualMode.teachingMode  => UIMode.ogretmen,
      VisualMode.errorAnalysis => UIMode.ogretmen, // stay in teacher mode, badge shows error
    };
    if (_ui.mode != newMode && !_ui.mode.isVoiceMode) {
      _setMode(newMode);
    }
  }

  // ── Visual board redraw ───────────────────────────────────────────────────

  Future<void> _openVisualBoard() async {
    final ctx = _imageCtx;
    if (ctx == null || _boardRedrawSvc == null) {
      await _openBoard();
      return;
    }

    setState(() => _ui.orbState = OrbVisualState.thinking);
    final lesson = await _boardRedrawSvc!.generateFromImage(ctx);
    if (!mounted) return;
    setState(() => _ui.orbState = OrbVisualState.idle);

    if (lesson != null && lesson.steps.isNotEmpty) {
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LessonBoardPage(lesson: lesson),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 480),
        ),
      );
    } else {
      await _openBoard();
    }
  }

  // ── Visual teaching screen ────────────────────────────────────────────────

  Future<void> _openVisualTeaching() async {
    final ctx = _imageCtx;
    final svc = _workAnalysisSvc;
    if (ctx == null || svc == null) return;

    final teacher = _identitySvc.identity;
    final initialMode = ctx.analysisResult?.suggestedMode == VisualMode.errorAnalysis
        ? VisualTeachingMode.hataAnalizi
        : ctx.analysisResult?.suggestedMode == VisualMode.teachingMode
            ? VisualTeachingMode.ogretim
            : VisualTeachingMode.cozum;

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => VisualTeachingScreen(
          imageCtx: ctx,
          analysisService: svc,
          initialMode: initialMode,
          teacherName: teacher.teacherName,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 480),
      ),
    );
  }

  // ── Orb interaction ───────────────────────────────────────────────────────

  void _onOrbTap() {
    if (_ui.mode.isVoiceMode) {
      if (_ui.orbState == OrbVisualState.speaking) {
        _voiceEngine?.interrupt();
      } else if (_ui.orbState == OrbVisualState.paused) {
        _voiceEngine?.resume();
      } else if (_ui.orbState == OrbVisualState.listening) {
        _voiceEngine?.pause();
      }
    } else {
      if (_isStreaming && _activeSession != null) {
        _activeSession!.interrupt();
      } else if (_isStreaming) {
        setState(() { _isStreaming = false; _ui.orbState = OrbVisualState.idle; });
      } else {
        setState(() => _showInput = !_showInput);
        if (_showInput) _inputFocus.requestFocus();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orbSize = math.min(size.width, size.height) * 0.40;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _loading
            ? _buildLoading()
            : Stack(
                fit: StackFit.expand,
                children: [
                  // ── Layer 0: Ambient background ──────────────────────────
                  AmbientLayer(
                    uiEngine: _ui,
                    particleCtrl: _particleCtrl,
                  ),

                  // ── Layer 0b: Atmosphere glow overlay ────────────────────
                  AtmosphereLayer(
                    engine: _ambientEngine,
                    breatheCtrl: _breatheCtrl,
                    focusMode: _focusModeActive,
                  ),

                  // ── Layer 1: Main UI ─────────────────────────────────────
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Partial transcript (top)
                              if (_partialTranscript.isNotEmpty)
                                Positioned(
                                  top: 20,
                                  left: 20,
                                  right: 20,
                                  child: _buildTranscriptStrip(),
                                ),

                              // Central orb
                              Center(child: _buildOrbArea(orbSize)),

                              // Subtitles (below orb)
                              Positioned(
                                bottom: 10,
                                left: 16,
                                right: 16,
                                child: LiveSubtitleEngine(
                                  items: _subtitles,
                                  activeWordIndex: _subtitleCtrl.wordIndex,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Session recap card
                        if (_showRecapCard)
                          SessionRecapCard(
                            teacher: _identitySvc.identity,
                            teacherState: _identitySvc.emotionalState,
                            continuity: _continuitySvc.data,
                            journal: _journalSvc.journal,
                            onContinue: () {
                              setState(() => _showRecapCard = false);
                              final unfinished =
                                  _continuitySvc.data.unfinishedTopic;
                              if (unfinished != null) {
                                _inputCtrl.text =
                                    '$unfinished konusuna devam edelim';
                                _sendText(_inputCtrl.text);
                                _inputCtrl.clear();
                              }
                            },
                            onDismiss: () =>
                                setState(() => _showRecapCard = false),
                          ),

                        // Visual analyzing indicator
                        if (_isAnalyzingImage)
                          const VisualAnalyzingBadge(),

                        // Visual mode badge (auto-detected from image)
                        if (!_isAnalyzingImage &&
                            _imageCtx?.analysisResult != null)
                          VisualModeBadge(
                            result: _imageCtx!.analysisResult!,
                            onDismiss: () =>
                                setState(() => _imageCtx = null),
                          ),

                        // Exam camp overlay
                        if (_examCampActive)
                          ExamCampOverlay(
                            service: _examCampSvc,
                            onEnd: () => setState(() {
                              _examCampSvc.endSession();
                              _examCampActive = false;
                              _ambientEngine.setMode(AtmosphereMode.focusRoom);
                            }),
                            onCorrect: () =>
                                _examCampSvc.recordAnswer(correct: true),
                            onIncorrect: () =>
                                _examCampSvc.recordAnswer(correct: false),
                          ),

                        // Board badge
                        if (_showBoardBadge) _buildBoardBadge(),

                        // Pending attachments (PDF only — images handled by overlay)
                        if (_pendingPdfPages.isNotEmpty)
                          _buildAttachmentPreview(),

                        // Text input (collapsible)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          child: _showInput ? _buildInputField() : const SizedBox.shrink(),
                        ),

                        // Mode selector
                        _buildModeBar(),
                        _buildBottomBar(),
                      ],
                    ),
                  ),

                  // ── Visual overlay (draggable image thumbnail) ───────────
                  if (_imageCtx != null && _imageCtx!.isVisible)
                    VisualOverlay(
                      ctx: _imageCtx!,
                      onDismiss: () => setState(() {
                        _imageCtx!.isVisible = false;
                      }),
                      onOpenBoard: _openVisualBoard,
                      onOpenAnalysis: _workAnalysisSvc != null
                          ? _openVisualTeaching
                          : null,
                      onCompareModeChanged: (v) => setState(() {
                        _imageCtx!.isCompareMode = v;
                        if (v) {
                          _imageCtx!.aiCorrectedDescription =
                              _imageCtx!.analysisResult?.teachingSuggestion ??
                                  'AI analizi hazırlanıyor…';
                        }
                      }),
                      onSpotlightModeChanged: (v) =>
                          setState(() => _imageCtx!.isSpotlightMode = v),
                      onPositionChanged: (pos) =>
                          _imageCtx!.overlayPosition = pos,
                    ),

                  // ── Drag overlay ─────────────────────────────────────────
                  if (_isDragging)
                    Container(
                      color: const Color(0xFF7C6BF8).withValues(alpha: 0.15),
                      child: const Center(
                        child: Text('Bırak',
                            style: TextStyle(
                                color: Color(0xFF9B8BFB),
                                fontSize: 28,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7C6BF8))),
            SizedBox(height: 12),
            Text('Hazırlanıyor…',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
          ],
        ),
      );

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          // App identity
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _anthropic != null
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF87171),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text('Lise AI',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3)),
            ],
          ),
          const Spacer(),
          // Atmosphere mode badge
          AtmosphereModeBadge(
            mode: _ambientEngine.mode,
            onTap: () async {
              final picked = await AtmospherePicker.show(
                context,
                current: _ambientEngine.mode,
              );
              if (picked != null && mounted) {
                setState(() => _ambientEngine.setMode(picked));
                if (picked == AtmosphereMode.examMode) {
                  _ui.motivation = MotivationState.normal;
                }
              }
            },
          ),
          const SizedBox(width: 8),
          // Teacher mood indicator
          TeacherMoodIndicator(
            teacher: _identitySvc.identity,
            state: _identitySvc.emotionalState,
            onTap: () => PersonalityPickerSheet.show(
              context,
              current: _identitySvc.identity.personalityType,
              onSelected: (type) async {
                await _identitySvc.switchPersonality(type, _storage);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          // Level selector
          _LevelPill(
            level: _level,
            onChanged: (l) {
              setState(() => _level = l);
              _storage.saveSetting('level', l.name);
            },
          ),
        ],
      ),
    );
  }

  // ── Orb area ──────────────────────────────────────────────────────────────

  Widget _buildOrbArea(double size) {
    final orbColor = Color(_ui.orbColorInt);
    return GestureDetector(
      onTap: _onOrbTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breatheCtrl, _waveCtrl, _flashCtrl]),
        builder: (_, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrbRenderer(
                state: _ui.orbState,
                orbColor: orbColor,
                breathe: _breatheCtrl.value,
                wave: _waveCtrl.value,
                flash: _flashCtrl.value,
                amp: _ui.speechAmplitude,
                size: size,
              ),
              const SizedBox(height: 12),
              // State hint
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _orbHint(),
                  key: ValueKey(_ui.orbState),
                  style: TextStyle(
                    color: orbColor.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _orbHint() {
    if (_ui.mode.isVoiceMode) {
      return switch (_ui.orbState) {
        OrbVisualState.speaking    => 'Konuşuyor — dokun → kes',
        OrbVisualState.listening   => 'Dinliyor',
        OrbVisualState.thinking    => 'Düşünüyor…',
        OrbVisualState.interrupted => 'Yeniden başlıyor…',
        OrbVisualState.paused      => 'Duraklatıldı',
        _ => _ui.mode.label,
      };
    }
    if (_isStreaming) return 'Yanıtlanıyor — dokun → durdur';
    return 'Dokun → soru sor';
  }

  // ── Transcript strip ──────────────────────────────────────────────────────

  Widget _buildTranscriptStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Color(0xFF4ADE80), size: 12),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _partialTranscript,
              style:
                  const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Board badge ───────────────────────────────────────────────────────────

  Widget _buildBoardBadge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GestureDetector(
        onTap: _imageCtx != null ? _openVisualBoard : _openBoard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0A28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF7C6BF8).withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _breatheCtrl,
                builder: (_, child) => Opacity(
                  opacity: 0.6 + 0.4 * _breatheCtrl.value,
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
                onTap: () => setState(() => _showBoardBadge = false),
                child: const Icon(Icons.close_rounded,
                    color: Color(0xFF4B5563), size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Attachment preview ────────────────────────────────────────────────────

  Widget _buildAttachmentPreview() {
    final label = '${_pendingPdfName ?? "PDF"} · ${_pendingPdfPages.length} sayfa';
    const icon = Icons.picture_as_pdf_rounded;
    final thumb = _pendingPdfPages.isNotEmpty ? _pendingPdfPages.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          children: [
            if (thumb != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(thumb,
                    width: 36, height: 36, fit: BoxFit.cover),
              )
            else
              Icon(icon, color: const Color(0xFF9CA3AF), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12)),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _pendingPdfPages = [];
                _pendingPdfName = null;
              }),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF4B5563), size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text input ────────────────────────────────────────────────────────────

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFF7C6BF8).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _onSendTapped(),
                decoration: const InputDecoration(
                  hintText: 'Ne sormak istiyorsun?',
                  hintStyle: TextStyle(color: Color(0xFF374151), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            GestureDetector(
              onTap: _onSendTapped,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.send_rounded,
                  color: Color(_ui.orbColorInt),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode bar ──────────────────────────────────────────────────────────────

  Widget _buildModeBar() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: UIMode.values.map((mode) {
          final isActive = _ui.mode == mode;
          final color = isActive
              ? Color(_ui.orbColorInt)
              : const Color(0xFF374151);
          return GestureDetector(
            onTap: () => _setMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? Color(_ui.orbColorInt).withValues(alpha: 0.12)
                    : const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isActive
                        ? Color(_ui.orbColorInt).withValues(alpha: 0.45)
                        : const Color(0xFF1F2937)),
              ),
              child: Center(
                child: Text(
                  mode.shortLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final hasMic = _speechSvc != null || _ui.mode.isVoiceMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic
          if (hasMic)
            _BottomBtn(
              icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              active: _isListening,
              color: _isListening ? const Color(0xFF4ADE80) : null,
              onTap: _toggleMic,
              tooltip: 'Sesli giriş',
            ),
          // Keyboard
          _BottomBtn(
            icon: Icons.keyboard_alt_outlined,
            active: _showInput,
            onTap: () {
              setState(() => _showInput = !_showInput);
              if (_showInput) _inputFocus.requestFocus();
            },
            tooltip: 'Yaz',
          ),
          // PDF
          _BottomBtn(
            icon: Icons.picture_as_pdf_rounded,
            onTap: _pickPdf,
            tooltip: 'PDF',
          ),
          // Image (active when image context loaded)
          _BottomBtn(
            icon: _imageCtx != null
                ? Icons.image_rounded
                : Icons.image_outlined,
            active: _imageCtx != null && _imageCtx!.isVisible,
            color: _imageCtx?.analysisResult?.modeColor,
            onTap: () {
              if (_imageCtx != null) {
                setState(() => _imageCtx!.isVisible = !_imageCtx!.isVisible);
              } else {
                _pickImage();
              }
            },
            tooltip: _imageCtx != null ? 'Görseli gizle/göster' : 'Görsel yükle',
          ),
          // Sınav Kampı
          _BottomBtn(
            icon: Icons.timer_rounded,
            active: _examCampActive,
            color: _examCampActive ? const Color(0xFFF87171) : null,
            onTap: _toggleExamCamp,
            tooltip: 'Sınav Kampı',
          ),
        ],
      ),
    );
  }

  // ── Exam camp toggle ───────────────────────────────────────────────────────

  Future<void> _toggleExamCamp() async {
    if (_examCampActive) {
      setState(() {
        _examCampSvc.endSession();
        _examCampActive = false;
        _ambientEngine.setMode(AtmosphereMode.focusRoom);
      });
      return;
    }

    final currentTopic = _continuitySvc.data.lastTopics.isNotEmpty
        ? _continuitySvc.data.lastTopics.last
        : '';

    final result = await showDialog<({int minutes, String topic})>(
      context: context,
      builder: (_) => ExamCampStartDialog(defaultTopic: currentTopic),
    );

    if (result == null || !mounted) return;

    _examCampSvc.startSession(
      durationMinutes: result.minutes,
      topic: result.topic.isEmpty ? 'Genel' : result.topic,
    );
    setState(() {
      _examCampActive = true;
      _ambientEngine.setMode(AtmosphereMode.examMode);
    });

    _addSubtitle(
      '${_identitySvc.identity.teacherName}: "Sınav kampı başlıyor — ${result.minutes} dakika. Hazır mısın?"',
      isUser: false,
    );
  }
}

// ── Level pill selector ────────────────────────────────────────────────────────

class _LevelPill extends StatelessWidget {
  final StudentLevel level;
  final ValueChanged<StudentLevel> onChanged;

  const _LevelPill({required this.level, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDialog<StudentLevel>(
          context: context,
          builder: (_) => _LevelDialog(current: level),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(level.label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                color: Color(0xFF4B5563), size: 14),
          ],
        ),
      ),
    );
  }
}

class _LevelDialog extends StatelessWidget {
  final StudentLevel current;
  const _LevelDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seviye Seç',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...StudentLevel.values.map((l) => ListTile(
                  title: Text(l.label,
                      style: const TextStyle(color: Colors.white)),
                  selected: l == current,
                  selectedColor: const Color(0xFF9B8BFB),
                  onTap: () => Navigator.pop(context, l),
                  visualDensity: VisualDensity.compact,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Bottom button ─────────────────────────────────────────────────────────────

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final Color? color;

  const _BottomBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? const Color(0xFF7C6BF8) : const Color(0xFF4B5563));
    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A1435) : const Color(0xFF080808),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active
                  ? const Color(0xFF7C6BF8).withValues(alpha: 0.4)
                  : const Color(0xFF1A1A1A)),
        ),
        child: Icon(icon, color: c, size: 19),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
