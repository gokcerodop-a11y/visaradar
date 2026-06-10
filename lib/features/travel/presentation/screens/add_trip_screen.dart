import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/country_names.dart';
import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/country_code_badge.dart';
import '../../../profile/domain/data/countries.dart';
import '../../domain/data/schengen_countries.dart';
import '../../domain/entities/travel_entry.dart';
import '../providers/trips_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');

class AddTripScreen extends ConsumerStatefulWidget {
  /// Pass an existing entry to edit it. Null = add mode.
  const AddTripScreen({super.key, this.existingEntry});

  final TravelEntry? existingEntry;

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  final _noteController = TextEditingController();

  Country? _country;

  /// null = auto-detect from country code; true/false = user override
  bool? _isSchengenOverride;
  bool _showSchengenOverride = false;

  DateTime? _entryDate;
  DateTime? _exitDate;
  bool _saving = false;

  bool get _isEditMode => widget.existingEntry != null;

  /// Effective Schengen status: override wins, else auto-detect from country.
  bool get _effectiveIsSchengen =>
      _isSchengenOverride ??
      (_country != null ? isSchengenCountry(_country!.code) : false);

  @override
  void initState() {
    super.initState();
    final e = widget.existingEntry;
    if (e != null) {
      _country = kCountries.where((c) => c.code == e.country).firstOrNull ??
          Country(e.country, e.countryLabel ?? e.country);
      // Only set override if user previously disagreed with auto-detection
      final autoSchengen = isSchengenCountry(e.country);
      _isSchengenOverride = (e.isSchengen != autoSchengen) ? e.isSchengen : null;
      _showSchengenOverride = _isSchengenOverride != null;
      _entryDate = e.entryDate.toLocal();
      _exitDate = e.exitDate?.toLocal();
      _noteController.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? get _validationError {
    if (_country == null) {
      return L.t('Please select a country.', 'Lütfen bir ülke seçin.');
    }
    if (_entryDate == null) {
      return L.t('Please select an entry date.', 'Lütfen bir giriş tarihi seçin.');
    }
    if (_exitDate != null && _exitDate!.isBefore(_entryDate!)) {
      return L.t('Exit date cannot be before entry date.',
          'Çıkış tarihi giriş tarihinden önce olamaz.');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Duplicate ongoing trip check
  // ---------------------------------------------------------------------------

  Future<bool> _confirmIfDuplicateOngoing() async {
    if (_exitDate != null || _isEditMode) return true;

    final trips = ref.read(tripsProvider);
    final existingOngoing = trips.where((t) => t.isOngoing).toList();
    if (existingOngoing.isEmpty) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(L.t('Open trip already exists',
            'Zaten açık bir seyahat var')),
        content: Text(
          L.t(
            'You already have an open trip with no exit date. '
            'Are you sure you want to add another?',
            'Çıkış tarihi olmayan açık bir seyahatiniz zaten var. '
            'Yine de bir tane daha eklemek istediğinize emin misiniz?',
          ),
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L.t('Cancel', 'İptal')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L.t('Add anyway', 'Yine de ekle')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    if (!await _confirmIfDuplicateOngoing()) {
      setState(() => _saving = false);
      return;
    }

    final entry = TravelEntry(
      id: _isEditMode
          ? widget.existingEntry!.id
          : DateTime.now().microsecondsSinceEpoch.toString(),
      country: _country!.code,
      countryLabel: _country!.name,
      entryDate: _entryDate!.toUtc(),
      exitDate: _exitDate?.toUtc(),
      isSchengen: _effectiveIsSchengen,
      confirmedByUser: true,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (_isEditMode) {
      await ref.read(tripsProvider.notifier).update(entry);
    } else {
      await ref.read(tripsProvider.notifier).add(entry);
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Country picker
  // ---------------------------------------------------------------------------

  void _showCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountryPickerSheet(
        selected: _country?.code,
        onSelect: (country) {
          setState(() {
            _country = country;
            // Reset override — auto-detect from new country
            _isSchengenOverride = null;
            _showSchengenOverride = false;
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickEntryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: L.t('Entry date', 'Giriş tarihi'),
    );
    if (picked != null) {
      setState(() {
        _entryDate = picked;
        if (_exitDate != null && _exitDate!.isBefore(picked)) {
          _exitDate = null;
        }
      });
    }
  }

  Future<void> _pickExitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _exitDate ?? (_entryDate ?? DateTime.now()),
      firstDate: _entryDate ?? DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: L.t('Exit date', 'Çıkış tarihi'),
    );
    if (picked != null) {
      setState(() => _exitDate = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canSave = _validationError == null && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode
            ? L.t('Edit Trip', 'Seyahati Düzenle')
            : L.t('Add Trip', 'Seyahat Ekle')),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brandTeal),
                  ),
                )
              : TextButton(
                  onPressed: canSave ? _save : null,
                  child: Text(
                    _isEditMode
                        ? L.t('Save', 'Kaydet')
                        : L.t('Add', 'Ekle'),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: canSave
                          ? AppColors.brandTeal
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Country ──────────────────────────────────────────────────────
          _SectionLabel(L.t('Country', 'Ülke')),
          _PickerTile(
            leading: _country != null
                ? CountryCodeBadge(
                    code: _country!.code,
                    highlighted: true,
                    size: BadgeSize.small,
                  )
                : const CountryCodeBadge(code: '  ', size: BadgeSize.small),
            label: _country != null
                ? countryNameLocalized(_country!.code, _country!.name)
                : L.t('Select country', 'Ülke seç'),
            hasValue: _country != null,
            onTap: _showCountryPicker,
            trailing: _country == null
                ? const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted)
                : null,
          ),
          const SizedBox(height: 12),

          // ── Schengen status (auto-detected) ───────────────────────────────
          if (_country != null) ...[
            _SchengenStatusCard(
              isSchengen: _effectiveIsSchengen,
              isOverridden: _isSchengenOverride != null,
              showOverride: _showSchengenOverride,
              onToggleOverride: () =>
                  setState(() => _showSchengenOverride = !_showSchengenOverride),
              onOverrideChanged: (v) =>
                  setState(() => _isSchengenOverride = v ? true : false),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 8),

          // ── Dates ─────────────────────────────────────────────────────────
          _SectionLabel(L.t('Dates', 'Tarihler')),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  leading: const Icon(Icons.flight_land_outlined,
                      size: 20, color: AppColors.textSecondary),
                  label: _entryDate != null
                      ? _dateFmt.format(_entryDate!)
                      : L.t('Entry date', 'Giriş tarihi'),
                  hasValue: _entryDate != null,
                  onTap: _pickEntryDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  leading: const Icon(Icons.flight_takeoff_outlined,
                      size: 20, color: AppColors.textSecondary),
                  label: _exitDate != null
                      ? _dateFmt.format(_exitDate!)
                      : L.t('Exit date', 'Çıkış tarihi'),
                  hasValue: _exitDate != null,
                  onTap: _pickExitDate,
                  trailing: _exitDate != null
                      ? GestureDetector(
                          onTap: () => setState(() => _exitDate = null),
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.textMuted),
                        )
                      : null,
                ),
              ),
            ],
          ),
          if (_exitDate == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                L.t('Leave exit date empty if you are still in the country.',
                    'Hâlâ ülkedeyseniz çıkış tarihini boş bırakın.'),
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 20),

          // ── Note ──────────────────────────────────────────────────────────
          _SectionLabel(L.t('Note (optional)', 'Not (isteğe bağlı)')),
          TextField(
            controller: _noteController,
            style: AppTextStyles.bodyMedium,
            maxLines: 3,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: L.t('Add a note about this trip…',
                  'Bu seyahat hakkında not ekleyin…'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schengen status card
// ---------------------------------------------------------------------------

class _SchengenStatusCard extends StatelessWidget {
  const _SchengenStatusCard({
    required this.isSchengen,
    required this.isOverridden,
    required this.showOverride,
    required this.onToggleOverride,
    required this.onOverrideChanged,
  });

  final bool isSchengen;
  final bool isOverridden;
  final bool showOverride;
  final VoidCallback onToggleOverride;
  final ValueChanged<bool> onOverrideChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isSchengen ? AppColors.brandTeal : AppColors.textSecondary;
    final bgColor =
        isSchengen ? AppColors.brandTeal.withAlpha(14) : Colors.transparent;
    final borderColor =
        isSchengen ? AppColors.brandTeal.withAlpha(60) : AppColors.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                isSchengen
                    ? Icons.check_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSchengen
                          ? L.t('Schengen country', 'Schengen ülkesi')
                          : L.t('Non-Schengen country', 'Schengen dışı ülke'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isSchengen
                          ? L.t('Counts toward your 90/180-day allowance',
                              '90/180 günlük hakkınıza dahil edilir')
                          : L.t('Does not affect your Schengen counter',
                              'Schengen sayacınızı etkilemez'),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (isOverridden)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    L.t('Override', 'Değiştirildi'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Override control (secondary)
        GestureDetector(
          onTap: onToggleOverride,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              showOverride
                  ? L.t('Hide override', 'Değişikliği gizle')
                  : L.t('Override Schengen status',
                      'Schengen durumunu değiştir'),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
        ),
        if (showOverride)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: SwitchListTile(
                dense: true,
                value: isSchengen,
                onChanged: onOverrideChanged,
                title: Text(
                  L.t('Schengen area', 'Schengen bölgesi'),
                  style: AppTextStyles.bodySmall,
                ),
                activeThumbColor: AppColors.brandTeal,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
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

// ---------------------------------------------------------------------------
// Picker tile
// ---------------------------------------------------------------------------

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.leading,
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country picker sheet — consistent with onboarding nationality picker
// ---------------------------------------------------------------------------

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.onSelect,
    this.selected,
  });

  final ValueChanged<Country> onSelect;
  final String? selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
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

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle
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
            // Title + search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.t('Select Country', 'Ülke Seç'),
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: L.t('Search country…', 'Ülke ara…'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: _clearSearch,
                              child: const Icon(Icons.close,
                                  size: 18, color: AppColors.textMuted),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    L.t('No countries found', 'Ülke bulunamadı'),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final country = filtered[i];
                    final isSelected = country.code == widget.selected;
                    final schengen = isSchengenCountry(country.code);
                    return _TripCountryRow(
                      country: country,
                      isSelected: isSelected,
                      isSchengen: schengen,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        widget.onSelect(country);
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

// ---------------------------------------------------------------------------
// Country row inside picker — mirrors onboarding _CountryRow
// ---------------------------------------------------------------------------

class _TripCountryRow extends StatelessWidget {
  const _TripCountryRow({
    required this.country,
    required this.isSelected,
    required this.isSchengen,
    required this.onTap,
  });

  final Country country;
  final bool isSelected;
  final bool isSchengen;
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
              // Country code badge — no flag emoji, consistent cross-platform
              CountryCodeBadge(
                code: country.code,
                highlighted: isSelected,
                size: BadgeSize.small,
              ),
              const SizedBox(width: 14),
              // Country name
              Expanded(
                child: Text(
                  countryNameLocalized(country.code, country.name),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              // Schengen badge (only for Schengen countries, not selected)
              if (isSchengen && !isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'S',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.brandTeal),
                  ),
                ),
              // Selected checkmark (replaces Schengen badge when selected)
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandTeal, size: 18),
              if (!isSchengen && !isSelected) const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}
