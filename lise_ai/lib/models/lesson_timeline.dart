import 'whiteboard_element.dart';

/// One teaching step: text to display + which whiteboard elements appear.
class LessonStep {
  final String text;
  final List<int> elementIndices; // 0-based indices into LessonTimeline.elements

  const LessonStep({required this.text, required this.elementIndices});

  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
        text: j['text'] as String? ?? '',
        elementIndices: ((j['elements'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}

/// Full lesson: ordered steps + all whiteboard elements.
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

  /// WhiteboardData view for the existing painter.
  WhiteboardData get whiteboardData =>
      WhiteboardData(title: title, elements: elements);

  /// Animation start time for step [i] = minimum delay of its elements.
  double stepStartTime(int i) {
    if (i >= steps.length) return double.infinity;
    final idxs = steps[i]
        .elementIndices
        .where((idx) => idx < elements.length)
        .toList();
    if (idxs.isEmpty) return 0;
    return idxs.map((idx) => elements[idx].delay).reduce((a, b) => a < b ? a : b);
  }
}
