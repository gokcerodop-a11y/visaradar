// return_greeting_builder.dart
//
// Composes the LiseAI return-greeting string a teacher uses when the
// student reopens the app after a previous session.
//
// Phase 4C — moved out of SessionContinuityService so that service can
// be extracted to omnicore_session in Phase 4F without dragging LiseAI's
// TeacherIdentity along. Pure function, no state.

import '../models/teacher_identity.dart';
import 'session_continuity_service.dart' show SessionContinuityData;

/// Build the "we left off here…" greeting line for the teacher to speak.
///
/// Returns `null` when there isn't enough prior-session context to compose
/// a useful greeting (first launch, or session continuity data is empty).
String? buildReturnGreeting(
  SessionContinuityData data,
  TeacherIdentity teacher,
) {
  if (!data.hasReturnContent) return null;

  final diff = DateTime.now().difference(data.lastSessionDate!);
  final timeStr = diff.inMinutes < 60
      ? 'az önce'
      : diff.inHours < 24
          ? '${diff.inHours} saat önce'
          : '${diff.inDays} gün önce';

  final lastTopic = data.lastTopics.isNotEmpty ? data.lastTopics.first : null;
  final unfinished = data.unfinishedTopic;

  if (unfinished != null) {
    return '${teacher.teacherName}: $timeStr "$unfinished" konusunda kalmıştık. '
        'Devam edelim mi?';
  }
  if (lastTopic != null) {
    return '${teacher.teacherName}: Geçen seferden devam ediyoruz. '
        'En son "$lastTopic" üzerinde çalışmıştık.';
  }
  return null;
}
