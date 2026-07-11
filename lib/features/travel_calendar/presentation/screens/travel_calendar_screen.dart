import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';

import '../../../../core/localization/locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/travel_log_service.dart';
import '../../domain/models/day_log.dart';
import 'day_detail_screen.dart';

/// Turkish / English month names (index 1..12).
const kMonthNamesTr = [
  '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const kMonthNamesEn = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Travel Calendar — auto-captured daily travel stats in a month grid.
class TravelCalendarScreen extends ConsumerStatefulWidget {
  const TravelCalendarScreen({super.key});

  @override
  ConsumerState<TravelCalendarScreen> createState() =>
      _TravelCalendarScreenState();
}

class _TravelCalendarScreenState extends ConsumerState<TravelCalendarScreen> {
  late DateTime _visibleMonth; // always day 1 of the shown month
  DateTime _selectedDay = DateTime.now();

  /// dateKey -> log for the visible month.
  Map<String, DayLog> _logs = {};
  bool _loading = true;

  StreamSubscription<StepCount>? _stepSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _loadMonth();
    _startPedometer();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  Future<void> _loadMonth() async {
    final service = ref.read(travelLogServiceProvider);
    final logs = await service.getLogsForMonth(_visibleMonth);
    if (!mounted) return;
    setState(() {
      _logs = {for (final log in logs) log.dateKey: log};
      _loading = false;
    });
  }

  /// Live step counting with graceful degradation: any pedometer error is
  /// swallowed and the calendar simply shows the last saved value (or 0).
  void _startPedometer() {
    try {
      _stepSub = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          try {
            final service = ref.read(travelLogServiceProvider);
            final updated = await service.recordPedometerReading(event.steps);
            if (!mounted) return;
            // Only refresh if today is inside the visible month.
            if (updated.dateKey
                .startsWith(_monthPrefix(_visibleMonth))) {
              setState(() => _logs[updated.dateKey] = updated);
            }
          } catch (_) {
            // Persisting failed — keep whatever is on screen.
          }
        },
        onError: (Object _) {
          // Sensor unavailable / permission denied → steps stay at 0.
        },
        cancelOnError: true,
      );
    } catch (_) {
      // Platform without pedometer support → steps stay at 0.
    }
  }

  static String _monthPrefix(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _loading = true;
    });
    _loadMonth();
  }

  Future<void> _openDay(DateTime date) async {
    setState(() => _selectedDay = date);
    final key = DayLog.keyFor(date);
    final log = _logs[key] ?? DayLog.empty(date);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayDetailScreen(dayLog: log, date: date),
      ),
    );
    // Detail screen may have edited or deleted the log — reload.
    _loadMonth();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          L.t('Travel Calendar', 'Seyahat Takvimi'),
          style: AppTextStyles.headlineMedium,
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brandTeal),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 12),
                  _buildWeekdayRow(),
                  const SizedBox(height: 6),
                  _buildCalendarGrid(),
                  const SizedBox(height: 20),
                  Text(
                    L.t('This Month', 'Bu Ay'),
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildMonthStats(),
                ],
              ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final names = L.isTr ? kMonthNamesTr : kMonthNamesEn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavArrow(
          icon: Icons.chevron_left_rounded,
          onTap: () => _changeMonth(-1),
        ),
        Text(
          '${names[_visibleMonth.month]} ${_visibleMonth.year}',
          style: AppTextStyles.headlineMedium,
        ),
        _NavArrow(
          icon: Icons.chevron_right_rounded,
          onTap: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    final labels = L.isTr
        ? const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(label, style: AppTextStyles.caption),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1; // Monday-based
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final today = DateTime.now();

    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(builder: (context) {
                    final cellIndex = row * 7 + col;
                    final dayNum = cellIndex - leadingBlanks + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox(height: 62);
                    }
                    final date = DateTime(
                        _visibleMonth.year, _visibleMonth.month, dayNum);
                    final log = _logs[DayLog.keyFor(date)];
                    final isToday = date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
                    final isSelected = date.year == _selectedDay.year &&
                        date.month == _selectedDay.month &&
                        date.day == _selectedDay.day;
                    return _DayCell(
                      dayNum: dayNum,
                      log: log,
                      isToday: isToday,
                      isSelected: isSelected,
                      onTap: () => _openDay(date),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMonthStats() {
    final logs = _logs.values.toList();
    final totalKm =
        logs.fold<double>(0, (sum, log) => sum + log.kmTraveled);
    final totalSteps = logs.fold<int>(0, (sum, log) => sum + log.steps);
    final countries = <String>{
      for (final log in logs)
        for (final country in log.countriesVisited) country.toLowerCase(),
    };
    final activeDays = logs.where((log) => !log.isEmpty).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.route_rounded,
                label: L.t('Total km', 'Toplam km'),
                value: _fmtKm(totalKm),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.directions_walk_rounded,
                label: L.t('Total steps', 'Toplam adım'),
                value: _fmtInt(totalSteps),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.public_rounded,
                label: L.t('Countries visited', 'Ziyaret edilen ülke'),
                value: '${countries.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.event_available_rounded,
                label: L.t('Active days', 'Aktif gün'),
                value: '$activeDays',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _fmtKm(double km) =>
      km >= 100 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);

  /// 12345 -> "12.345" (TR) / "12,345" (EN)
  static String _fmtInt(int value) {
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

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: AppColors.brandTeal, size: 26),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNum,
    required this.log,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int dayNum;
  final DayLog? log;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRecord = log != null && !log!.isEmpty;
    final cities = log?.citiesVisited ?? const [];

    // City hint under the date: single city → its (short) name,
    // multiple → "3 şehir" / "3 cities".
    String? cityHint;
    if (cities.length == 1) {
      cityHint = cities.first;
    } else if (cities.length > 1) {
      cityHint =
          L.t('${cities.length} cities', '${cities.length} şehir');
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 62,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandTeal.withValues(alpha: 0.16)
              : (hasRecord ? AppColors.surfaceCard : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: AppColors.brandTeal, width: 1.4)
              : (isSelected
                  ? Border.all(
                      color: AppColors.brandTeal.withValues(alpha: 0.6))
                  : null),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? AppColors.brandTeal
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            if (cityHint != null)
              Text(
                cityHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.brandTeal,
                ),
              )
            else if (hasRecord)
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.brandTeal,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brandTeal, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.displayMedium),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
