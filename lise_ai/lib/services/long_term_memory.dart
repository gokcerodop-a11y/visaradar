// long_term_memory.dart — re-export shim (Phase 4D of the OmniCore migration).
//
// Canonical source moved to `package:omnicore_memory/omnicore_memory.dart`.
// LiseAI call sites continue to use `import '../services/long_term_memory.dart';`
// unchanged.

export 'package:omnicore_memory/omnicore_memory.dart'
    show LongTermMemory, MistakePattern, SubjectMastery;
