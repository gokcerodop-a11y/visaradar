// app_logger.dart — re-export shim (Phase 3 of the OmniCore migration).
//
// Canonical source moved to `package:omnicore_foundation/omnicore_foundation.dart`.
// This shim exists so every existing `import '../services/app_logger.dart';`
// call site keeps working unchanged. Future cleanup will rewrite call
// sites to import the package directly.

export 'package:omnicore_foundation/omnicore_foundation.dart'
    show AppLogger, LogLevel;
