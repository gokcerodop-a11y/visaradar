import 'package:flutter_test/flutter_test.dart';
import 'package:visaradar/features/travel/domain/entities/travel_entry.dart';
import 'package:visaradar/features/travel/domain/usecases/schengen_calculator.dart';

void main() {
  const calculator = SchengenCalculator();

  // Helper to build a UTC date easily
  DateTime d(int year, int month, int day) => DateTime.utc(year, month, day);

  TravelEntry entry({
    required String id,
    required DateTime entryDate,
    DateTime? exitDate,
    bool isSchengen = true,
    bool confirmed = true,
  }) {
    return TravelEntry(
      id: id,
      country: 'DE',
      entryDate: entryDate,
      exitDate: exitDate,
      isSchengen: isSchengen,
      confirmedByUser: confirmed,
    );
  }

  group('SchengenCalculator', () {
    test('zero entries → 0 days used, 90 remaining, safe', () {
      final result = calculator.calculate([], referenceDate: d(2024, 6, 1));
      expect(result.daysUsed, 0);
      expect(result.daysRemaining, 90);
      expect(result.riskLevel, SchengenRisk.safe);
    });

    test('single 30-day stay within window', () {
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 5, 1),
            exitDate: d(2024, 5, 30),
          ),
        ],
        referenceDate: d(2024, 6, 1),
      );
      expect(result.daysUsed, 30);
      expect(result.daysRemaining, 60);
      expect(result.riskLevel, SchengenRisk.safe);
    });

    test('stay older than 180 days is excluded', () {
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2023, 11, 1),
            exitDate: d(2023, 11, 15),
          ),
        ],
        referenceDate: d(2024, 6, 1),
      );
      expect(result.daysUsed, 0);
    });

    test('non-Schengen entry is excluded', () {
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 5, 1),
            exitDate: d(2024, 5, 30),
            isSchengen: false,
          ),
        ],
        referenceDate: d(2024, 6, 1),
      );
      expect(result.daysUsed, 0);
    });

    test('unconfirmed entry is excluded', () {
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 5, 1),
            exitDate: d(2024, 5, 30),
            confirmed: false,
          ),
        ],
        referenceDate: d(2024, 6, 1),
      );
      expect(result.daysUsed, 0);
    });

    test('open-ended entry (no exit) counts up to today', () {
      final referenceDate = d(2024, 6, 10);
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 6, 1),
            // no exitDate → still in country
          ),
        ],
        referenceDate: referenceDate,
      );
      // 1 Jun to 10 Jun inclusive = 10 days
      expect(result.daysUsed, 10);
    });

    test('warning risk when ≤15 days remaining', () {
      // 76 days used → 14 remaining
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 1, 1),
            exitDate: d(2024, 3, 16), // 76 days
          ),
        ],
        referenceDate: d(2024, 3, 16),
      );
      expect(result.riskLevel, SchengenRisk.warning);
    });

    test('critical risk when ≤5 days remaining', () {
      // 86 days used → 4 remaining
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 1, 1),
            exitDate: d(2024, 3, 26), // 86 days
          ),
        ],
        referenceDate: d(2024, 3, 26),
      );
      expect(result.riskLevel, SchengenRisk.critical);
    });

    test('over risk when >90 days used', () {
      // 95 days
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 1, 1),
            exitDate: d(2024, 4, 4), // 95 days
          ),
        ],
        referenceDate: d(2024, 4, 4),
      );
      expect(result.riskLevel, SchengenRisk.over);
      expect(result.isOver, isTrue);
    });

    test('days clamped at 90 boundary correctly', () {
      // Exactly 90 days → 0 remaining, critical
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 1, 1),
            exitDate: d(2024, 3, 30), // 90 days
          ),
        ],
        referenceDate: d(2024, 3, 30),
      );
      expect(result.daysUsed, 90);
      expect(result.daysRemaining, 0);
    });

    test('multiple entries within window sum correctly', () {
      final result = calculator.calculate(
        [
          entry(id: '1', entryDate: d(2024, 3, 1), exitDate: d(2024, 3, 20)), // 20
          entry(id: '2', entryDate: d(2024, 4, 1), exitDate: d(2024, 4, 30)), // 30
          entry(id: '3', entryDate: d(2024, 5, 15), exitDate: d(2024, 5, 24)), // 10
        ],
        referenceDate: d(2024, 6, 1),
      );
      expect(result.daysUsed, 60);
      expect(result.daysRemaining, 30);
    });

    test('entry partially outside window is clipped', () {
      // Reference: Jun 1 2024 → windowStart = Jun 1 − 179 days = Dec 5 2023
      // Entry: Nov 15 – Dec 10 2023  → only Dec 5–10 inside = 6 days
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2023, 11, 15),
            exitDate: d(2023, 12, 10),
          ),
        ],
        referenceDate: d(2024, 6, 1),
      );
      expect(result.daysUsed, 6);
    });

    test('nextResetDate is null when not over limit', () {
      final result = calculator.calculate([], referenceDate: d(2024, 6, 1));
      expect(result.nextResetDate, isNull);
    });

    test('nextResetDate is set when over 90-day limit', () {
      final result = calculator.calculate(
        [
          entry(
            id: '1',
            entryDate: d(2024, 1, 1),
            exitDate: d(2024, 4, 4), // 95 days
          ),
        ],
        referenceDate: d(2024, 4, 4),
      );
      expect(result.nextResetDate, isNotNull);
      // Should be 180 days after Jan 1
      expect(result.nextResetDate, d(2024, 6, 29));
    });
  });
}
