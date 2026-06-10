import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/premium_providers.dart';
import '../../services/subscription_service.dart';
import '../profile/presentation/providers/profile_provider.dart';

/// Premium paywall. Critically (App Review 2.1b): pricing/CTA copy is only
/// rendered when the App Store returns live [ProductDetails]. When products are
/// unavailable we show benefits + an "unavailable" notice — never a fake price.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = SubscriptionService.productAnnual;
  bool _showLifetime = false;

  @override
  void initState() {
    super.initState();
    _resolveLifetimeEligibility();
  }

  Future<void> _resolveLifetimeEligibility() async {
    // Lifetime is only offered after 3 days of use (per pricing strategy).
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(AppConstants.keyInstallDate);
    final installed =
        iso != null ? DateTime.tryParse(iso) : null;
    final eligible = installed != null &&
        DateTime.now().difference(installed).inDays >= 3;
    if (mounted) setState(() => _showLifetime = eligible);
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(isTurkishProvider);
    final subs = ref.watch(subscriptionProvider);
    final isPremium = ref.watch(isPremiumProvider);

    // Auto-close once entitlement is granted.
    if (isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context, true);
      });
    }

    final products = subs.products
        .where((p) =>
            _showLifetime || p.id != SubscriptionService.productLifetime)
        .toList();
    final hasProducts = products.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _header(isTr),
                  const SizedBox(height: 24),
                  _benefits(isTr),
                  const SizedBox(height: 24),
                  if (hasProducts)
                    ...products.map((p) => _planCard(p, isTr))
                  else
                    _unavailableNotice(isTr),
                ],
              ),
            ),
            if (hasProducts) _ctaBar(subs, isTr),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isTr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandTeal, AppColors.info],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.bolt, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          'VisaRadar Travel Premium',
          style: AppTextStyles.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isTr
              ? 'Yapay zekâ seyahat asistanı, belge tarayıcı ve sınır modunun '
                  'kilidini aç.'
              : 'Unlock the AI travel assistant, document scanner and border mode.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _benefits(bool isTr) {
    final items = isTr
        ? const [
            'Yapay zekâ asistanına sınırsız soru',
            'Pasaport, vize ve izin belgesi tarayıcı',
            'Sınıra yaklaşınca otomatik sınır modu',
            'Seyahat tarzına özel akıllı ipuçları',
          ]
        : const [
            'Unlimited questions to the AI assistant',
            'Passport, visa & permit document scanner',
            'Automatic border mode when you approach',
            'Smart tips tailored to your travel style',
          ];
    return Column(
      children: [
        for (final b in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.brandTeal, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(b, style: AppTextStyles.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _planCard(ProductDetails p, bool isTr) {
    final selected = _selected == p.id;
    final isAnnual = p.id == SubscriptionService.productAnnual;
    final isLifetime = p.id == SubscriptionService.productLifetime;

    final title = isLifetime
        ? (isTr ? 'Ömür Boyu' : 'Lifetime')
        : isAnnual
            ? (isTr ? 'Yıllık' : 'Annual')
            : (isTr ? 'Aylık' : 'Monthly');

    final subtitle = isAnnual
        ? (isTr ? '3 gün ücretsiz dene · en avantajlı' : '3-day free trial · best value')
        : isLifetime
            ? (isTr ? 'Tek seferlik ödeme' : 'One-time payment')
            : (isTr ? 'Aylık yenilenir' : 'Renews monthly');

    return GestureDetector(
      onTap: () => setState(() => _selected = p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brandTeal : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.brandTeal : AppColors.textMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTextStyles.titleLarge),
                      if (isAnnual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isTr ? 'EN POPÜLER' : 'MOST POPULAR',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.brandNavy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(p.price, style: AppTextStyles.titleLarge),
          ],
        ),
      ),
    );
  }

  Widget _unavailableNotice(bool isTr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isTr
                  ? 'Satın alma şu anda kullanılamıyor. Lütfen daha sonra '
                      'tekrar deneyin.'
                  : 'Purchases are currently unavailable. Please try again later.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaBar(SubscriptionService subs, bool isTr) {
    final product = subs.productById(_selected) ?? subs.products.first;
    final busy = subs.purchaseInFlight;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : () => subs.buy(product),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isTr ? 'Devam Et' : 'Continue'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: busy ? null : () => subs.restore(),
                child: Text(isTr ? 'Satın Alımları Geri Yükle' : 'Restore'),
              ),
              Text('·',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              TextButton(
                onPressed: () => _openTerms(isTr),
                child: Text(isTr ? 'Şartlar' : 'Terms'),
              ),
            ],
          ),
          Text(
            isTr
                ? 'Abonelik otomatik yenilenir; istediğin zaman App Store\'dan '
                    'iptal edebilirsin.'
                : 'Subscription auto-renews; cancel anytime in the App Store.',
            textAlign: TextAlign.center,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _openTerms(bool isTr) {
    // Profile read kept for future locale-aware legal routing.
    ref.read(profileProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isTr
            ? 'Şartlar Profil > Yasal bölümünde.'
            : 'Terms are in Profile > Legal.'),
      ),
    );
  }
}
