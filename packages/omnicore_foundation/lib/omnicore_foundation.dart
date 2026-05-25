// OmniCore Foundation — shared low-level utilities for all OmniCore apps.
//
// Phase 3 lifted concrete utility services into this package. Phase 4
// adds three minimal interfaces (KeyValueStorage, AssistantTone,
// AssistantPacingHint) that downstream OmniCore packages depend on
// instead of LiseAI's concrete types. See:
//   docs/architecture/omnicore_migration_plan.md
//   docs/architecture/omnicore_phase4_plan.md

// ── Extracted services (Phase 3) ─────────────────────────────────────────────

export 'src/api_client.dart';
export 'src/app_logger.dart';
export 'src/app_version_service.dart';
export 'src/connectivity_service.dart';
export 'src/crash_reporter.dart';
export 'src/error_handler.dart';
export 'src/haptics_service.dart';
export 'src/working_memory.dart';

// ── Interfaces (Phase 4A) ────────────────────────────────────────────────────

export 'src/assistant_pacing_hint.dart';
export 'src/assistant_tone.dart';
export 'src/key_value_storage.dart';

// ── Package identity ─────────────────────────────────────────────────────────

/// Package identity. Bumped when public API changes.
const omniCoreFoundationVersion = '0.4.1';

/// Human-readable package name.
const omniCoreFoundationName = 'omnicore_foundation';
