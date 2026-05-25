// ── WorkingGoal ───────────────────────────────────────────────────────────────

class WorkingGoal {
  final String description;
  final DateTime setAt;
  final List<String> subgoals;
  bool isResolved;

  WorkingGoal({
    required this.description,
    required this.setAt,
    List<String>? subgoals,
    this.isResolved = false,
  }) : subgoals = subgoals ?? [];
}

// ── WorkingMemory ─────────────────────────────────────────────────────────────
//
// Teacher's active reasoning state.
// Current goal, unresolved concepts, equation state, reasoning chain.
// Designed to survive session interruptions.

class WorkingMemory {
  WorkingGoal? currentGoal;
  final List<String> _unresolvedConcepts = [];
  String? activeSubproblem;
  String? currentEquationState; // e.g. "2x+4=10 → şu an: 2x=6"
  final List<String> _reasoningChain = [];
  bool _wasInterrupted = false;
  DateTime? _interruptedAt;

  List<String> get unresolvedConcepts => List.unmodifiable(_unresolvedConcepts);
  List<String> get reasoningChain => List.unmodifiable(_reasoningChain);
  bool get wasInterrupted => _wasInterrupted;

  void setGoal(String description, {List<String>? subgoals}) {
    currentGoal = WorkingGoal(
      description: description,
      setAt: DateTime.now(),
      subgoals: subgoals,
    );
    _wasInterrupted = false;
  }

  void resolveGoal() {
    currentGoal = null;
    _reasoningChain.clear();
    activeSubproblem = null;
    currentEquationState = null;
  }

  void addUnresolvedConcept(String concept) {
    if (!_unresolvedConcepts.contains(concept)) {
      _unresolvedConcepts.add(concept);
    }
  }

  void resolveConcept(String concept) {
    _unresolvedConcepts.remove(concept);
  }

  void addReasoningStep(String step) {
    _reasoningChain.add(step);
    if (_reasoningChain.length > 8) _reasoningChain.removeAt(0);
  }

  void markInterrupted() {
    _wasInterrupted = true;
    _interruptedAt = DateTime.now();
  }

  void resume() {
    _wasInterrupted = false;
  }

  String buildWorkingMemoryBlock() {
    final hasContent = currentGoal != null ||
        _unresolvedConcepts.isNotEmpty ||
        _reasoningChain.isNotEmpty ||
        activeSubproblem != null ||
        currentEquationState != null;

    if (!hasContent) return '';

    final sb = StringBuffer('\n## Çalışma Belleği (Aktif Oturum)\n');

    if (currentGoal != null) {
      sb.writeln('- Hedef: ${currentGoal!.description}');
      if (currentGoal!.subgoals.isNotEmpty) {
        sb.writeln('  Alt hedefler: ${currentGoal!.subgoals.join(' | ')}');
      }
    }

    if (_wasInterrupted && _interruptedAt != null) {
      sb.writeln('- ⚠ Oturum kesintiye uğradı (${_ago(_interruptedAt!)}) — hedef hâlâ geçerli');
    }

    if (activeSubproblem != null) {
      sb.writeln('- Aktif alt problem: $activeSubproblem');
    }

    if (currentEquationState != null) {
      sb.writeln('- Denklem durumu: $currentEquationState');
    }

    if (_unresolvedConcepts.isNotEmpty) {
      sb.writeln('- Henüz çözülmemiş kavramlar: ${_unresolvedConcepts.join(', ')}');
    }

    if (_reasoningChain.isNotEmpty) {
      sb.writeln('- Akıl yürütme zinciri:');
      for (final step in _reasoningChain) {
        sb.writeln('  → $step');
      }
    }

    return sb.toString();
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    return '${diff.inHours} saat önce';
  }
}
