// OmniCore Memory — five-layer cognitive memory subsystem.
//
// Phase 4D shipped the three pure-storage memory layers.
// Phase 4E adds ShortTermMemory + the two pure orchestrators
// (MemoryRetrievalEngine, MemoryPromptLayer). MemorySummarizer stays
// in lise_ai for Phase 4 because it depends on AIProvider which moves
// to its own package in Phase 5.
//
// All public surface is provider- and vertical-agnostic. Storage flows
// through omnicore_foundation's KeyValueStorage interface; tone +
// pacing flow through omnicore_foundation's AssistantTone +
// AssistantPacingHint interfaces.

// ── Storage-backed layers (Phase 4D) ─────────────────────────────────────────

export 'src/episodic_memory.dart';
export 'src/long_term_memory.dart';
export 'src/semantic_memory.dart';

// ── In-session layers + orchestrators (Phase 4E) ─────────────────────────────

export 'src/memory_prompt_layer.dart';
export 'src/memory_retrieval_engine.dart';
export 'src/short_term_memory.dart';

/// Package identity. Bumped when public API changes.
const omniCoreMemoryVersion = '0.2.0';

/// Human-readable package name.
const omniCoreMemoryName = 'omnicore_memory';
