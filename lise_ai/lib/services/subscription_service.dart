import 'dart:convert';
import '../services/storage_service.dart';

// ── SubscriptionTier ──────────────────────────────────────────────────────────

enum SubscriptionTier {
  free,     // limited daily questions
  premium,  // unlimited all features
  family,   // premium for up to 5 accounts
}

extension SubscriptionTierExt on SubscriptionTier {
  String get label => switch (this) {
        SubscriptionTier.free    => 'Ücretsiz',
        SubscriptionTier.premium => 'Premium',
        SubscriptionTier.family  => 'Aile',
      };

  bool get isPaid => this != SubscriptionTier.free;
}

// ── Entitlement ───────────────────────────────────────────────────────────────

enum Entitlement {
  /// Unlimited chat questions per day (free = 10/day cap).
  unlimitedChat,

  /// PDF upload and multi-page analysis.
  pdfUpload,

  /// Realtime voice mode (STT + TTS streaming).
  voiceMode,

  /// Advanced local analytics and weekly report.
  advancedAnalytics,

  /// Exam camp mode.
  examCamp,

  /// Cloud sync across devices.
  cloudSync,

  /// Family sharing (up to 5 sub-accounts).
  familySharing,

  /// Priority Claude model selection (Opus vs Sonnet).
  priorityModel,
}

// ── Entitlement tables per tier ────────────────────────────────────────────────

const _freeEntitlements = <Entitlement>{
  Entitlement.voiceMode,  // basic voice — limited
  Entitlement.examCamp,
};

const _premiumEntitlements = <Entitlement>{
  Entitlement.unlimitedChat,
  Entitlement.pdfUpload,
  Entitlement.voiceMode,
  Entitlement.advancedAnalytics,
  Entitlement.examCamp,
  Entitlement.cloudSync,
  Entitlement.priorityModel,
};

const _familyEntitlements = <Entitlement>{
  Entitlement.unlimitedChat,
  Entitlement.pdfUpload,
  Entitlement.voiceMode,
  Entitlement.advancedAnalytics,
  Entitlement.examCamp,
  Entitlement.cloudSync,
  Entitlement.familySharing,
  Entitlement.priorityModel,
};

// ── SubscriptionStatus ────────────────────────────────────────────────────────

class SubscriptionStatus {
  final SubscriptionTier tier;
  final DateTime? validUntil;       // null = free tier
  final String? transactionId;      // StoreKit/Play transaction ref
  final bool isTrialActive;
  final DateTime? trialEndsAt;

  const SubscriptionStatus({
    this.tier = SubscriptionTier.free,
    this.validUntil,
    this.transactionId,
    this.isTrialActive = false,
    this.trialEndsAt,
  });

  bool get isActive =>
      tier == SubscriptionTier.free ||
      (validUntil != null && validUntil!.isAfter(DateTime.now()));

  bool get isExpired =>
      tier != SubscriptionTier.free &&
      (validUntil == null || validUntil!.isBefore(DateTime.now()));

  Set<Entitlement> get entitlements => switch (tier) {
        SubscriptionTier.free    => _freeEntitlements,
        SubscriptionTier.premium => _premiumEntitlements,
        SubscriptionTier.family  => _familyEntitlements,
      };

  bool hasEntitlement(Entitlement e) => entitlements.contains(e);

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'validUntil': validUntil?.toIso8601String(),
        'transactionId': transactionId,
        'isTrialActive': isTrialActive,
        'trialEndsAt': trialEndsAt?.toIso8601String(),
      };

  factory SubscriptionStatus.fromJson(Map<String, dynamic> j) =>
      SubscriptionStatus(
        tier: SubscriptionTier.values.firstWhere(
          (t) => t.name == j['tier'],
          orElse: () => SubscriptionTier.free,
        ),
        validUntil: j['validUntil'] != null
            ? DateTime.tryParse(j['validUntil'] as String)
            : null,
        transactionId: j['transactionId'] as String?,
        isTrialActive: j['isTrialActive'] as bool? ?? false,
        trialEndsAt: j['trialEndsAt'] != null
            ? DateTime.tryParse(j['trialEndsAt'] as String)
            : null,
      );
}

// ── SubscriptionService ───────────────────────────────────────────────────────

class SubscriptionService {
  static const _kKey = 'subscription_v1';

  SubscriptionStatus _status = const SubscriptionStatus();
  SubscriptionStatus get status => _status;
  SubscriptionTier get tier => _status.tier;

  // Convenience shortcuts
  bool get isPremium => _status.tier.isPaid && _status.isActive;
  bool get isFree    => !isPremium;

  // Daily question counter (free tier)
  static const int _freeDailyLimit = 10;
  int _todayQuestionCount = 0;
  String _lastCountDate = '';

  bool get canAskQuestion {
    if (isPremium) return true;
    _ensureDailyReset();
    return _todayQuestionCount < _freeDailyLimit;
  }

  int get questionsRemainingToday {
    if (isPremium) return -1; // unlimited
    _ensureDailyReset();
    return (_freeDailyLimit - _todayQuestionCount).clamp(0, _freeDailyLimit);
  }

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init(StorageService storage) async {
    final raw = storage.loadSetting(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _status = SubscriptionStatus.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _status = const SubscriptionStatus();
      }
    }
  }

  // ── Entitlement check ────────────────────────────────────────────────────────

  bool hasEntitlement(Entitlement e) => _status.hasEntitlement(e);

  // ── Purchase flow (stub) ──────────────────────────────────────────────────────

  /// Begin purchase for the given tier. In production, wire to StoreKit/Play.
  /// Returns true if subscription was successfully activated.
  Future<bool> purchase(
    SubscriptionTier tier,
    StorageService storage,
  ) async {
    // TODO: integrate revenue_cat or in_app_purchase package
    // For now, immediately grant the tier (useful for TestFlight testing).
    _status = SubscriptionStatus(
      tier: tier,
      validUntil: DateTime.now().add(const Duration(days: 30)),
    );
    await _persist(storage);
    return true;
  }

  /// Restore purchases from StoreKit/Play (stub).
  Future<bool> restorePurchases(StorageService storage) async {
    // TODO: implement restore flow
    return false;
  }

  // ── Trial ────────────────────────────────────────────────────────────────────

  Future<void> startTrial(StorageService storage) async {
    final trialEnd = DateTime.now().add(const Duration(days: 7));
    _status = SubscriptionStatus(
      tier: SubscriptionTier.premium,
      validUntil: trialEnd,
      isTrialActive: true,
      trialEndsAt: trialEnd,
    );
    await _persist(storage);
  }

  // ── Daily counter ─────────────────────────────────────────────────────────────

  void recordQuestion() {
    _ensureDailyReset();
    _todayQuestionCount++;
  }

  void _ensureDailyReset() {
    final today = _dateKey(DateTime.now());
    if (_lastCountDate != today) {
      _lastCountDate = today;
      _todayQuestionCount = 0;
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _persist(StorageService storage) async {
    await storage.saveSetting(_kKey, jsonEncode(_status.toJson()));
  }
}
