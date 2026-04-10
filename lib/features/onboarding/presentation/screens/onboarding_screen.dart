import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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

  // Step index of the nationality page
  static const int _nationalityStep = 1;
  static const int _totalSteps = 7;

  // Collected profile data
  String? _nationality;
  String? _nationalityLabel;
  PassportType _passportType = PassportType.ordinary;
  ResidenceStatus _residenceStatus = ResidenceStatus.none;
  TravelMode _travelMode = TravelMode.plane;
  String? _preferredLocale;

  bool get _canContinue {
    if (_saving) return false;
    // Nationality must be selected before proceeding from step 1
    if (_currentStep == _nationalityStep && _nationality == null) return false;
    return true;
  }

  void _next() {
    if (!_canContinue) return;
    if (_currentStep < _totalSteps - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
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
    if (mounted) context.go('/main/radar');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _StepHeader(
                current: _currentStep,
                total: _totalSteps,
                onBack: _currentStep > 0 ? _back : null,
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    const _WelcomePage(),
                    _NationalityPage(
                      selected: _nationality,
                      onSelect: (code, label) => setState(() {
                        _nationality = code;
                        _nationalityLabel = label;
                      }),
                    ),
                    _SelectionPage<PassportType>(
                      title: 'Passport Type',
                      subtitle: 'Select the type of passport you travel with.',
                      options: const [
                        _SelectOption(
                          value: PassportType.ordinary,
                          icon: Icons.book_outlined,
                          title: 'Ordinary passport',
                          subtitle: 'Standard passport issued to citizens',
                        ),
                        _SelectOption(
                          value: PassportType.euEeaSwiss,
                          icon: Icons.flag_outlined,
                          title: 'EU / EEA / Swiss passport',
                          subtitle: 'Free movement within the Schengen area',
                        ),
                        _SelectOption(
                          value: PassportType.diplomatic,
                          icon: Icons.shield_outlined,
                          title: 'Diplomatic passport',
                          subtitle: 'Issued to diplomatic personnel',
                        ),
                        _SelectOption(
                          value: PassportType.serviceOfficial,
                          icon: Icons.badge_outlined,
                          title: 'Service / official passport',
                          subtitle: 'Issued for official government travel',
                        ),
                        _SelectOption(
                          value: PassportType.special,
                          icon: Icons.star_border_outlined,
                          title: 'Special passport',
                          subtitle: 'Other special-category passport',
                        ),
                      ],
                      selected: _passportType,
                      onChanged: (v) => setState(() => _passportType = v),
                    ),
                    _SelectionPage<ResidenceStatus>(
                      title: 'Residence Status',
                      subtitle: 'Do you hold a residence permit?',
                      options: const [
                        _SelectOption(
                          value: ResidenceStatus.none,
                          icon: Icons.person_outline,
                          title: 'No residence permit',
                          subtitle: 'Visiting on a tourist or short-stay visa',
                        ),
                        _SelectOption(
                          value: ResidenceStatus.euSchengenResident,
                          icon: Icons.home_outlined,
                          title: 'EU / Schengen residence permit',
                          subtitle: 'Long-stay visa or permit in a Schengen country',
                        ),
                        _SelectOption(
                          value: ResidenceStatus.otherResidenceStatus,
                          icon: Icons.location_city_outlined,
                          title: 'Other residence status',
                          subtitle: 'Permit outside the EU / Schengen area',
                        ),
                      ],
                      selected: _residenceStatus,
                      onChanged: (v) => setState(() => _residenceStatus = v),
                    ),
                    _SelectionPage<TravelMode>(
                      title: 'How do you travel?',
                      subtitle: 'Choose your primary mode of travel.',
                      options: const [
                        _SelectOption(
                          value: TravelMode.plane,
                          icon: Icons.flight_outlined,
                          title: 'Plane',
                          subtitle: 'Air travel',
                        ),
                        _SelectOption(
                          value: TravelMode.car,
                          icon: Icons.directions_car_outlined,
                          title: 'Car',
                          subtitle: 'Driving across borders',
                        ),
                        _SelectOption(
                          value: TravelMode.train,
                          icon: Icons.train_outlined,
                          title: 'Train',
                          subtitle: 'Rail travel',
                        ),
                        _SelectOption(
                          value: TravelMode.bus,
                          icon: Icons.directions_bus_outlined,
                          title: 'Bus',
                          subtitle: 'Coach or intercity bus',
                        ),
                        _SelectOption(
                          value: TravelMode.ferry,
                          icon: Icons.directions_boat_outlined,
                          title: 'Ferry',
                          subtitle: 'Sea crossing',
                        ),
                        _SelectOption(
                          value: TravelMode.camperCaravan,
                          icon: Icons.rv_hookup_outlined,
                          title: 'Camper / caravan',
                          subtitle: 'Motorhome or caravan travel',
                        ),
                        _SelectOption(
                          value: TravelMode.motorcycle,
                          icon: Icons.two_wheeler_outlined,
                          title: 'Motorcycle',
                          subtitle: 'Motorbike travel',
                        ),
                        _SelectOption(
                          value: TravelMode.onFoot,
                          icon: Icons.directions_walk_outlined,
                          title: 'On foot',
                          subtitle: 'Hiking or walking across borders',
                        ),
                      ],
                      selected: _travelMode,
                      onChanged: (v) => setState(() => _travelMode = v),
                    ),
                    _LanguagePage(
                      selected: _preferredLocale,
                      onChanged: (v) => setState(() => _preferredLocale = v),
                    ),
                    const _PermissionsPage(),
                  ],
                ),
              ),
              _BottomBar(
                saving: _saving,
                canContinue: _canContinue,
                isLastStep: _currentStep == _totalSteps - 1,
                onContinue: _next,
                // Show hint on nationality step when nothing selected
                hint: _currentStep == _nationalityStep && _nationality == null
                    ? 'Select your country to continue'
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
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
    this.hint,
  });

  final bool saving;
  final bool canContinue;
  final bool isLastStep;
  final VoidCallback onContinue;
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
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            onPressed: canContinue ? onContinue : null,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandNavy,
                    ),
                  )
                : Text(isLastStep ? 'Get Started' : 'Continue'),
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
    required this.onBack,
  });

  final int current;
  final int total;
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
            child: Row(
              children: List.generate(total, (i) {
                final active = i <= current;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 3,
                    margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: active ? AppColors.brandTeal : AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.radar, color: AppColors.brandTeal, size: 44),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to VisaRadar',
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Know exactly where you stand — Schengen days counted,\nborder crossings logged, alerts sent before you overstay.',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          _FeatureRow(
            icon: Icons.timer_outlined,
            label: 'Accurate 90/180-day Schengen calculator',
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.notifications_outlined,
            label: 'Alerts before your allowance runs out',
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.lock_outline,
            label: 'Your data stays on your device only',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brandTeal.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.brandTeal, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Nationality
// ---------------------------------------------------------------------------

class _NationalityPage extends StatefulWidget {
  const _NationalityPage({
    required this.selected,
    required this.onSelect,
  });

  final String? selected;
  final void Function(String code, String label) onSelect;

  @override
  State<_NationalityPage> createState() => _NationalityPageState();
}

class _NationalityPageState extends State<_NationalityPage> {
  final _searchController = TextEditingController();
  String _query = '';

  List<Country> get _filtered {
    if (_query.isEmpty) return kCountries;
    final q = _query.toLowerCase();
    return kCountries
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q))
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Nationality', style: AppTextStyles.displayMedium),
              const SizedBox(height: 6),
              Text(
                'Select the country that issued your passport.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search country…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: _clearSearch,
                          child: const Icon(Icons.close, size: 18,
                              color: AppColors.textMuted),
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
                'No countries found',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
    );
  }
}

// A single country row — custom widget for full control over appearance.
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
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandTeal, size: 18)
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
// Page: Generic selection (passport type, residence, travel mode)
// ---------------------------------------------------------------------------

class _SelectOption<T> {
  const _SelectOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _SelectionPage<T> extends StatelessWidget {
  const _SelectionPage({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final List<_SelectOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          ...options.map((opt) => _SelectCard<T>(
                option: opt,
                isSelected: opt.value == selected,
                onTap: () => onChanged(opt.value),
              )),
        ],
      ),
    );
  }
}

class _SelectCard<T> extends StatelessWidget {
  const _SelectCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _SelectOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandTeal.withAlpha(18)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isSelected ? AppColors.brandTeal : AppColors.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandTeal.withAlpha(30)
                      : AppColors.brandNavy,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: isSelected
                      ? AppColors.brandTeal
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandTeal, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Language
// ---------------------------------------------------------------------------

class _LanguagePage extends StatelessWidget {
  const _LanguagePage({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Language', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text(
            'Choose the language you want VisaRadar to use.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          _LangOption(
            label: 'Automatic',
            sublabel: 'Follows your device language',
            isSelected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(height: 10),
          _LangOption(
            label: 'English',
            sublabel: 'English',
            isSelected: selected == 'en',
            onTap: () => onChanged('en'),
          ),
          const SizedBox(height: 10),
          _LangOption(
            label: 'Türkçe',
            sublabel: 'Turkish',
            isSelected: selected == 'tr',
            onTap: () => onChanged('tr'),
          ),
          const SizedBox(height: 20),
          Text(
            'More languages will be added over time.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandTeal.withAlpha(18)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.brandTeal : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    sublabel,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.brandTeal, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Permissions
// ---------------------------------------------------------------------------

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Almost there', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text(
            'VisaRadar works best with a couple of permissions. '
            'You can change these any time in your device settings.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          _PermissionCard(
            icon: Icons.location_on_outlined,
            color: AppColors.brandTeal,
            title: 'Location Access',
            body: 'Detects when you cross a border and logs entries '
                'automatically. Location is only used when VisaRadar needs '
                'to update your travel record.',
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.notifications_outlined,
            color: AppColors.info,
            title: 'Notifications',
            body: 'Sends reminders before your Schengen allowance runs out. '
                'You choose which alerts are enabled in Settings.',
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.lock_outline,
            color: AppColors.success,
            title: 'Privacy by Default',
            body: 'All your travel data stays on this device. '
                'VisaRadar never shares your location or history with third parties.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Permission prompts will appear the first time each feature activates.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
