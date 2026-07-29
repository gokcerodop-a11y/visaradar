// subscription_service.dart
// Apple StoreKit (in_app_purchase) wrapper for VisaRadar Premium.
//
// Two products: monthly + annual (auto-renewable). The Premium entitlement
// unlocks the AI Assistant,
// document scanner and border mode. The original transaction id is cached and
// sent as the Authorization bearer to the visaradar-proxy Worker, which
// performs authoritative Apple receipt validation.
//
// IMPORTANT (App Review 2.1b): the word "Premium" must only appear alongside a
// real, purchasable product. [isAvailable] + [products] gate that — the paywall
// never shows price/CTA copy unless the store returned live product details.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PremiumPlan { none, monthly, annual, lifetime }

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  static const productMonthly = 'com.visaradar.premium.monthly';
  static const productAnnual = 'com.visaradar.premium.annual';
  static const productLifetime = 'com.visaradar.premium.lifetime';

  static Set<String> get productIds => {productMonthly, productAnnual};

  static const _kCachedTxId = 'visaradar.premium.txId';
  static const _kCachedExpiresAt = 'visaradar.premium.expiresAt'; // epoch ms
  static const _kCachedPlan = 'visaradar.premium.plan';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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
  bool _restoreInFlight = false;
  String? _purchaseError;
  bool _lastRestoreFoundPurchases = false;
  Timer? _expiryTimer;

  // ── Public getters ────────────────────────────────────────────────

  bool get available => _available;
  bool get isPremium => _isPremium;
  PremiumPlan get plan => _plan;
  bool get purchaseInFlight => _purchaseInFlight || _restoreInFlight;
  String? get currentOriginalTransactionId => _originalTransactionId;
  DateTime? get expiresAt => _expiresAt;

  /// Non-null while a purchase error is pending display; call [clearError] once shown.
  String? get purchaseError => _purchaseError;

  void clearError() {
    _purchaseError = null;
  }

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
    _scheduleExpiryTimer();

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
    if (!_available || _purchaseInFlight || _restoreInFlight) return false;
    _purchaseInFlight = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    try {
      // All three products are bought via buyNonConsumable in in_app_purchase
      // (auto-renewable subscriptions included).
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (!ok) {
        _purchaseError = 'purchase-failed';
        _purchaseInFlight = false;
        notifyListeners();
      }
      return ok;
    } catch (e) {
      debugPrint('[SubscriptionService] buy failed: $e');
      _purchaseError = 'purchase-failed';
      _purchaseInFlight = false;
      notifyListeners();
      return false;
    }
  }

  /// Restore prior purchases. Returns true if at least one purchase was found.
  Future<bool> restore() async {
    if (!_available || _purchaseInFlight || _restoreInFlight) return false;
    _restoreInFlight = true;
    _lastRestoreFoundPurchases = false;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // Allow stream to deliver restored events before checking the flag.
      await Future.delayed(const Duration(milliseconds: 800));
      _restoreInFlight = false;
      final found = _lastRestoreFoundPurchases;
      notifyListeners();
      return found;
    } catch (e) {
      debugPrint('[SubscriptionService] restore failed: $e');
      _restoreInFlight = false;
      notifyListeners();
      return false;
    }
  }

  /// Re-evaluate expiry against the current clock; call on app resume.
  void refreshExpiry() {
    if (_plan == PremiumPlan.lifetime) return;
    if (_expiresAt != null) {
      final wasActive = _isPremium;
      _isPremium = _expiresAt!.isAfter(DateTime.now());
      if (wasActive != _isPremium) notifyListeners();
    }
    _scheduleExpiryTimer();
  }

  /// Clear local premium entitlement when the Worker signals a revocation/refund.
  Future<void> revokeEntitlement() async {
    await debugReset();
  }

  // ── Internal purchase handling ────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _purchaseInFlight = true;
          break;
        case PurchaseStatus.purchased:
          await _activate(p);
          _purchaseInFlight = false;
          break;
        case PurchaseStatus.restored:
          _lastRestoreFoundPurchases = true;
          await _activate(p);
          _purchaseInFlight = false;
          break;
        case PurchaseStatus.canceled:
          _purchaseInFlight = false;
          break;
        case PurchaseStatus.error:
          _purchaseError = p.error?.message ?? 'purchase-failed';
          debugPrint('[SubscriptionService] purchase error: ${p.error}');
          _purchaseInFlight = false;
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  // Decodes a StoreKit 2 JWS token and extracts the originalTransactionId.
  // Returns null if the input is not a valid JWS or lacks the field.
  String? _extractTxIdFromJws(String jws) {
    try {
      final parts = jws.split('.');
      if (parts.length != 3) return null;
      String padded = parts[1];
      padded += '=' * ((4 - padded.length % 4) % 4);
      padded = padded.replaceAll('-', '+').replaceAll('_', '/');
      final payload = jsonDecode(utf8.decode(base64.decode(padded))) as Map<String, dynamic>;
      return payload['originalTransactionId']?.toString();
    } catch (_) {
      return null;
    }
  }

  // Decodes a StoreKit 2 JWS token and extracts the revocationDate (epoch ms).
  // Returns non-null when Apple has flagged the transaction as revoked or refunded.
  DateTime? _extractRevocationDateFromJws(String jws) {
    try {
      final parts = jws.split('.');
      if (parts.length != 3) return null;
      String padded = parts[1];
      padded += '=' * ((4 - padded.length % 4) % 4);
      padded = padded.replaceAll('-', '+').replaceAll('_', '/');
      final payload = jsonDecode(utf8.decode(base64.decode(padded))) as Map<String, dynamic>;
      final revokeMs = payload['revocationDate'];
      if (revokeMs == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((revokeMs as num).toInt());
    } catch (_) {
      return null;
    }
  }

  // Decodes a StoreKit 2 JWS token and extracts the real expiresDate (epoch ms).
  // Returns null for lifetime products (no expiresDate field) or on decode failure.
  DateTime? _extractExpiresDateFromJws(String jws) {
    try {
      final parts = jws.split('.');
      if (parts.length != 3) return null;
      String padded = parts[1];
      padded += '=' * ((4 - padded.length % 4) % 4);
      padded = padded.replaceAll('-', '+').replaceAll('_', '/');
      final payload = jsonDecode(utf8.decode(base64.decode(padded))) as Map<String, dynamic>;
      final expiresMs = payload['expiresDate'];
      if (expiresMs == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((expiresMs as num).toInt());
    } catch (_) {
      return null;
    }
  }

  Future<void> _activate(PurchaseDetails purchase) async {
    String txId = purchase.purchaseID ?? '';
    DateTime? jwsExpiresAt;
    if (Platform.isIOS) {
      // serverVerificationData on iOS is a StoreKit 2 JWS — decode it.
      final jws = purchase.verificationData.serverVerificationData;
      if (txId.isEmpty) txId = _extractTxIdFromJws(jws) ?? jws;
      // Use Apple's real expiresDate instead of a static duration offset.
      jwsExpiresAt = _extractExpiresDateFromJws(jws);
      // If Apple flagged this transaction as revoked/refunded, clear entitlement
      // and stop. Without this check, silent restore on cold launch would
      // re-activate a refunded lifetime purchase every session.
      if (_extractRevocationDateFromJws(jws) != null) {
        debugPrint('[SubscriptionService] purchase revoked by Apple, clearing entitlement');
        await revokeEntitlement();
        return;
      }
    }
    if (txId.isEmpty) {
      debugPrint('[SubscriptionService] purchase has no txId, skipping');
      return;
    }

    _originalTransactionId = txId;
    final now = DateTime.now();

    switch (purchase.productID) {
      case productLifetime:
        _plan = PremiumPlan.lifetime;
        _expiresAt = null;
        _isPremium = true;
        break;
      case productAnnual:
        _plan = PremiumPlan.annual;
        _expiresAt = jwsExpiresAt ?? now.add(const Duration(days: 366));
        // Guard against restoring an already-expired subscription.
        _isPremium = _expiresAt!.isAfter(now);
        break;
      case productMonthly:
      default:
        _plan = PremiumPlan.monthly;
        _expiresAt = jwsExpiresAt ?? now.add(const Duration(days: 31));
        _isPremium = _expiresAt!.isAfter(now);
        break;
    }
    _scheduleExpiryTimer();

    await _saveCachedState();
  }

  /// Schedules a one-shot timer to revoke premium precisely when [_expiresAt] passes.
  void _scheduleExpiryTimer() {
    _expiryTimer?.cancel();
    if (_plan == PremiumPlan.lifetime || _expiresAt == null) return;
    final delay = _expiresAt!.difference(DateTime.now());
    if (delay.isNegative) return;
    _expiryTimer = Timer(delay, () {
      _isPremium = false;
      notifyListeners();
    });
  }

  Future<void> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    // txId Keychain'den oku (güvenli depolama)
    final tx = await _storage.read(key: _kCachedTxId);
    // Eski SharedPreferences'tan migration: varsa sil ve Keychain'e taşı
    final legacyTx = prefs.getString(_kCachedTxId);
    if (tx == null && legacyTx != null && legacyTx.isNotEmpty) {
      await _storage.write(key: _kCachedTxId, value: legacyTx);
      await prefs.remove(_kCachedTxId);
    }
    final effectiveTx = tx ?? legacyTx;
    final exp = prefs.getInt(_kCachedExpiresAt);
    final planName = prefs.getString(_kCachedPlan);
    if (effectiveTx != null && effectiveTx.isNotEmpty) {
      // Migrate: if cached value is a JWS, decode it to the numeric transaction ID.
      final decoded = _extractTxIdFromJws(effectiveTx) ?? effectiveTx;
      _originalTransactionId = decoded;
      if (decoded != effectiveTx) await _storage.write(key: _kCachedTxId, value: decoded);
    }
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
    // txId (Bearer token) → iOS Keychain (şifreli)
    if (_originalTransactionId != null) {
      await _storage.write(key: _kCachedTxId, value: _originalTransactionId!);
    }
    // Plan ve bitiş tarihi SharedPreferences'ta (kişisel olmayan veri)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedPlan, _plan.name);
    if (_expiresAt != null) {
      await prefs.setInt(_kCachedExpiresAt, _expiresAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kCachedExpiresAt);
    }
  }

  /// Clears cached entitlement from Keychain and SharedPreferences.
  /// Called directly for debug resets and via [revokeEntitlement] for production revocations.
  Future<void> debugReset() async {
    _expiryTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await _storage.delete(key: _kCachedTxId);
    await prefs.remove(_kCachedTxId); // legacy migration temizliği
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
    _expiryTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
