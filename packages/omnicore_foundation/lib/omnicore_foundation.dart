// OmniCore Foundation — shared low-level utilities for all OmniCore apps.
//
// Phase 3 of the OmniCore migration lifts every domain-agnostic utility
// out of `lise_ai/lib/services/` into this package. Each lift comes with
// a re-export shim left behind in `lib/services/<file>.dart` so existing
// call sites continue to compile unchanged.
//
// See docs/architecture/omnicore_migration_plan.md.

// ── Extracted services (Phase 3) ─────────────────────────────────────────────

export 'src/api_client.dart';
export 'src/app_logger.dart';
export 'src/app_version_service.dart';
export 'src/connectivity_service.dart';
export 'src/crash_reporter.dart';
export 'src/error_handler.dart';
export 'src/haptics_service.dart';
export 'src/working_memory.dart';

// ── Package identity ─────────────────────────────────────────────────────────

/// Package identity. Bumped when public API changes.
const omniCoreFoundationVersion = '0.3.0';

/// Human-readable package name.
const omniCoreFoundationName = 'omnicore_foundation';
