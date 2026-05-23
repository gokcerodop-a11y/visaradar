import 'whiteboard_element.dart';

/// One teaching step: short title + spoken text + whiteboard elements.
class LessonStep {
  final String stepTitle;       // Short 1–3 word label, e.g. "Tanım"
  final String text;            // Full teacher explanation (shown in chat)
  final List<int> elementIndices;
  final double pauseAfter;

  const LessonStep({
    required this.stepTitle,
    required this.text,
    required this.elementIndices,
    this.pauseAfter = 1.5,
  });

  int get wordCount =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
        stepTitle: j['step_title'] as String? ?? 'Adım',
        text: j['text'] as String? ?? '',
        elementIndices: ((j['elements'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        pauseAfter: (j['pause_after'] as num?)?.toDouble() ?? 1.5,
      );
}

/// Full lesson: ordered steps + whiteboard elements.
class LessonTimeline {
  final String title;
  final List<LessonStep> steps;
  final List<WhiteboardElement> elements;

  const LessonTimeline({
    required this.title,
    required this.steps,
    required this.elements,
  });

  factory LessonTimeline.fromJson(Map<String, dynamic> j) => LessonTimeline(
        title: j['title'] as String? ?? '',
        elements: ((j['elements'] as List?) ?? [])
            .map((e) =>
                WhiteboardElement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        steps: ((j['steps'] as List?) ?? [])
            .map((s) =>
                LessonStep.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );

  WhiteboardData get whiteboardData =>
      WhiteboardData(title: title, elements: elements);

  /// Animation start time for step [i] = min delay of its elements.
  double stepStartTime(int i) {
    if (i >= steps.length) return double.infinity;
    final idxs = steps[i]
        .elementIndices
        .where((idx) => idx < elements.length)
        .toList();
    if (idxs.isEmpty) return 0;
    return idxs
        .map((idx) => elements[idx].delay)
        .reduce((a, b) => a < b ? a : b);
  }
}
