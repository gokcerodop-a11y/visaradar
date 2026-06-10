// subscription_service.dart
// Apple StoreKit (in_app_purchase) wrapper for VisaRadar Premium.
//
// Three products: monthly + annual (auto-renewable) and lifetime
// (non-consumable). The Premium entitlement unlocks the AI Assistant,
// document scanner and border mode. The original transaction id is cached and
// sent as the Authorization bearer to the visaradar-proxy Worker, which
// performs authoritative Apple receipt validation.
//
// IMPORTANT (App Review 2.1b): the word "Premium" must only appear alongside a
// real, purchasable product. [isAvailable] + [products] gate that — the paywall
// never shows price/CTA copy unless the store returned live product details.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PremiumPlan { none, monthly, annual, lifetime }

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  static const productMonthly = 'com.visaradar.premium.monthly';
  static const productAnnual = 'com.visaradar.premium.annual';
  static const productLifetime = 'com.visaradar.premium.lifetime';

  static Set<String> get productIds =>
      {productMonthly, productAnnual, productLifetime};

  static const _kCachedTxId = 'visaradar.premium.txId';
  static const _kCachedExpiresAt = 'visaradar.premium.expiresAt'; // epoch ms
  static const _kCachedPlan = 'visaradar.premium.plan';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _initialized = false;

  bool _available = false;
  bool _isPremium = false;
  PremiumPlan _plan = PremiumPlan.none;
  String? _originalTransactionId;
  DateTime? _expiresAt;
  List<ProductDetails> _products = const [];
  bool _purchaseInFlight = false;

  // ── Public getters ────────────────────────────────────────────────

  bool get available => _available;
  bool get isPremium => _isPremium;
  PremiumPlan get plan => _plan;
  bool get purchaseInFlight => _purchaseInFlight;
  String? get currentOriginalTransactionId => _originalTransactionId;
  DateTime? get expiresAt => _expiresAt;

  /// Live product details from the App Store, ordered monthly → annual →
  /// lifetime. Empty until the store responds (or on Simulator / no account).
  List<ProductDetails> get products {
    int rank(String id) => id == productMonthly
        ? 0
        : id == productAnnual
            ? 1
            : 2;
    final list = [..._products]..sort((a, b) => rank(a.id).compareTo(rank(b.id)));
    return list;
  }

  ProductDetails? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProductDetails? get monthly => productById(productMonthly);
  ProductDetails? get annual => productById(productAnnual);
  ProductDetails? get lifetime => productById(productLifetime);

  // ── Init ──────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadCachedState();

    _available = await _iap.isAvailable();
    if (!_available) {
      // Simulator / unsupported device — IAP unavailable but app still works.
      notifyListeners();
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () {},
      onError: (Object e) =>
          debugPrint('[SubscriptionService] purchase stream error: $e'),
    );

    await queryProducts();
    await _iap.restorePurchases(); // silent restore on launch
    notifyListeners();
  }

  // ── Product query ─────────────────────────────────────────────────

  Future<void> queryProducts() async {
    if (!_available) return;
    final resp = await _iap.queryProductDetails(productIds);
    if (resp.error != null) {
      debugPrint('[SubscriptionService] queryProductDetails: ${resp.error}');
    }
    if (resp.notFoundIDs.isNotEmpty) {
      debugPrint('[SubscriptionService] not found: ${resp.notFoundIDs}');
    }
    _products = resp.productDetails;
    notifyListeners();
  }

  // ── Purchase + restore ────────────────────────────────────────────

  /// Start a purchase. The result arrives asynchronously via [purchaseStream].
  Future<bool> buy(ProductDetails product) async {
    if (!_available) return false;
    _purchaseInFlight = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    try {
      // All three products are bought via buyNonConsumable in in_app_purchase
      // (auto-renewable subscriptions included).
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('[SubscriptionService] buy failed: $e');
      _purchaseInFlight = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> restore() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // ── Internal purchase handling ────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _purchaseInFlight = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _activate(p);
          _purchaseInFlight = false;
          break;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          debugPrint('[SubscriptionService] ${p.status.name}: ${p.error}');
          _purchaseInFlight = false;
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  Future<void> _activate(PurchaseDetails purchase) async {
    String txId = purchase.purchaseID ?? '';
    if (txId.isEmpty && Platform.isIOS) {
      txId = purchase.verificationData.serverVerificationData;
    }
    if (txId.isEmpty) {
      debugPrint('[SubscriptionService] purchase has no txId, skipping');
      return;
    }

    _originalTransactionId = txId;
    _isPremium = true;

    switch (purchase.productID) {
      case productLifetime:
        _plan = PremiumPlan.lifetime;
        _expiresAt = null; // forever
        break;
      case productAnnual:
        _plan = PremiumPlan.annual;
        _expiresAt = DateTime.now().add(const Duration(days: 366));
        break;
      case productMonthly:
      default:
        _plan = PremiumPlan.monthly;
        _expiresAt = DateTime.now().add(const Duration(days: 31));
        break;
    }

    await _saveCachedState();
  }

  Future<void> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    final tx = prefs.getString(_kCachedTxId);
    final exp = prefs.getInt(_kCachedExpiresAt);
    final planName = prefs.getString(_kCachedPlan);
    if (tx != null && tx.isNotEmpty) _originalTransactionId = tx;
    _plan = PremiumPlan.values.firstWhere(
      (e) => e.name == planName,
      orElse: () => PremiumPlan.none,
    );
    if (_plan == PremiumPlan.lifetime) {
      _isPremium = _originalTransactionId != null;
      _expiresAt = null;
    } else if (exp != null) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(exp);
      _isPremium = _expiresAt!.isAfter(DateTime.now());
    }
  }

  Future<void> _saveCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_originalTransactionId != null) {
      await prefs.setString(_kCachedTxId, _originalTransactionId!);
    }
    await prefs.setString(_kCachedPlan, _plan.name);
    if (_expiresAt != null) {
      await prefs.setInt(_kCachedExpiresAt, _expiresAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kCachedExpiresAt);
    }
  }

  /// Debug only — clears cached entitlement.
  Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCachedTxId);
    await prefs.remove(_kCachedExpiresAt);
    await prefs.remove(_kCachedPlan);
    _originalTransactionId = null;
    _expiresAt = null;
    _isPremium = false;
    _plan = PremiumPlan.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
