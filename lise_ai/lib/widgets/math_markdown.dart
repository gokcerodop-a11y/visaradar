import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// ── Public widget ─────────────────────────────────────────────────────────────

/// Renders mixed Markdown + LaTeX math.
///
/// Supported delimiters:
///   $$...$$   or   \[...\]   → display (block) math
///   $...$     or   \(...\)   → inline math inside text
///
/// During streaming ([isStreaming] = true) incomplete delimiters are rendered
/// as plain text to avoid parse errors.
class MathMarkdown extends StatelessWidget {
  final String data;
  final bool isStreaming;
  final MarkdownStyleSheet? styleSheet;

  const MathMarkdown({
    super.key,
    required this.data,
    this.isStreaming = false,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final blocks = _splitDisplayMath(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((b) => _buildBlock(context, b)).toList(),
    );
  }

  // ── Block rendering ─────────────────────────────────────────────────────────

  Widget _buildBlock(BuildContext context, _Block block) {
    if (block.isDisplay) return _DisplayMathBox(tex: block.content);
    return _InlineContent(
      text: block.content,
      styleSheet: styleSheet,
      isStreaming: isStreaming,
    );
  }

  // ── Display math splitter ───────────────────────────────────────────────────

  List<_Block> _splitDisplayMath(String text) {
    // If streaming, bail early if we have an unclosed $$
    if (isStreaming) {
      final ddCount = '\$\$'.allMatches(text).length;
      if (ddCount % 2 != 0) return [_Block(text, false)];
    }

    final segments = <_Block>[];
    // Match $$...$$ or \[...\]
    final re = RegExp(r'\$\$([\s\S]*?)\$\$|\\\[([\s\S]*?)\\\]');
    int cursor = 0;

    for (final m in re.allMatches(text)) {
      if (m.start > cursor) {
        segments.add(_Block(text.substring(cursor, m.start), false));
      }
      final content = (m.group(1) ?? m.group(2) ?? '').trim();
      if (content.isNotEmpty) segments.add(_Block(content, true));
      cursor = m.end;
    }
    if (cursor < text.length) {
      segments.add(_Block(text.substring(cursor), false));
    }
    return segments.isEmpty ? [_Block(text, false)] : segments;
  }
}

// ── Display math box ──────────────────────────────────────────────────────────

class _DisplayMathBox extends StatelessWidget {
  final String tex;
  const _DisplayMathBox({required this.tex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF08081C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2464), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          tex,
          mathStyle: MathStyle.display,
          textStyle: const TextStyle(
            color: Color(0xFFE9D5FF),
            fontSize: 18,
            height: 1.5,
          ),
          onErrorFallback: (_) => SelectableText(
            tex,
            style: const TextStyle(
              color: Color(0xFFE9D5FF),
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inline content renderer ───────────────────────────────────────────────────

/// Renders a non-display segment that may contain inline math ($...$, \(...\)).
class _InlineContent extends StatelessWidget {
  final String text;
  final MarkdownStyleSheet? styleSheet;
  final bool isStreaming;

  // Matches $...$  or  \(...\)
  // Avoids $$ (display math) and empty spans.
  static final _inlineRe = RegExp(
    r'(?<!\$)\$(?!\$)([^$\n]+?)(?<!\$)\$(?!\$)|\\\((.+?)\\\)',
    dotAll: false,
  );

  const _InlineContent({
    required this.text,
    this.styleSheet,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox(height: 2);

    // During streaming, avoid partial inline math rendering.
    final safeText =
        isStreaming ? _stripPartialInline(text) : text;

    if (!_inlineRe.hasMatch(safeText)) {
      // Pure markdown — delegate fully.
      return MarkdownBody(
        data: safeText,
        styleSheet: styleSheet,
        softLineBreak: true,
      );
    }

    // Contains inline math — process line by line.
    return _buildLines(context, safeText);
  }

  Widget _buildLines(BuildContext context, String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    final mdBuffer = StringBuffer();

    void flushMarkdown() {
      final md = mdBuffer.toString().trimRight();
      if (md.isNotEmpty) {
        widgets.add(MarkdownBody(
          data: md,
          styleSheet: styleSheet,
          softLineBreak: true,
        ));
      }
      mdBuffer.clear();
    }

    for (final line in lines) {
      if (_inlineRe.hasMatch(line)) {
        flushMarkdown();
        widgets.add(_MathLine(line: line, context: context));
      } else {
        mdBuffer.writeln(line);
      }
    }
    flushMarkdown();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// During streaming, if there's an unclosed `$`, strip from that point.
  static String _stripPartialInline(String text) {
    final dollars = RegExp(r'(?<!\$)\$(?!\$)').allMatches(text).toList();
    if (dollars.length % 2 != 0) {
      // Odd number of single-$ → last one is unclosed; strip from it
      return text.substring(0, dollars.last.start);
    }
    return text;
  }
}

// ── Single line with inline math ──────────────────────────────────────────────

class _MathLine extends StatelessWidget {
  final String line;
  final BuildContext context;

  static final _re = RegExp(
    r'(?<!\$)\$(?!\$)([^$\n]+?)(?<!\$)\$(?!\$)|\\\((.+?)\\\)',
    dotAll: false,
  );

  const _MathLine({required this.line, required this.context});

  @override
  Widget build(BuildContext _) {
    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final m in _re.allMatches(line)) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: line.substring(cursor, m.start),
          style: _plainStyle,
        ));
      }
      final mathTex = (m.group(1) ?? m.group(2) ?? '').trim();
      if (mathTex.isNotEmpty) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              mathTex,
              textStyle: const TextStyle(
                color: Color(0xFFE9D5FF),
                fontSize: 15.5,
              ),
              onErrorFallback: (_) => Text(
                '\$$mathTex\$',
                style: const TextStyle(
                  color: Color(0xFFE9D5FF),
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ));
      }
      cursor = m.end;
    }

    if (cursor < line.length) {
      spans.add(TextSpan(
        text: line.substring(cursor),
        style: _plainStyle,
      ));
    }

    if (spans.isEmpty) return const SizedBox(height: 2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(children: spans),
        textScaler: MediaQuery.of(context).textScaler,
      ),
    );
  }

  static const _plainStyle = TextStyle(
    color: Color(0xFFE5E7EB),
    fontSize: 15,
    height: 1.55,
  );
}

// ── Internal model ─────────────────────────────────────────────────────────────

class _Block {
  final String content;
  final bool isDisplay;
  const _Block(this.content, this.isDisplay);
}
