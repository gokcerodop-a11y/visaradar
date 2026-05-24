import 'episodic_memory.dart';
import 'long_term_memory.dart';
import 'memory_retrieval_engine.dart';
import 'semantic_memory.dart';
import 'short_term_memory.dart';
import 'working_memory.dart';

// ── MemoryPromptLayer ─────────────────────────────────────────────────────────
//
// Assembles all cognitive memory layers into a structured Claude system prompt.
// Called once per _buildSystemPrompt() invocation in ai_os_screen.dart.
//
// Layer order (from most to least critical for immediate response quality):
//   1. Short-term: what's happening RIGHT NOW
//   2. Working memory: what the teacher is tracking
//   3. Retrieved memories: relevant past history
//   4. Long-term profile: who the student IS
//   5. Semantic: topic relationships and successful patterns
//   6. Episodic: memorable moments to reference naturally
//
// Future hooks:
//   - Vector memory (RAG): replace keyword retrieval with embedding similarity
//   - Cloud sync: persist across devices
//   - Cross-device memory: share between phone and tablet
//   - Team classroom: teacher dashboard across multiple students
//   - Embedding-based analogy matching

class MemoryPromptLayer {
  static String build({
    required ShortTermMemory shortTerm,
    required WorkingMemory workingMemory,
    required LongTermMemory longTerm,
    required EpisodicMemory episodic,
    required SemanticMemory semantic,
    required MemoryRetrievalEngine retrieval,
    required String currentTopic,
  }) {
    // Retrieve contextually relevant memories
    final query = MemoryQuery(currentTopic: currentTopic);
    final retrieved = retrieval.retrieve(
      query,
      episodic: episodic,
      longTerm: longTerm,
      semantic: semantic,
      shortTerm: shortTerm,
      working: workingMemory,
    );

    final sb = StringBuffer();

    // ── Layer 1: Immediate session context (highest priority) ──────────────
    final stBlock = shortTerm.buildContextBlock();
    if (stBlock.isNotEmpty) sb.write(stBlock);

    // ── Layer 2: Working memory (active reasoning state) ──────────────────
    final wmBlock = workingMemory.buildWorkingMemoryBlock();
    if (wmBlock.isNotEmpty) sb.write(wmBlock);

    // ── Layer 3: Retrieved memories (contextually relevant past) ──────────
    final retrievalBlock = retrieval.buildRetrievalBlock(retrieved);
    if (retrievalBlock.isNotEmpty) sb.write(retrievalBlock);

    // ── Layer 4: Long-term student profile ─────────────────────────────────
    final ltBlock = longTerm.buildLongTermBlock();
    if (ltBlock.isNotEmpty) sb.write(ltBlock);

    // ── Layer 5: Semantic knowledge (topic graph, analogies) ───────────────
    final semBlock = semantic.buildSemanticBlock(currentTopic);
    if (semBlock.isNotEmpty) sb.write(semBlock);

    // ── Layer 6: Episodic (memorable moments — use naturally) ──────────────
    final epBlock = episodic.buildEpisodicBlock(currentTopic);
    if (epBlock.isNotEmpty) sb.write(epBlock);

    if (sb.isEmpty) return '';

    return '\n# Öğretmen Belleği\n'
        'Bu bilgiler sana öğrenciyi daha iyi tanıman için verildi. '
        'Listele değil, doğal konuşma sırasında yeri geldikçe kullan.\n'
        '$sb';
  }

  /// Quick version: only short-term + working memory. Used when full build is too slow.
  static String buildQuick({
    required ShortTermMemory shortTerm,
    required WorkingMemory workingMemory,
  }) {
    final sb = StringBuffer();
    final stBlock = shortTerm.buildContextBlock();
    if (stBlock.isNotEmpty) sb.write(stBlock);
    final wmBlock = workingMemory.buildWorkingMemoryBlock();
    if (wmBlock.isNotEmpty) sb.write(wmBlock);
    return sb.toString();
  }
}
