import '../models/teacher_identity.dart';
import 'storage_service.dart';

// ── TeacherIdentityService ────────────────────────────────────────────────────
//
// Manages teacher identity: personality selection, persistence, prompt building.
// Future hooks: ElevenLabs voice ID per personality, avatar ID, live camera stream.

class TeacherIdentityService {
  static const _key = 'teacher_identity_v1';

  TeacherIdentity _identity = TeacherIdentity.defaultIdentity;
  TeacherEmotionalState _emotionalState = TeacherEmotionalState.calm;

  TeacherIdentity get identity => _identity;
  TeacherEmotionalState get emotionalState => _emotionalState;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final saved = storage.loadSetting(_key);
    if (saved != null) {
      _identity = TeacherIdentity.fromJsonString(saved);
    }
  }

  Future<void> switchPersonality(
    TeacherPersonalityType type,
    StorageService storage,
  ) async {
    _identity = TeacherIdentity.forPersonality(type);
    await storage.saveSetting(_key, _identity.toJsonString());
  }

  // ── Emotional state engine ─────────────────────────────────────────────────

  /// Compute and update teacher emotional state from student context.
  /// Called after each interaction.
  TeacherEmotionalState computeEmotionalState({
    required int frustrationStreak,       // consecutive frustrated turns
    required double confidenceTrend,      // recent success rate 0–1
    required bool studentIsDistracted,    // short messages, off-topic
    required bool studentIsAnxious,
    required bool isAdvancedStudent,
  }) {
    TeacherEmotionalState newState;

    if (frustrationStreak >= 3) {
      newState = TeacherEmotionalState.encouraging;
    } else if (studentIsAnxious) {
      newState = TeacherEmotionalState.encouraging;
    } else if (studentIsDistracted) {
      newState = TeacherEmotionalState.focused;
    } else if (isAdvancedStudent && confidenceTrend >= 0.75) {
      newState = TeacherEmotionalState.challengeMode;
    } else if (confidenceTrend < 0.35) {
      newState = TeacherEmotionalState.corrective;
    } else if (confidenceTrend >= 0.80) {
      newState = TeacherEmotionalState.excited;
    } else {
      newState = TeacherEmotionalState.calm;
    }

    _emotionalState = newState;
    return newState;
  }

  // ── Prompt building ────────────────────────────────────────────────────────

  /// Full teacher identity + emotional state system prompt block.
  String buildFullPrompt() {
    return _identity.buildIdentityBlock() + _buildEmotionalBlock();
  }

  String _buildEmotionalBlock() {
    final state = _emotionalState;
    return '''

[ÖĞRETMEN DUYGUSAL DURUMU: ${state.label}]
${_emotionalInstruction(state)}
''';
  }

  static String _emotionalInstruction(TeacherEmotionalState state) =>
      switch (state) {
        TeacherEmotionalState.calm => 'Normal tempo. Dengeli, net açıklamalar yap.',
        TeacherEmotionalState.excited =>
            'Enerjik ol! Öğrenci iyi gidiyor — onu daha da ilerlet. '
            '"Harika!" gibi ifadeler kullan.',
        TeacherEmotionalState.focused =>
            'Derin odak modu. Dikkat dağıtma, konuya sadık kal. '
            'Kısa ve öz cümleler.',
        TeacherEmotionalState.encouraging =>
            'Öğrenci zorlanıyor. Çok yumuşak ve sabırlı ol. '
            'Cümleleri kısalt. "Birlikte halledelim" diyerek başla. '
            'Hataları asla vurgulama — alternatif yolu göster.',
        TeacherEmotionalState.corrective =>
            'Hataları açıkça ve nazikçe düzelt. '
            '"Şöyle düşünmek daha doğru olur" gibi ifadeler kullan. '
            'Her düzeltmeden sonra öğrenciyi küçük bir başarıya yönlendir.',
        TeacherEmotionalState.challengeMode =>
            'Öğrenci ileri seviyede — onu zorla! '
            'Daha zor sorular sor, daha az ipucu ver. '
            '"Bunu kendin çözebilirsin" diyerek güven ver.',
      };

  // ── Future hooks ───────────────────────────────────────────────────────────
  // TODO(future): ElevenLabs voice ID per personality
  // String? get elevenLabsVoiceId => null;
  //
  // TODO(future): Avatar model ID for animated face
  // String? get avatarModelId => null;
  //
  // TODO(future): Live camera teacher stream URL
  // String? get liveStreamUrl => null;
}
