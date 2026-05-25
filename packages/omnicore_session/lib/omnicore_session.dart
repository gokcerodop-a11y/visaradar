// OmniCore Session — continuity + recovery for AI conversational apps.
//
// Two services, both domain-agnostic after Phase 4C:
//
//   SessionContinuityService    persists cross-session topic context,
//                               confidence trend, frustration streak,
//                               used analogies, last-session summary.
//                               Stable Hive key: 'session_continuity_v1'.
//
//   SessionRecoveryService      cold-start snapshot of the most recent
//                               session, restorable within 24h.
//                               Stable Hive key: 'session_snapshot_v1'.
//
// Persistence flows through omnicore_foundation's KeyValueStorage.

export 'src/session_continuity_service.dart';
export 'src/session_recovery_service.dart';

/// Package identity. Bumped when public API changes.
const omniCoreSessionVersion = '0.1.0';

/// Human-readable package name.
const omniCoreSessionName = 'omnicore_session';
