// OmniCore Foundation — shared low-level utilities for all OmniCore apps.
//
// Phase 3 of the OmniCore migration begins lifting LiseAI services into
// this package. Each lift comes with a re-export shim left behind in
// lib/services/<file>.dart so existing call sites continue to work
// unchanged. See docs/architecture/omnicore_migration_plan.md.

// ── Extracted services (Phase 3) ─────────────────────────────────────────────

export 'src/app_logger.dart';
export 'src/crash_reporter.dart';

// ── Package identity ─────────────────────────────────────────────────────────

/// Package identity. Bumped when public API changes.
const omniCoreFoundationVersion = '0.2.0';

/// Human-readable package name.
const omniCoreFoundationName = 'omnicore_foundation';
