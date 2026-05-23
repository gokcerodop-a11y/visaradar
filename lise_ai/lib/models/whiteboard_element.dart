import 'package:flutter/material.dart';

// ── Element type ───────────────────────────────────────────────────────────────

enum WBType {
  text,
  formula,
  step,
  line,
  arrow,
  vector,
  circle,
  rect,
  axes,
  curve,
  point,
  parabola,
  sine,
  triangle,
}

// ── Single whiteboard element ─────────────────────────────────────────────────

class WhiteboardElement {
  final WBType type;
  final double delay; // seconds from animation start

  // Text / formula / step
  final String? content;
  final double fontSize;

  // Normalized position (0.0–1.0 relative to canvas)
  final double? x, y;

  // Line / arrow / vector endpoints
  final double? x1, y1, x2, y2;

  // Circle / parabola vertex
  final double? cx, cy, r;

  // Axes / rect size
  final double? w, h;

  // Parabola coefficient (y = a*(x-cx)^2 in normalized-then-scaled space)
  final double? a;

  // Sine wave parameters
  final double? amplitude, frequency, phase;

  // Polyline / curve / triangle vertices
  final List<List<double>>? points;

  // Optional label (arrow tip, point label, curve name, comma-separated for triangle)
  final String? label;

  // Color name (mapped below)
  final String colorName;

  const WhiteboardElement({
    required this.type,
    required this.delay,
    this.content,
    this.fontSize = 15,
    this.x,
    this.y,
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.cx,
    this.cy,
    this.r,
    this.w,
    this.h,
    this.a,
    this.amplitude,
    this.frequency,
    this.phase,
    this.points,
    this.label,
    this.colorName = 'white',
  });

  // ── Color mapping ───────────────────────────────────────────────────────────

  Color get color {
    switch (colorName) {
      case 'purple':
        return const Color(0xFF9B8BFB);
      case 'blue':
        return const Color(0xFF60A5FA);
      case 'green':
        return const Color(0xFF4ADE80);
      case 'orange':
        return const Color(0xFFFB923C);
      case 'red':
        return const Color(0xFFF87171);
      case 'yellow':
        return const Color(0xFFFBBF24);
      case 'gray':
        return const Color(0xFF9CA3AF);
      case 'pink':
        return const Color(0xFFF472B6);
      case 'cyan':
        return const Color(0xFF22D3EE);
      default:
        return Colors.white;
    }
  }

  // ── JSON deserialization ────────────────────────────────────────────────────

  static WBType _parseType(String s) {
    switch (s) {
      case 'formula':
        return WBType.formula;
      case 'step':
        return WBType.step;
      case 'line':
        return WBType.line;
      case 'arrow':
        return WBType.arrow;
      case 'vector':
        return WBType.vector;
      case 'circle':
        return WBType.circle;
      case 'rect':
        return WBType.rect;
      case 'axes':
        return WBType.axes;
      case 'curve':
        return WBType.curve;
      case 'point':
        return WBType.point;
      case 'parabola':
        return WBType.parabola;
      case 'sine':
        return WBType.sine;
      case 'triangle':
        return WBType.triangle;
      default:
        return WBType.text;
    }
  }

  factory WhiteboardElement.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return WhiteboardElement(
      type: _parseType(j['type'] as String? ?? 'text'),
      delay: (j['delay'] as num? ?? 0).toDouble(),
      content: j['content'] as String?,
      fontSize: (j['size'] as num?)?.toDouble() ?? 15,
      x: d('x') ?? d('ox'),
      y: d('y') ?? d('oy'),
      x1: d('x1'),
      y1: d('y1'),
      x2: d('x2'),
      y2: d('y2'),
      cx: d('cx'),
      cy: d('cy'),
      r: d('r'),
      w: d('w'),
      h: d('h'),
      a: d('a'),
      amplitude: d('amplitude'),
      frequency: d('frequency'),
      phase: d('phase'),
      points: (j['points'] as List?)
          ?.map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
      label: j['label'] as String?,
      colorName: j['color'] as String? ?? 'white',
    );
  }
}

// ── Whiteboard dataset ────────────────────────────────────────────────────────

class WhiteboardData {
  final String title;
  final List<WhiteboardElement> elements;

  const WhiteboardData({required this.title, required this.elements});

  factory WhiteboardData.fromJson(Map<String, dynamic> j) => WhiteboardData(
        title: j['title'] as String? ?? '',
        elements: ((j['elements'] as List?) ?? [])
            .map((e) =>
                WhiteboardElement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  /// Total animation duration in seconds.
  /// Buffer is 4 s to cover long draw durations (sine = 2.5 s, parabola = 2.2 s).
  double get totalDuration {
    if (elements.isEmpty) return 0;
    final maxDelay = elements.map((e) => e.delay).reduce((a, b) => a > b ? a : b);
    return maxDelay + 4.0;
  }

  /// Default fallback animation shown when AI cannot generate a plan.
  static WhiteboardData defaultAnimation() {
    return const WhiteboardData(
      title: 'Sinüs Fonksiyonu',
      elements: [
        // Axes first
        WhiteboardElement(
          type: WBType.axes,
          x: 0.07, y: 0.72, w: 0.86, h: 0.55,
          label: 'x,y',
          delay: 0.0,
          colorName: 'gray',
        ),
        // Title formula
        WhiteboardElement(
          type: WBType.formula,
          content: 'f(x) = sin(x)',
          x: 0.07, y: 0.06,
          fontSize: 22,
          colorName: 'purple',
          delay: 0.9,
        ),
        // Sine wave
        WhiteboardElement(
          type: WBType.sine,
          x1: 0.07, x2: 0.93, y: 0.72,
          amplitude: 0.17,
          frequency: 2.0,
          colorName: 'purple',
          label: 'sin(x)',
          delay: 1.5,
        ),
        // Period annotation
        WhiteboardElement(
          type: WBType.arrow,
          x1: 0.07, y1: 0.85, x2: 0.50, y2: 0.85,
          colorName: 'cyan',
          label: 'Periyot 2π',
          delay: 3.0,
        ),
        // Key points
        WhiteboardElement(
          type: WBType.point,
          x: 0.07, y: 0.72,
          label: '(0, 0)',
          colorName: 'yellow',
          delay: 3.4,
        ),
        WhiteboardElement(
          type: WBType.point,
          x: 0.285, y: 0.55,
          label: '(π/2, 1)',
          colorName: 'green',
          delay: 3.7,
        ),
        WhiteboardElement(
          type: WBType.point,
          x: 0.50, y: 0.72,
          label: '(π, 0)',
          colorName: 'yellow',
          delay: 4.0,
        ),
        // Note
        WhiteboardElement(
          type: WBType.text,
          content: 'Genlik: 1   |   Periyot: 2π ≈ 6.28',
          x: 0.07, y: 0.91,
          fontSize: 12,
          colorName: 'gray',
          delay: 4.3,
        ),
      ],
    );
  }
}
