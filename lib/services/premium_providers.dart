import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_service.dart';

/// Singleton StoreKit wrapper exposed as a [ChangeNotifierProvider] so the UI
/// rebuilds whenever entitlement / product state changes. [init] kicks off the
/// store query + silent restore once, on first read.
final subscriptionProvider = ChangeNotifierProvider<SubscriptionService>((ref) {
  final s = SubscriptionService.instance;
  // Fire-and-forget; notifyListeners() updates watchers when it resolves.
  s.init();
  return s;
});

/// The single source of truth for gating Premium features.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPremium;
});

/// True once the App Store has returned live product details — required before
/// any "Premium" pricing/CTA copy may be shown (App Review 2.1b).
final hasPremiumProductsProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).products.isNotEmpty;
});

/// Bearer token (original transaction id) for authenticated Worker calls.
final premiumBearerProvider = Provider<String?>((ref) {
  return ref.watch(subscriptionProvider).currentOriginalTransactionId;
});
