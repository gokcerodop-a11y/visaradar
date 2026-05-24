import '../models/cognitive_profile.dart';
import '../services/storage_service.dart';

// ── CognitiveProfileEngine ────────────────────────────────────────────────────
//
// Detects learning style, motivation, and error patterns from conversations.
// Persists to Hive via StorageService and injects summary into Claude prompts.

class CognitiveProfileEngine {
  static const _key = 'cognitive_profile_v1';

  CognitiveProfile _profile = CognitiveProfile();
  StorageService? _storage;

  CognitiveProfile get profile => _profile;

  // ── Init / persist ─────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    _storage = storage;
    final raw = storage.loadSetting(_key);
    if (raw != null) {
      try {
        _profile = CognitiveProfile.fromJsonString(raw);
      } catch (_) {
        _profile = CognitiveProfile();
      }
    }
  }

  Future<void> _save() async {
    await _storage?.saveSetting(_key, _profile.toJsonString());
  }

  // ── Detection keywords ─────────────────────────────────────────────────────

  static const _styleKeywords = <String, List<String>>{
    'exampleBased': [
      'örnek ver', 'örnek göster', 'somut örnek', 'mesela', 'for example',
      'örneğin', 'gibi bir şey', 'örnek yap',
    ],
    'conceptual': [
      'mantığını anlat', 'neden', 'nasıl çalışır', 'niye', 'sebebi ne',
      'arkasındaki mantık', 'temel kavram', 'özünü anlat',
    ],
    'fastAnswer': [
      'kısaca', 'özet', 'kısa anlat', 'hızlıca', 'sadece sonucu',
      'direkt söyle', 'hızlı', 'brief', 'tldr',
    ],
    'stepByStep': [
      'adım adım', 'adımlarla', 'sırayla', 'basamak basamak',
      'step by step', 'tek tek açıkla', 'her adımı göster',
    ],
  };

  static const _frustrationKeywords = [
    'yapamıyorum', 'anlayamıyorum', 'çok zor', 'zor geliyor',
    'kafam karıştı', 'hiç anlamadım', 'anlamıyorum', 'olmadı',
    'beceremiyorum', 'çok karmaşık', 'imkansız', 'saçma geldi',
    'yoruldum', 'sıkıştım', 'takıldım', 'neden bu kadar zor',
  ];

  static const _confidenceKeywords = [
    'anladım', 'tamam anladım', 'kolaymış', 'kavradım', 'mantıklı',
    'artık anlıyorum', 'çok kolay', 'bunu biliyorum', 'hallettim',
    'çözdüm', 'başardım', 'teşekkürler anladım',
  ];

  static const _anxietyKeywords = [
    'sınav', 'endişe', 'kaygı', 'stres', 'korkuyorum', 'sınavım var',
    'yetiştiremeyeceğim', 'geçemeyeceğim', 'not düşecek', 'başaramayacağım',
    'panik', 'tyt', 'ayt', 'lgs', 'büyük sınav',
  ];

  static const _boredKeywords = [
    'sıkıldım', 'çok uzun', 'çok sıkıcı', 'kısa tut', 'özetle',
    'geç', 'hadi', 'bıkalım', 'daha farklı anlat', 'ilgimi çekmiyor',
  ];

  // Error type detection based on message context
  static const _errorKeywords = <String, List<String>>{
    'islem': [
      'hesap', 'işlem', 'toplama', 'çarpma', 'bölme', 'çıkarma',
      'sonuç yanlış', 'nerede hata yaptım', 'hesaplamada',
    ],
    'kavram': [
      'ne demek', 'kavram', 'tanım', 'nedir bu', 'anlamı ne',
      'terim', 'bilmiyordum', 'farkı ne', 'ne fark var',
    ],
    'dikkat': [
      'dikkat etmemişim', 'atlamışım', 'gözden kaçırdım', 'yanlış okudum',
      'işaret unutmuşum', 'eksi unutmuşum',
    ],
    'formul': [
      'formül', 'formülü yanlış', 'hangi formül', 'formülü bilemedim',
      'denklemi', 'kuralı bilemedim',
    ],
    'okuma': [
      'yanlış anladım', 'soru yanlış anladım', 'farklı anladım',
      'okumamışım', 'atlamışım', 'soruyu okumadan',
    ],
  };

  // ── Main processing ────────────────────────────────────────────────────────

  /// Call after every user message + assistant response pair.
  Future<void> processInteraction({
    required String userMessage,
    required String assistantReply,
    required bool usedBoard,
    required bool usedHints,
  }) async {
    final signals = <String>[];
    final lower = userMessage.toLowerCase();

    // ── Learning style detection ─────────────────────────────────────────────
    for (final entry in _styleKeywords.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        _profile.addStyleVote(entry.key);
        signals.add('style:${entry.key}');
      }
    }

    // Board usage is a strong visual signal
    if (usedBoard) {
      _profile.addStyleVote('visual');
      signals.add('style:visual');
    }

    // ── Motivation detection ─────────────────────────────────────────────────
    if (_frustrationKeywords.any((kw) => lower.contains(kw))) {
      _profile.motivationState = MotivationState.frustrated;
      signals.add('motivation:frustrated');
      // Struggling also increases attention estimate downward
      if (_profile.attentionSpanEstimate > 1) {
        _profile.attentionSpanEstimate--;
      }
    } else if (_boredKeywords.any((kw) => lower.contains(kw))) {
      _profile.motivationState = MotivationState.bored;
      signals.add('motivation:bored');
    } else if (_anxietyKeywords.any((kw) => lower.contains(kw))) {
      _profile.motivationState = MotivationState.anxious;
      signals.add('motivation:anxious');
    } else if (_confidenceKeywords.any((kw) => lower.contains(kw))) {
      _profile.motivationState = MotivationState.confident;
      signals.add('motivation:confident');
      // Comprehension — nudge attention up
      if (_profile.attentionSpanEstimate < 10) {
        _profile.attentionSpanEstimate++;
      }
    }

    // ── Error type detection ─────────────────────────────────────────────────
    // Only scan when hint was used (sign of struggle)
    if (usedHints) {
      final fullText = '$userMessage $assistantReply'.toLowerCase();
      for (final entry in _errorKeywords.entries) {
        if (entry.value.any((kw) => fullText.contains(kw))) {
          final errorType = ErrorType.values.firstWhere(
            (e) => e.name == entry.key,
            orElse: () => ErrorType.kavram,
          );
          _profile.errorTypeCounts[errorType] =
              (_profile.errorTypeCounts[errorType] ?? 0) + 1;
          signals.add('error:${entry.key}');
        }
      }
    }

    // ── Preferred explanation length ─────────────────────────────────────────
    if (_styleKeywords['fastAnswer']!.any((kw) => lower.contains(kw))) {
      _profile.preferredExplanationLength = 1;
    } else if (_styleKeywords['stepByStep']!.any((kw) => lower.contains(kw))) {
      _profile.preferredExplanationLength = 3;
    }

    // ── Preferred tone ───────────────────────────────────────────────────────
    if (_profile.motivationState == MotivationState.frustrated ||
        _profile.motivationState == MotivationState.anxious) {
      _profile.preferredTeacherTone = 'encouraging';
    } else if (_profile.motivationState == MotivationState.bored) {
      _profile.preferredTeacherTone = 'engaging';
    } else if (_profile.motivationState == MotivationState.confident) {
      _profile.preferredTeacherTone = 'direct';
    }

    // ── Signals log (last 8) ─────────────────────────────────────────────────
    _profile.lastDetectedSignals = [
      ...signals,
      ..._profile.lastDetectedSignals,
    ].take(8).toList();

    await _save();
  }

  // ── Prompt injection ───────────────────────────────────────────────────────

  /// Returns a Turkish instruction block for the Claude system prompt.
  String buildProfilePrompt() {
    final buf = StringBuffer();
    final p = _profile;

    final hasStyle = p.learningStyle != LearningStyle.unknown;
    final hasMood = p.motivationState != MotivationState.normal;
    final hasErrors = p.topErrors.isNotEmpty;

    if (!hasStyle && !hasMood && !hasErrors) return '';

    buf.writeln('\n--- BİLİŞSEL PROFİL ---');

    if (hasStyle) {
      buf.writeln('Öğrenim tarzı: ${p.learningStyle.label}');
      buf.writeln(p.learningStyle.promptInstruction);
    }

    if (hasMood) {
      buf.writeln('Motivasyon: ${p.motivationState.label}');
      buf.writeln(p.motivationState.promptInstruction);
    }

    if (hasErrors) {
      final errLabels = p.topErrors.map((e) => e.label).join(', ');
      buf.writeln('Sık yapılan hata tipleri: $errLabels — bu alanlara özellikle dikkat et.');
    }

    if (p.preferredExplanationLength == 1) {
      buf.writeln('Yanıtları kısa ve öz tut.');
    } else if (p.preferredExplanationLength == 3) {
      buf.writeln('Adım adım, ayrıntılı açıkla.');
    }

    buf.writeln('--- BİLİŞSEL PROFİL SONU ---');
    return buf.toString();
  }

  void reset() {
    _profile = CognitiveProfile();
    _save();
  }
}
