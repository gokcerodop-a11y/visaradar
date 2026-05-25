// OmniCore Memory — five-layer cognitive memory subsystem.
//
// Phase 4D ships the three pure-storage memory layers (LongTermMemory,
// EpisodicMemory, SemanticMemory). Phase 4E will add ShortTermMemory and
// the three orchestrators (MemoryRetrievalEngine, MemoryPromptLayer,
// MemorySummarizer — the latter deferred to Phase 5).
//
// All public surface is provider- and vertical-agnostic. Storage flows
// through omnicore_foundation's KeyValueStorage interface.

export 'src/episodic_memory.dart';
export 'src/long_term_memory.dart';
export 'src/semantic_memory.dart';

/// Package identity. Bumped when public API changes.
const omniCoreMemoryVersion = '0.1.0';

/// Human-readable package name.
const omniCoreMemoryName = 'omnicore_memory';
