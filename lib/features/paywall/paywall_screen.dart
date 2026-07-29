import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/premium_providers.dart';
import '../../services/subscription_service.dart';

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

    // Show purchase error snackbar if set by subscription service.
    final purchaseErr = subs.purchaseError;
    if (purchaseErr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(isTr
              ? 'Satın alma başarısız oldu. Lütfen tekrar deneyin.'
              : 'Purchase failed. Please try again.'),
        ));
        subs.clearError();
      });
    }

    final products = subs.products.toList();
    final hasProducts = products.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: isTr ? 'Kapat' : 'Close',
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
                    _unavailableNotice(subs, isTr),
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
              ? 'AI asistan (günde 40 soru), belge tarayıcı ve Türkiye kara '
                  'sınırı modunun kilidini aç.'
              : 'Unlock the AI assistant (40 questions/day), document scanner '
                  'and Turkey land border mode.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _benefits(bool isTr) {
    final items = isTr
        ? const [
            'AI Asistan (günde 40 soru)',
            'Güvenlik Tarayıcı',
            'Tax-Free Rehberi',
            'AI Tur Rehberi',
            'Belge Tarayıcı (pasaport, vize ve izin belgeleri)',
            'Derin Bilgi — SHA-256 konum kanıtı zinciri',
            'Türkiye kara sınırı modu',
          ]
        : const [
            'AI Assistant (40 questions/day)',
            'Security Scanner',
            'Tax-Free Guide',
            'AI Tour Guide',
            'Document Scanner (passport, visa & permits)',
            'Deep Record — SHA-256 location proof chain',
            'Turkey land border mode',
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

    final title = isAnnual
        ? (isTr ? 'Yıllık' : 'Annual')
        : (isTr ? 'Aylık' : 'Monthly');

    final subtitle = isAnnual
        ? (isTr ? 'En avantajlı · yıllık' : 'Best value · annual')
        : (isTr ? 'Aylık yenilenir' : 'Renews monthly');

    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle, ${p.price}',
      child: GestureDetector(
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
                        Flexible(
                          child: Text(title, style: AppTextStyles.titleLarge),
                        ),
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
              const SizedBox(width: 8),
              Flexible(
                child: Text(p.price, style: AppTextStyles.titleLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unavailableNotice(SubscriptionService subs, bool isTr) {
    // When the store is reachable but products failed to load (e.g. offline at
    // launch), show a retry button so the user doesn't need to reopen the paywall.
    final canRetry = subs.available;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isTr
                      ? 'Satın alma şu anda kullanılamıyor. İnternet bağlantını '
                          'kontrol et.'
                      : 'Purchases unavailable. Check your internet connection.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (canRetry) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => subs.queryProducts(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(isTr ? 'Tekrar Dene' : 'Retry'),
            ),
          ],
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
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: busy ? null : () => _handleRestore(subs, isTr),
                child: Text(isTr ? 'Satın Alımları Geri Yükle' : 'Restore'),
              ),
              Text('·',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              TextButton(
                onPressed: () => _openUrl(AppConstants.termsUrl),
                child: Text(isTr ? 'Şartlar' : 'Terms'),
              ),
              Text('·',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              TextButton(
                onPressed: () => _openUrl(AppConstants.privacyPolicyUrl),
                child: Text(isTr ? 'Gizlilik' : 'Privacy'),
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

  Future<void> _handleRestore(SubscriptionService subs, bool isTr) async {
    final found = await subs.restore();
    if (!mounted) return;
    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF1C2A3F),
        content: Text(isTr
            ? 'Geri yüklenecek satın alım bulunamadı.'
            : 'No purchases found to restore.'),
      ));
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
