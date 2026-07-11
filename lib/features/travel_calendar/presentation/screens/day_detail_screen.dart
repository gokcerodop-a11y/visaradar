import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/travel_log_service.dart';
import '../../domain/models/day_log.dart';
import 'travel_calendar_screen.dart' show kMonthNamesTr, kMonthNamesEn;

const _kWeekdayNamesTr = [
  '', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];
const _kWeekdayNamesEn = [
  '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday',
];

/// Full detail + editing for a single calendar day.
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({
    super.key,
    required this.dayLog,
    required this.date,
  });

  final DayLog dayLog;
  final DateTime date;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  late DayLog _log;
  late final TextEditingController _noteController;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _log = widget.dayLog;
    _noteController = TextEditingController(text: _log.notes ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  TravelLogService get _service => ref.read(travelLogServiceProvider);

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    final updated =
        await _service.updateNote(_log.dateKey, _noteController.text);
    if (!mounted) return;
    setState(() {
      _log = updated;
      _savingNote = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceCard,
        content: Text(
          L.t('Note saved', 'Not kaydedildi'),
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }

  Future<void> _editStayedCity() async {
    final controller = TextEditingController(text: _log.stayedCity ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          L.t('Overnight city', 'Kalınan Şehir'),
          style: AppTextStyles.titleLarge,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodyLarge,
          cursorColor: AppColors.brandTeal,
          decoration: InputDecoration(
            hintText: L.t('e.g. Rome', 'örn. Roma'),
            hintStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textMuted),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.brandTeal),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              L.t('Cancel', 'İptal'),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(
              L.t('Save', 'Kaydet'),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.brandTeal),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final updated = await _service.updateStayedCity(_log.dateKey, result);
    if (!mounted) return;
    setState(() => _log = updated);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          L.t('Delete this day?', 'Bu gün silinsin mi?'),
          style: AppTextStyles.titleLarge,
        ),
        content: Text(
          L.t(
            'All records for this day (km, steps, cities, note) will be permanently deleted.',
            'Bu güne ait tüm kayıtlar (km, adım, şehirler, not) kalıcı olarak silinecek.',
          ),
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              L.t('Cancel', 'İptal'),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              L.t('Delete', 'Sil'),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.deleteLog(_log.dateKey);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  String get _title {
    final months = L.isTr ? kMonthNamesTr : kMonthNamesEn;
    final weekdays = L.isTr ? _kWeekdayNamesTr : _kWeekdayNamesEn;
    final d = widget.date;
    return L.isTr
        ? '${d.day} ${months[d.month]} ${d.year} ${weekdays[d.weekday]}'
        : '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(_title, style: AppTextStyles.titleLarge),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: L.t('Delete day', 'Günü sil'),
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildCitiesSection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final stayed = (_log.stayedCity == null || _log.stayedCity!.isEmpty)
        ? L.t('Add', 'Ekle')
        : _log.stayedCity!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DetailMetricCard(
                icon: Icons.directions_car_rounded,
                label: L.t('Distance traveled', 'Gidilen Yol'),
                value:
                    '${_log.kmTraveled.toStringAsFixed(1)} km',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DetailMetricCard(
                icon: Icons.directions_walk_rounded,
                label: L.t('Walking', 'Yürüme'),
                value: '${_log.walkingKm.toStringAsFixed(1)} km',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DetailMetricCard(
                icon: Icons.directions_run_rounded,
                label: L.t('Steps', 'Adım'),
                value: _fmtSteps(_log.steps),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DetailMetricCard(
                icon: Icons.hotel_rounded,
                label: L.t('Overnight city', 'Kalınan Şehir'),
                value: stayed,
                onTap: _editStayedCity,
                trailingIcon: Icons.edit_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCitiesSection() {
    final cities = _log.citiesVisited;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandTeal.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_rounded,
                  color: AppColors.brandTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                L.t('Cities visited', 'Geçilen Şehirler'),
                style: AppTextStyles.titleLarge,
              ),
              const Spacer(),
              if (cities.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${cities.length}',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.brandTeal),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (cities.isEmpty)
            Row(
              children: [
                const Icon(Icons.explore_off_rounded,
                    color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L.t(
                      'No record for this day',
                      'Bu gün için kayıt yok',
                    ),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final city in cities)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            AppColors.brandTeal.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_rounded,
                            color: AppColors.brandTeal, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.brandTeal),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  color: AppColors.brandTeal, size: 22),
              const SizedBox(width: 8),
              Text(L.t('Note', 'Not'), style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 5,
            minLines: 3,
            style: AppTextStyles.bodyLarge,
            cursorColor: AppColors.brandTeal,
            decoration: InputDecoration(
              hintText: L.t(
                'How was your day? Write a memory...',
                'Günün nasıl geçti? Bir anı yaz...',
              ),
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.brandNavyLight,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.brandTeal),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _savingNote ? null : _saveNote,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                foregroundColor: AppColors.brandNavy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _savingNote
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandNavy,
                      ),
                    )
                  : Text(
                      L.t('Save', 'Kaydet'),
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.brandNavy),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 12345 -> "12.345" (TR) / "12,345" (EN)
  static String _fmtSteps(int value) {
    final sep = L.isTr ? '.' : ',';
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(sep);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _DetailMetricCard extends StatelessWidget {
  const _DetailMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailingIcon,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 108,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.brandTeal, size: 20),
                  const Spacer(),
                  if (trailingIcon != null)
                    Icon(trailingIcon,
                        color: AppColors.textMuted, size: 16),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
