import 'dart:convert';
import '../services/storage_service.dart';

// ── Pricing constants (USD per unit) ─────────────────────────────────────────
// Based on Anthropic claude-sonnet-4-6 pricing (approximate, update as needed)

class _Pricing {
  static const double inputPer1MTokens  = 3.00;   // claude-sonnet-4-x input
  static const double outputPer1MTokens = 15.00;  // claude-sonnet-4-x output
  static const double imagePerCall      = 0.0016; // ~1600 tokens per image
  static const double ttsPerKiloChar    = 0.015;  // TTS cost per 1000 chars
}

// ── SessionCost ────────────────────────────────────────────────────────────────

class SessionCost {
  final int inputTokens;
  final int outputTokens;
  final int imageCallCount;
  final int ttsCharCount;
  final DateTime sessionDate;

  const SessionCost({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.imageCallCount = 0,
    this.ttsCharCount = 0,
    required this.sessionDate,
  });

  double get inputCostUsd   => inputTokens * _Pricing.inputPer1MTokens / 1_000_000;
  double get outputCostUsd  => outputTokens * _Pricing.outputPer1MTokens / 1_000_000;
  double get imageCostUsd   => imageCallCount * _Pricing.imagePerCall;
  double get ttsCostUsd     => ttsCharCount * _Pricing.ttsPerKiloChar / 1000;
  double get totalCostUsd   => inputCostUsd + outputCostUsd + imageCostUsd + ttsCostUsd;
  int    get totalTokens    => inputTokens + outputTokens;

  SessionCost operator +(SessionCost other) => SessionCost(
        inputTokens:    inputTokens + other.inputTokens,
        outputTokens:   outputTokens + other.outputTokens,
        imageCallCount: imageCallCount + other.imageCallCount,
        ttsCharCount:   ttsCharCount + other.ttsCharCount,
        sessionDate: sessionDate,
      );

  Map<String, dynamic> toJson() => {
        'inputTokens':    inputTokens,
        'outputTokens':   outputTokens,
        'imageCallCount': imageCallCount,
        'ttsCharCount':   ttsCharCount,
        'sessionDate':    sessionDate.toIso8601String(),
      };

  factory SessionCost.fromJson(Map<String, dynamic> j) => SessionCost(
        inputTokens:    j['inputTokens']    as int? ?? 0,
        outputTokens:   j['outputTokens']   as int? ?? 0,
        imageCallCount: j['imageCallCount'] as int? ?? 0,
        ttsCharCount:   j['ttsCharCount']   as int? ?? 0,
        sessionDate: DateTime.parse(j['sessionDate'] as String),
      );

  /// Human-readable cost string, e.g. "~$0.0042"
  String get displayCost {
    final c = totalCostUsd;
    if (c < 0.001) return '<\$0.001';
    return '~\$${c.toStringAsFixed(4)}';
  }
}

// ── AICostTracker ──────────────────────────────────────────────────────────────

class AICostTracker {
  static const _kKey = 'ai_cost_v1';

  // Current session accumulator.
  SessionCost _session = SessionCost(sessionDate: DateTime.now());

  // Historical daily costs (date string → serialized SessionCost).
  final Map<String, SessionCost> _dailyCosts = {};

  SessionCost get currentSession => _session;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          _dailyCosts[entry.key] =
              SessionCost.fromJson(entry.value as Map<String, dynamic>);
        }
      } catch (_) {
        // ignore corrupt data
      }
    }
  }

  // ── Record ──────────────────────────────────────────────────────────────────

  /// Estimate token counts from text using the ~4 chars/token heuristic.
  static int estimateTokens(String text) => (text.length / 4).ceil();

  void recordChatTurn({
    required String systemPrompt,
    required List<Map<String, dynamic>> history,
    required String reply,
  }) {
    // Estimate input: system prompt + full history.
    final inputText = systemPrompt + history.map((m) => m['content'] ?? '').join(' ');
    final inputTok = estimateTokens(inputText.toString());
    final outputTok = estimateTokens(reply);

    _session = SessionCost(
      inputTokens:    _session.inputTokens + inputTok,
      outputTokens:   _session.outputTokens + outputTok,
      imageCallCount: _session.imageCallCount,
      ttsCharCount:   _session.ttsCharCount,
      sessionDate:    _session.sessionDate,
    );
  }

  void recordImageAnalysis() {
    _session = SessionCost(
      inputTokens:    _session.inputTokens,
      outputTokens:   _session.outputTokens,
      imageCallCount: _session.imageCallCount + 1,
      ttsCharCount:   _session.ttsCharCount,
      sessionDate:    _session.sessionDate,
    );
  }

  void recordTts(int charCount) {
    _session = SessionCost(
      inputTokens:    _session.inputTokens,
      outputTokens:   _session.outputTokens,
      imageCallCount: _session.imageCallCount,
      ttsCharCount:   _session.ttsCharCount + charCount,
      sessionDate:    _session.sessionDate,
    );
  }

  // ── Persist ─────────────────────────────────────────────────────────────────

  Future<void> persistSession(StorageService storage) async {
    final dateKey = _dateKey(_session.sessionDate);
    final existing = _dailyCosts[dateKey];
    _dailyCosts[dateKey] = existing != null ? existing + _session : _session;
    await storage.saveSetting(
      _kKey,
      jsonEncode(
        _dailyCosts.map((k, v) => MapEntry(k, v.toJson())),
      ),
    );
  }

  // ── Aggregates ──────────────────────────────────────────────────────────────

  SessionCost dailyCost({DateTime? date}) {
    final key = _dateKey(date ?? DateTime.now());
    return _dailyCosts[key] ?? SessionCost(sessionDate: date ?? DateTime.now());
  }

  SessionCost monthlyCost({DateTime? month}) {
    final m = month ?? DateTime.now();
    final prefix = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    SessionCost total = SessionCost(sessionDate: m);
    for (final entry in _dailyCosts.entries) {
      if (entry.key.startsWith(prefix)) {
        total = total + entry.value;
      }
    }
    return total;
  }

  // ── Display helpers ──────────────────────────────────────────────────────────

  String get sessionCostDisplay   => _session.displayCost;
  String get dailyCostDisplay     => dailyCost().displayCost;
  String get monthlyCostDisplay   => monthlyCost().displayCost;
  int    get sessionTokens        => _session.totalTokens;

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
