// ai_message.dart
// Provider-agnostic message + role types for AI conversations.
// Maps cleanly to Claude (system + user/assistant), OpenAI (system+user+assistant)
// and Gemini (system instruction + user/model).

import 'dart:typed_data';

/// Conversational role.
enum AIMessageRole {
  /// User input.
  user,

  /// Model output.
  assistant,
}

/// A single image attached to a message.
class AIImageAttachment {
  final Uint8List bytes;
  final String mediaType; // e.g. "image/png", "image/jpeg"

  const AIImageAttachment({
    required this.bytes,
    required this.mediaType,
  });
}

/// One turn in a conversation.
///
/// Either [text] is non-null (text-only turn) or [images] is non-empty
/// (multimodal turn). Both can be set when a turn carries text + images.
class AIMessage {
  final AIMessageRole role;
  final String text;
  final List<AIImageAttachment> images;

  const AIMessage({
    required this.role,
    required this.text,
    this.images = const [],
  });

  AIMessage.user(String text, {List<AIImageAttachment> images = const []})
      : this(role: AIMessageRole.user, text: text, images: images);

  AIMessage.assistant(String text)
      : this(role: AIMessageRole.assistant, text: text);

  /// Map representation used by Claude's `/messages` endpoint.
  /// Other providers convert via their own adapters.
  Map<String, dynamic> toClaudeJson() {
    if (images.isEmpty) {
      return {'role': role.name, 'content': text};
    }
    final content = <Map<String, dynamic>>[];
    for (final img in images) {
      content.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': img.mediaType,
          'data': _base64(img.bytes),
        },
      });
    }
    if (text.isNotEmpty) {
      content.add({'type': 'text', 'text': text});
    }
    return {'role': role.name, 'content': content};
  }

  static String _base64(Uint8List bytes) {
    // Tiny inline base64 to keep zero external deps.
    // Falls back to dart:convert if dart:typed_data alone isn't enough.
    // The actual base64 encoder is imported by callers when needed; this
    // helper exists to make the toClaudeJson API self-contained for tests.
    // ignore: avoid_dynamic_calls
    return _Base64.encode(bytes);
  }
}

/// Minimal in-package base64 to avoid a dart:convert import in the type file.
abstract class _Base64 {
  static const _table =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  static String encode(Uint8List bytes) {
    final out = StringBuffer();
    int i = 0;
    while (i + 3 <= bytes.length) {
      final b0 = bytes[i];
      final b1 = bytes[i + 1];
      final b2 = bytes[i + 2];
      out.write(_table[(b0 >> 2) & 0x3F]);
      out.write(_table[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      out.write(_table[((b1 << 2) | (b2 >> 6)) & 0x3F]);
      out.write(_table[b2 & 0x3F]);
      i += 3;
    }
    final remaining = bytes.length - i;
    if (remaining == 1) {
      final b0 = bytes[i];
      out.write(_table[(b0 >> 2) & 0x3F]);
      out.write(_table[(b0 << 4) & 0x3F]);
      out.write('==');
    } else if (remaining == 2) {
      final b0 = bytes[i];
      final b1 = bytes[i + 1];
      out.write(_table[(b0 >> 2) & 0x3F]);
      out.write(_table[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      out.write(_table[(b1 << 2) & 0x3F]);
      out.write('=');
    }
    return out.toString();
  }
}
