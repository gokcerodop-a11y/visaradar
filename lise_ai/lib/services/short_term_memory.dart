import 'dart:collection';
import '../models/teacher_identity.dart'; // TeacherEmotionalState
import 'attention_engine.dart'; // PacingAdjustment

// ── ShortTermTurn ─────────────────────────────────────────────────────────────

class ShortTermTurn {
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final String? topic;

  const ShortTermTurn({
    required this.role,
    required this.text,
    required this.timestamp,
    this.topic,
  });
}

// ── ShortTermMemory ───────────────────────────────────────────────────────────
//
// Sliding window of last 20 turns.
// Tracks active confusion, problem, board state, emotional state, pacing.

class ShortTermMemory {
  static const int maxTurns = 20;

  final Queue<ShortTermTurn> _turns = Queue();

  String? currentConfusion;       // detected confusion phrase or topic
  String? activeProblem;          // current question being worked on
  String? boardStateDescription;  // last thing shown on board
  TeacherEmotionalState? recentEmotionalState;
  PacingAdjustment? currentPacing;

  static const List<String> _confusionPhrases = [
    'anlamadım', 'bilmiyorum', 'karıştı', 'anlayamadım',
    'nasıl oluyor', 'neden böyle', 'çözemedim', 'takıldım',
  ];

  void addTurn(ShortTermTurn turn) {
    _turns.addLast(turn);
    while (_turns.length > maxTurns) { _turns.removeFirst(); }
    if (turn.role == 'user') {
      final lower = turn.text.toLowerCase();
      if (_confusionPhrases.any((p) => lower.contains(p))) {
        currentConfusion = turn.text.length > 100
            ? '${turn.text.substring(0, 100)}…'
            : turn.text;
      }
      if (turn.text.contains('?') || turn.text.length < 120) {
        activeProblem = turn.text.length > 120
            ? '${turn.text.substring(0, 120)}…'
            : turn.text;
      }
    }
  }

  List<ShortTermTurn> get recentTurns => _turns.toList();

  String buildContextBlock() {
    final sb = StringBuffer('\n## Anlık Oturum Bağlamı\n');
    bool hasContent = false;

    if (currentConfusion != null) {
      sb.writeln('- Güncel karışıklık: "$currentConfusion"');
      hasContent = true;
    }
    if (activeProblem != null) {
      sb.writeln('- Aktif soru: "$activeProblem"');
      hasContent = true;
    }
    if (boardStateDescription != null) {
      sb.writeln('- Tahta içeriği: $boardStateDescription');
      hasContent = true;
    }
    if (recentEmotionalState != null) {
      sb.writeln('- Son öğretmen tonu: ${recentEmotionalState!.label}');
      hasContent = true;
    }
    if (currentPacing != null && currentPacing != PacingAdjustment.none) {
      sb.writeln('- Tempo ayarı: ${currentPacing!.name}');
      hasContent = true;
    }

    // Last 4 turns as context snippet
    final recent = _turns.toList().reversed.take(4).toList().reversed.toList();
    if (recent.isNotEmpty) {
      sb.writeln('Son etkileşimler:');
      for (final t in recent) {
        final role = t.role == 'user' ? 'Öğrenci' : 'Öğretmen';
        final preview = t.text.length > 90 ? '${t.text.substring(0, 90)}…' : t.text;
        sb.writeln('  $role: $preview');
      }
      hasContent = true;
    }

    if (!hasContent) return '';
    return sb.toString();
  }

  void clear() {
    _turns.clear();
    currentConfusion = null;
    activeProblem = null;
    boardStateDescription = null;
    recentEmotionalState = null;
    currentPacing = null;
  }
}
