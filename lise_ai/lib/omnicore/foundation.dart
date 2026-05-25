// foundation.dart
// Barrel for the future `omnicore_foundation` package.
//
// Phase 2: re-exports today's files from their current `lib/services/`
// locations. Phase 3 will physically move each of these into
// `packages/omnicore_foundation/lib/src/`. Callers that depend on this
// barrel today will keep working unchanged after the move.

export '../services/api_client.dart';
export '../services/app_logger.dart';
export '../services/app_version_service.dart';
export '../services/connectivity_service.dart';
export '../services/crash_reporter.dart';
export '../services/error_handler.dart';
export '../services/haptics_service.dart';
export '../services/runtime_stability_monitor.dart';
export '../services/runtime_validation_service.dart';
export '../services/storage_service.dart';
