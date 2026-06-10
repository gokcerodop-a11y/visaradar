import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/country_names.dart';
import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/country_code_badge.dart';
import '../../../profile/domain/data/countries.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late String? _nationality;
  late String? _nationalityLabel;
  late PassportType _passportType;
  late ResidenceStatus _residenceStatus;
  late TravelMode _travelMode;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nationality = profile.nationality;
    _nationalityLabel = profile.nationalityLabel;
    _passportType = profile.passportType;
    _residenceStatus = profile.residenceStatus;
    _travelMode = profile.travelMode;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = UserProfile(
      nationality: _nationality,
      nationalityLabel: _nationalityLabel,
      passportType: _passportType,
      residenceStatus: _residenceStatus,
      travelMode: _travelMode,
      preferredLocale: ref.read(profileProvider).preferredLocale,
    );
    await ref.read(profileProvider.notifier).update(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('Edit Profile', 'Profili Düzenle')),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandTeal,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(
                    L.t('Save', 'Kaydet'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.brandTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel(label: L.t('Nationality', 'Uyruk')),
          _NationalityTile(
            label: _nationalityLabel,
            code: _nationality,
            onSelect: (code, label) =>
                setState(() {
                  _nationality = code;
                  _nationalityLabel = label;
                }),
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: L.t('Passport Type', 'Pasaport türü')),
          _OptionGroup<PassportType>(
            options: [
              _Option(
                value: PassportType.ordinary,
                icon: Icons.book_outlined,
                title: L.t('Ordinary passport', 'Umuma mahsus pasaport'),
                subtitle: L.t('Standard passport issued to citizens',
                    'Vatandaşlara verilen standart pasaport'),
              ),
              _Option(
                value: PassportType.euEeaSwiss,
                icon: Icons.flag_outlined,
                title: L.t('EU / EEA / Swiss passport',
                    'AB / AEA / İsviçre pasaportu'),
                subtitle: L.t('Free movement within the Schengen area',
                    'Schengen alanında serbest dolaşım'),
              ),
              _Option(
                value: PassportType.diplomatic,
                icon: Icons.shield_outlined,
                title: L.t('Diplomatic passport', 'Diplomatik pasaport'),
                subtitle: L.t('Issued to diplomatic personnel',
                    'Diplomatik personele verilir'),
              ),
              _Option(
                value: PassportType.serviceOfficial,
                icon: Icons.badge_outlined,
                title: L.t('Service / official passport',
                    'Hizmet / resmi pasaport'),
                subtitle: L.t('Issued for official government travel',
                    'Resmi devlet seyahati için verilir'),
              ),
              _Option(
                value: PassportType.special,
                icon: Icons.star_border_outlined,
                title: L.t('Special passport', 'Hususi pasaport'),
                subtitle: L.t('Other special-category passport',
                    'Diğer özel kategori pasaport'),
              ),
            ],
            selected: _passportType,
            onChanged: (v) => setState(() => _passportType = v),
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: L.t('Residence Status', 'İkamet durumu')),
          _OptionGroup<ResidenceStatus>(
            options: [
              _Option(
                value: ResidenceStatus.none,
                icon: Icons.person_outline,
                title: L.t('No residence permit', 'İkamet izni yok'),
                subtitle: L.t('Visiting on a tourist or short-stay visa',
                    'Turist veya kısa süreli vize ile ziyaret'),
              ),
              _Option(
                value: ResidenceStatus.euSchengenResident,
                icon: Icons.home_outlined,
                title: L.t('EU / Schengen residence permit',
                    'AB / Schengen ikamet izni'),
                subtitle: L.t('Long-stay visa or permit in a Schengen country',
                    'Schengen ülkesinde uzun süreli vize veya izin'),
              ),
              _Option(
                value: ResidenceStatus.otherResidenceStatus,
                icon: Icons.location_city_outlined,
                title: L.t('Other residence status', 'Diğer ikamet durumu'),
                subtitle: L.t('Permit outside the EU / Schengen area',
                    'AB / Schengen dışı izin'),
              ),
            ],
            selected: _residenceStatus,
            onChanged: (v) => setState(() => _residenceStatus = v),
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: L.t('Travel Method', 'Seyahat yöntemi')),
          _OptionGroup<TravelMode>(
            options: [
              _Option(
                value: TravelMode.plane,
                icon: Icons.flight_outlined,
                title: L.t('Plane', 'Uçak'),
                subtitle: L.t('Air travel', 'Hava yolu'),
              ),
              _Option(
                value: TravelMode.car,
                icon: Icons.directions_car_outlined,
                title: L.t('Car', 'Araba'),
                subtitle: L.t('Driving across borders', 'Sınırlardan araçla geçiş'),
              ),
              _Option(
                value: TravelMode.train,
                icon: Icons.train_outlined,
                title: L.t('Train', 'Tren'),
                subtitle: L.t('Rail travel', 'Tren yolu'),
              ),
              _Option(
                value: TravelMode.bus,
                icon: Icons.directions_bus_outlined,
                title: L.t('Bus', 'Otobüs'),
                subtitle: L.t('Coach or intercity bus', 'Şehirlerarası otobüs'),
              ),
              _Option(
                value: TravelMode.ferry,
                icon: Icons.directions_boat_outlined,
                title: L.t('Ferry', 'Feribot'),
                subtitle: L.t('Sea crossing', 'Deniz geçişi'),
              ),
              _Option(
                value: TravelMode.camperCaravan,
                icon: Icons.rv_hookup_outlined,
                title: L.t('Camper / caravan', 'Karavan'),
                subtitle: L.t('Motorhome or caravan travel',
                    'Motokaravan veya karavan ile seyahat'),
              ),
              _Option(
                value: TravelMode.motorcycle,
                icon: Icons.two_wheeler_outlined,
                title: L.t('Motorcycle', 'Motosiklet'),
                subtitle: L.t('Motorbike travel', 'Motosiklet ile seyahat'),
              ),
              _Option(
                value: TravelMode.onFoot,
                icon: Icons.directions_walk_outlined,
                title: L.t('On foot', 'Yürüyerek'),
                subtitle: L.t('Hiking or walking across borders',
                    'Sınırlardan yürüyerek geçiş'),
              ),
            ],
            selected: _travelMode,
            onChanged: (v) => setState(() => _travelMode = v),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _NationalityTile extends StatelessWidget {
  const _NationalityTile({
    required this.label,
    required this.code,
    required this.onSelect,
  });

  final String? label;
  final String? code;
  final void Function(String code, String label) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: code != null
            ? CountryCodeBadge(code: code!)
            : const Icon(Icons.language, color: AppColors.textSecondary),
        title: Text(
          label != null
              ? countryNameLocalized(code, label!)
              : L.t('Select nationality', 'Uyruk seçin'),
          style: AppTextStyles.bodyMedium.copyWith(
            color: label != null ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
          size: 18,
        ),
        onTap: () => _showPicker(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountryPickerSheet(onSelect: onSelect),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.onSelect});
  final void Function(String code, String label) onSelect;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<Country> get _filtered => _query.isEmpty
      ? kCountries
      : kCountries
          .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: L.t('Search nationality…', 'Uyruk ara…'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final c = _filtered[i];
                  return ListTile(
                    leading: CountryCodeBadge(code: c.code),
                    title: Text(countryNameLocalized(c.code, c.name),
                        style: AppTextStyles.bodyMedium),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onSelect(c.code, c.name);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Option<T> {
  const _Option({
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

class _OptionGroup<T> extends StatelessWidget {
  const _OptionGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_Option<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return GestureDetector(
          onTap: () => onChanged(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandTeal.withAlpha(20)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.brandTeal
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  opt.icon,
                  color: isSelected
                      ? AppColors.brandTeal
                      : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opt.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                      const SizedBox(height: 2),
                      Text(opt.subtitle,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: AppColors.brandTeal, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
