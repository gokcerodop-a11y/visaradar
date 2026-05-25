// session.dart
// Barrel for the future `omnicore_session` package.
//
// Cold-start recovery + cross-session continuity. Phase 4 lifts these
// to their own package after the LessonMode + topic context is
// parametrized to a generic SessionContext<T>.

export '../services/session_continuity_service.dart';
export '../services/session_recovery_service.dart';
