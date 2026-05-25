/// OmniCore Foundation — shared low-level utilities for all OmniCore apps.
///
/// Phase 1 of the OmniCore migration is intentionally a skeleton. Real
/// extractions begin in Phase 3 (per `docs/architecture/omnicore_migration_plan.md`).
/// For now this package exposes only its identity and version so dependent
/// apps can wire up imports and verify the monorepo plumbing works.

/// Package identity. Bumped when public API changes.
const omniCoreFoundationVersion = '0.1.0';

/// Human-readable package name.
const omniCoreFoundationName = 'omnicore_foundation';
