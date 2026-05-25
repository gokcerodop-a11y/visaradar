import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:omnicore_foundation/omnicore_foundation.dart' show KeyValueStorage;

// ── Plain data classes (no code-gen needed) ───────────────────────────────────

class ConversationMeta {
  final String id;
  final String title;
  final DateTime createdAt;

  const ConversationMeta({
    required this.id,
    required this.title,
    required this.createdAt,
  });
}

class StoredMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final Uint8List? imageBytes;
  final DateTime timestamp;

  const StoredMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.imageBytes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'isError': isError,
        'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory StoredMessage.fromJson(Map<String, dynamic> j) => StoredMessage(
        text: (j['text'] as String?) ?? '',
        isUser: (j['isUser'] as bool?) ?? false,
        isError: (j['isError'] as bool?) ?? false,
        imageBytes: j['imageBytes'] != null
            ? base64Decode(j['imageBytes'] as String)
            : null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (j['timestamp'] as int?) ?? 0),
      );
}

class StoredConversation {
  final String id;
  String title;
  final DateTime createdAt;
  final List<StoredMessage> messages;

  StoredConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory StoredConversation.fromJson(Map<String, dynamic> j) =>
      StoredConversation(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? 'Sohbet',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as int?) ?? 0),
        messages: ((j['messages'] as List?) ?? [])
            .map((m) => StoredMessage.fromJson(
                Map<String, dynamic>.from(m as Map)))
            .toList(),
      );

  ConversationMeta get meta =>
      ConversationMeta(id: id, title: title, createdAt: createdAt);
}

// ── Storage service ────────────────────────────────────────────────────────────

class StorageService implements KeyValueStorage {
  static const _boxName = 'lise_ai_v1';
  static const _indexKey = 'index';

  late Box _box;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // ── Index helpers ─────────────────────────────────────────────────────────

  List<String> _readIndex() {
    final raw = _box.get(_indexKey);
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  Future<void> _writeIndex(List<String> ids) => _box.put(_indexKey, ids);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns all conversations, newest first.
  Future<List<ConversationMeta>> listConversations() async {
    final index = _readIndex();
    final result = <ConversationMeta>[];
    for (final id in index.reversed) {
      final raw = _box.get('conv_$id') as String?;
      if (raw != null) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          result.add(ConversationMeta(
            id: id,
            title: (map['title'] as String?) ?? 'Sohbet',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
                (map['createdAt'] as int?) ?? 0),
          ));
        } catch (_) {}
      }
    }
    return result;
  }

  Future<StoredConversation?> loadConversation(String id) async {
    final raw = _box.get('conv_$id') as String?;
    if (raw == null) return null;
    try {
      return StoredConversation.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConversation(StoredConversation conv) async {
    final index = _readIndex();
    if (!index.contains(conv.id)) {
      index.add(conv.id);
      await _writeIndex(index);
    }
    await _box.put('conv_${conv.id}', jsonEncode(conv.toJson()));
  }

  Future<void> deleteConversation(String id) async {
    final index = _readIndex();
    index.remove(id);
    await _writeIndex(index);
    await _box.delete('conv_$id');
  }

  String generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  // ── App settings (mode, level) ────────────────────────────────────────────
  // Implements KeyValueStorage so memory + session services in
  // omnicore_memory / omnicore_session can depend on the abstract
  // interface instead of this concrete LiseAI service.

  @override
  Future<void> saveSetting(String key, String value) =>
      _box.put('setting_$key', value);

  @override
  String? loadSetting(String key) =>
      _box.get('setting_$key') as String?;

  @override
  Future<void> deleteSetting(String key) => _box.delete('setting_$key');
}
