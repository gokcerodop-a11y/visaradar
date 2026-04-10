import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'VisaRadar Premium',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _HeroSection(),
              const SizedBox(height: 28),
              _TrialBadge(),
              const SizedBox(height: 28),
              _FeaturesSection(),
              const SizedBox(height: 24),
              _PricingCard(),
              const SizedBox(height: 28),
              _CtaSection(),
              const SizedBox(height: 24),
              _LegalSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Section
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.brandTeal.withAlpha(60),
                AppColors.brandTeal.withAlpha(10),
              ],
            ),
            border: Border.all(
              color: AppColors.brandTeal.withAlpha(80),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.radar,
            color: AppColors.brandTeal,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Travel Smarter.',
          style: AppTextStyles.displayMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'VisaRadar keeps your trips legal, your stays calculated,\nand your documents ahead of schedule.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trial Badge
// ---------------------------------------------------------------------------

class _TrialBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.brandTeal.withAlpha(20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.brandTeal.withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 14, color: AppColors.brandTeal),
            const SizedBox(width: 6),
            Text(
              '${AppConstants.trialDays}-Day Free Trial — No charge today',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.brandTeal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Features Section
// ---------------------------------------------------------------------------

class _FeaturesSection extends StatelessWidget {
  static const _features = [
    (
      icon: Icons.calculate_outlined,
      title: 'Schengen Day Tracker',
      subtitle: 'Know exactly how many days you have left — always.',
    ),
    (
      icon: Icons.flight_takeoff_outlined,
      title: 'Border & Trip Logging',
      subtitle: 'Log every entry and exit. Build your full travel history.',
    ),
    (
      icon: Icons.public_outlined,
      title: 'Country Insights',
      subtitle: 'Visa requirements, rules, and entry guidance per country.',
    ),
    (
      icon: Icons.auto_awesome_outlined,
      title: 'Smart Travel Tools',
      subtitle: 'Upcoming: alerts, route planning, and more.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: _features.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          return Column(
            children: [
              _FeatureRow(icon: f.icon, title: f.title, subtitle: f.subtitle),
              if (i < _features.length - 1)
                const Divider(height: 24, color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandTeal.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.brandTeal, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_circle, color: AppColors.brandTeal, size: 18),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing Card
// ---------------------------------------------------------------------------

class _PricingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Text(
                  'Subscription',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withAlpha(80)),
                  ),
                  child: Text(
                    'Monthly',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _PricingRow(
            regionIcon: Icons.location_on,
            region: 'Türkiye',
            price: '₺${AppConstants.priceTryMonthly.toStringAsFixed(0)} / mo',
            note: 'Billed monthly after trial',
          ),
          const Divider(height: 1, indent: 68, color: AppColors.divider),
          _PricingRow(
            regionIcon: Icons.public,
            region: 'International',
            price: '€${AppConstants.priceEurMonthly.toStringAsFixed(2)} / mo',
            note: 'Billed monthly after trial',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({
    required this.regionIcon,
    required this.region,
    required this.price,
    required this.note,
    this.isLast = false,
  });
  final IconData regionIcon;
  final String region;
  final String price;
  final String note;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, isLast ? 16 : 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(regionIcon, color: AppColors.brandTeal, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(region, style: AppTextStyles.bodyMedium),
              Text(
                note,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            price,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.brandTeal,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA Section
// ---------------------------------------------------------------------------

class _CtaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('In-app purchase coming soon.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandTeal,
              foregroundColor: AppColors.brandNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Start ${AppConstants.trialDays}-Day Free Trial',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.brandNavy,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase restore coming soon.'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Text(
            'Restore Purchase',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Legal / Billing notes
// ---------------------------------------------------------------------------

class _LegalSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trial & Billing',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Your ${AppConstants.trialDays}-day free trial begins on the day you subscribe.\n'
            '• You will not be charged during the trial period.\n'
            '• After the trial, your subscription renews monthly at the applicable rate for your region.\n'
            '• Cancel anytime before the trial ends to avoid being charged.\n'
            '• No partial refunds for unused periods.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Payment is processed through the App Store or Google Play. '
            'Subscription management and cancellation is available in your device\'s account settings.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
