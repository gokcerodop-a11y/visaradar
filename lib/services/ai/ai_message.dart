// ai_message.dart — provider-agnostic chat message + optional image attachment.
import 'dart:convert';
import 'dart:typed_data';

enum AIMessageRole { user, assistant }

/// Binary attachment (image or PDF). `application/pdf` → Claude `document`
/// block, otherwise an `image` block.
class AIImageAttachment {
  final Uint8List bytes;
  final String mediaType;
  const AIImageAttachment({required this.bytes, required this.mediaType});
  bool get isPdf => mediaType == 'application/pdf';
}

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

  Map<String, dynamic> toClaudeJson() {
    if (images.isEmpty) {
      return {'role': role.name, 'content': text};
    }
    final content = <Map<String, dynamic>>[];
    for (final att in images) {
      content.add({
        'type': att.isPdf ? 'document' : 'image',
        'source': {
          'type': 'base64',
          'media_type': att.mediaType,
          'data': base64Encode(att.bytes),
        },
      });
    }
    if (text.isNotEmpty) content.add({'type': 'text', 'text': text});
    return {'role': role.name, 'content': content};
  }
}
