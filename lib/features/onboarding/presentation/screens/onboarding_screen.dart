import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../screens/consent_gate_screen.dart' show isConsentGiven;
import '../../../../shared/widgets/country_code_badge.dart';
import '../../../profile/domain/data/countries.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentStep = 0;
  bool _saving = false;

  // Step indices
  static const int _languageStep = 0;
  static const int _nationalityStep = 1;
  static const int _totalSteps = 2;

  // Collected profile data
  String? _nationality;
  String? _nationalityLabel;
  String? _preferredLocale;

  // Passport type, residence status and travel mode are no longer asked
  // during onboarding — they default to sensible values and can be changed
  // later in Settings → Travel Profile.
  static const PassportType _passportType = PassportType.ordinary;
  static const ResidenceStatus _residenceStatus = ResidenceStatus.none;
  static const TravelMode _travelMode = TravelMode.plane;

  bool get _canContinue {
    if (_saving) return false;
    if (_currentStep == _languageStep && _preferredLocale == null) {
      return false;
    }
    if (_currentStep == _nationalityStep && _nationality == null) return false;
    return true;
  }

  void _next() {
    if (!_canContinue) return;
    if (_currentStep < _totalSteps - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    final profile = UserProfile(
      nationality: _nationality,
      nationalityLabel: _nationalityLabel,
      passportType: _passportType,
      residenceStatus: _residenceStatus,
      travelMode: _travelMode,
      preferredLocale: _preferredLocale,
    );
    await ref.read(profileProvider.notifier).completeOnboarding(profile);
    // First the KVKK consent gate (if not yet accepted), then the welcome
    // tour — the gate itself continues to the tour on acceptance.
    final consentGiven = await isConsentGiven();
    if (!mounted) return;
    context.go(consentGiven ? AppRoutes.welcomeTour : AppRoutes.consentGate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Short bilingual helper. After step 0 the locale is guaranteed non-null;
  // on step 0 the screen is bilingual by design so this helper is unused.
  String _t(String en, String tr) => _preferredLocale == 'tr' ? tr : en;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.brandNavy,
        body: SafeArea(
          child: Column(
            children: [
              _StepHeader(
                current: _currentStep,
                total: _totalSteps,
                isTr: _preferredLocale == 'tr',
                onBack: _currentStep > 0 ? _back : null,
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    _WelcomeLanguagePage(
                      selected: _preferredLocale,
                      onSelect: (code) =>
                          setState(() => _preferredLocale = code),
                    ),
                    _NationalityPage(
                      locale: _preferredLocale,
                      selected: _nationality,
                      onSelect: (code, label) => setState(() {
                        _nationality = code;
                        _nationalityLabel = label;
                      }),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                saving: _saving,
                canContinue: _canContinue,
                isLastStep: _currentStep == _totalSteps - 1,
                onContinue: _next,
                continueLabel: _continueLabel(),
                hint: _bottomHint(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _continueLabel() {
    final isLast = _currentStep == _totalSteps - 1;
    // Step 0 before language pick: show both, neutral.
    if (_currentStep == _languageStep && _preferredLocale == null) {
      return 'Continue · Devam';
    }
    if (isLast) return _t('Get Started', 'Başla');
    return _t('Continue', 'Devam');
  }

  String? _bottomHint() {
    if (_currentStep == _languageStep && _preferredLocale == null) {
      return 'Select a language · Bir dil seçin';
    }
    if (_currentStep == _nationalityStep && _nationality == null) {
      return _t(
        'Select your country to continue',
        'Devam etmek için ülkenizi seçin',
      );
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Bottom bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.saving,
    required this.canContinue,
    required this.isLastStep,
    required this.onContinue,
    required this.continueLabel,
    this.hint,
  });

  final bool saving;
  final bool canContinue;
  final bool isLastStep;
  final VoidCallback onContinue;
  final String continueLabel;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null) ...[
            Text(
              hint!,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canContinue ? onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                foregroundColor: AppColors.brandNavy,
                disabledBackgroundColor: AppColors.brandTeal.withAlpha(70),
                disabledForegroundColor: AppColors.brandNavy.withAlpha(180),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandNavy,
                      ),
                    )
                  : Text(
                      isLastStep ? continueLabel : continueLabel,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.brandNavy,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step header (progress bar + back button)
// ---------------------------------------------------------------------------

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.current,
    required this.total,
    required this.isTr,
    required this.onBack,
  });

  final int current;
  final int total;
  final bool isTr;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: onBack != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              label: isTr
                  ? 'Adım ${current + 1}, toplam $total'
                  : 'Step ${current + 1} of $total',
              child: Row(
                children: List.generate(total, (i) {
                  final active = i <= current;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      height: 3,
                      margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.brandTeal : AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 0: Welcome + Language (bilingual)
// ---------------------------------------------------------------------------

class _WelcomeLanguagePage extends StatelessWidget {
  const _WelcomeLanguagePage({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _FadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandTeal.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brandTeal.withAlpha(60),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.radar,
                color: AppColors.brandTeal,
                size: 44,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Welcome to VisaRadar',
              style: AppTextStyles.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "VisaRadar'a Hoşgeldiniz",
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              'Choose your language',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Dilinizi seçin',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _LanguageCard(
              flag: '🇬🇧',
              title: 'English',
              subtitle: 'Continue in English',
              isSelected: selected == 'en',
              onTap: () => onSelect('en'),
            ),
            const SizedBox(height: 12),
            _LanguageCard(
              flag: '🇹🇷',
              title: 'Türkçe',
              subtitle: 'Türkçe ile devam et',
              isSelected: selected == 'tr',
              onTap: () => onSelect('tr'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String flag;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandTeal.withAlpha(20)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.brandTeal : AppColors.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  shape: BoxShape.circle,
                ),
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.brandTeal,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: Nationality
// ---------------------------------------------------------------------------

class _NationalityPage extends StatefulWidget {
  const _NationalityPage({
    required this.locale,
    required this.selected,
    required this.onSelect,
  });

  final String? locale;
  final String? selected;
  final void Function(String code, String label) onSelect;

  @override
  State<_NationalityPage> createState() => _NationalityPageState();
}

class _NationalityPageState extends State<_NationalityPage> {
  final _searchController = TextEditingController();
  String _query = '';

  bool get _isTr => widget.locale == 'tr';

  List<Country> get _filtered {
    if (_query.isEmpty) return kCountries;
    final q = _query.toLowerCase();
    return kCountries
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return _FadeIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTr ? 'Vatandaşlığınız' : 'Your Nationality',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _isTr
                      ? 'Pasaportunuzu veren ülkeyi seçin.'
                      : 'Select the country that issued your passport.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: _isTr ? 'Ülke ara…' : 'Search country…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? Semantics(
                            button: true,
                            label: _isTr ? 'Aramayı temizle' : 'Clear search',
                            child: GestureDetector(
                              onTap: _clearSearch,
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _isTr ? 'Ülke bulunamadı' : 'No countries found',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final country = filtered[i];
                  final isSelected = country.code == widget.selected;
                  return _CountryRow(
                    country: country,
                    isSelected: isSelected,
                    onTap: () => widget.onSelect(country.code, country.name),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final Country country;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.brandTeal.withAlpha(15),
        highlightColor: AppColors.brandTeal.withAlpha(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: isSelected
              ? BoxDecoration(
                  color: AppColors.brandTeal.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.brandTeal.withAlpha(60),
                    width: 1,
                  ),
                )
              : const BoxDecoration(),
          child: Row(
            children: [
              CountryCodeBadge(code: country.code, highlighted: isSelected),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  country.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.brandTeal,
                  size: 18,
                )
              else
                const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtle fade-in transition wrapper used on every page for premium feel.
// ---------------------------------------------------------------------------

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
