// ── VoiceCommand ─────────────────────────────────────────────────────────────

enum VoiceCommand {
  // Interruption commands
  stop,             // "dur", "bekle", "hayır"
  iDontUnderstand, // "anlamadım", "anlayamadım"
  repeat,           // "tekrar", "tekrar söyle", "bir daha"
  slower,           // "yavaş", "yavaşla", "daha yavaş"
  faster,           // "hızlan", "hızlı", "daha hızlı"

  // Mode change commands
  switchToBoard,    // "tahtaya geç", "tahtada göster"
  textOnly,         // "sadece anlat", "yazıyla anlat"
  askQuestion,      // "soru sor", "test et"
  hintMode,         // "ipuçlu çöz", "ipucu ver"
  silentContinue,   // "sessiz devam", "sadece yaz"
  summarize,        // "özet geç", "özetle", "kısalt"

  // Emotional commands
  encourageMe,      // "motivasyon ver", "cesaretlen"
  simpler,          // "daha basit", "basitleştir"
  harder,           // "daha zor", "zorlaştır"
}

extension VoiceCommandExt on VoiceCommand {
  bool get isInterruption => switch (this) {
        VoiceCommand.stop            => true,
        VoiceCommand.iDontUnderstand => true,
        VoiceCommand.repeat          => true,
        VoiceCommand.slower          => true,
        _                            => false,
      };

  String get acknowledgement => switch (this) {
        VoiceCommand.stop            => 'Tamam, duruyorum.',
        VoiceCommand.iDontUnderstand => 'Anlıyorum, tekrar açıklayayım.',
        VoiceCommand.repeat          => 'Tabii, tekrar edeyim.',
        VoiceCommand.slower          => 'Tamam, daha yavaş devam edeyim.',
        VoiceCommand.faster          => 'Tamam, daha hızlı gidelim.',
        VoiceCommand.switchToBoard   => 'Tahtaya geçiyorum.',
        VoiceCommand.textOnly        => 'Tamam, sadece yazıyla devam.',
        VoiceCommand.askQuestion     => 'Sana bir soru sorayım.',
        VoiceCommand.hintMode        => 'İpuçlu moda geçiyorum.',
        VoiceCommand.silentContinue  => 'Sessizce devam ediyorum.',
        VoiceCommand.summarize       => 'Özet geçiyorum.',
        VoiceCommand.encourageMe     => 'Harika gidiyorsun!',
        VoiceCommand.simpler         => 'Daha basit anlatayım.',
        VoiceCommand.harder          => 'Biraz zorluyorum seni.',
      };
}

// ── VoiceCommandDetector ──────────────────────────────────────────────────────
//
// Detects voice commands from STT transcripts.
// Runs BEFORE the message reaches Claude — intercepts mode/pacing changes.

class VoiceCommandDetector {
  // Each entry: list of trigger phrases → command
  static const _rules = <List<String>, VoiceCommand>{
    ['dur', 'hayır dur', 'bekle', 'tamam dur']: VoiceCommand.stop,
    ['anlamadım', 'anlayamadım', 'anlaşılmadı', 'karıştı']: VoiceCommand.iDontUnderstand,
    ['tekrar', 'tekrar söyle', 'tekrar et', 'bir daha', 'yenile']: VoiceCommand.repeat,
    ['yavaş', 'yavaşla', 'daha yavaş', 'ağır ağır']: VoiceCommand.slower,
    ['hızlan', 'hızlı', 'daha hızlı', 'hız']: VoiceCommand.faster,
    ['tahtaya geç', 'tahtada göster', 'tahtaya', 'tahta']: VoiceCommand.switchToBoard,
    ['sadece anlat', 'yazıyla', 'metin olarak', 'sesiz']: VoiceCommand.textOnly,
    ['soru sor', 'test et', 'sınar mısın', 'sor bana']: VoiceCommand.askQuestion,
    ['ipuçlu', 'ipucu ver', 'ipucuyla çöz']: VoiceCommand.hintMode,
    ['sessiz devam', 'sadece yaz', 'yazarak devam']: VoiceCommand.silentContinue,
    ['özet geç', 'özetle', 'kısalt', 'kısa anlat']: VoiceCommand.summarize,
    ['motivasyon', 'cesaretlen', 'teşvik et', 'yapabilir miyim']: VoiceCommand.encourageMe,
    ['daha basit', 'basitleştir', 'kolay anlat', 'sade anlat']: VoiceCommand.simpler,
    ['daha zor', 'zorlaştır', 'ileri seviye', 'challenge']: VoiceCommand.harder,
  };

  /// Returns the detected command, or null if transcript is a regular message.
  static VoiceCommand? detect(String transcript) {
    final lower = transcript.toLowerCase().trim();

    for (final entry in _rules.entries) {
      for (final phrase in entry.key) {
        // Exact match or starts with for short commands
        if (lower == phrase ||
            lower.startsWith('$phrase ') ||
            lower.endsWith(' $phrase') ||
            lower.contains(' $phrase ') ||
            // Short commands (≤4 chars) can be standalone words
            (phrase.length <= 5 && lower.split(' ').contains(phrase))) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// True if the transcript is ONLY a voice command (don't forward to Claude).
  static bool isStandaloneCommand(String transcript) {
    final cmd = detect(transcript);
    if (cmd == null) return false;
    // Only treat as standalone if transcript is short (≤ 5 words)
    final wordCount = transcript.trim().split(' ').length;
    return wordCount <= 5;
  }
}
