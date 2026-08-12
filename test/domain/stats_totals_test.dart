import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/analytics_service.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';

Dosage _dose(
  String id,
  double amount,
  DateTime timestamp, {
  String strain = 'strain',
}) =>
    Dosage(id: id, strainId: strain, amount: amount, timestamp: timestamp);

void main() {
  group('grandTotals', () {
    test('separates the span tracked from the days actually dosed', () {
      final doses = [
        _dose('1', 16, DateTime(2025, 2, 1, 8)),
        _dose('2', 16, DateTime(2025, 2, 1, 14)),
        // Feb 2 is a rest day.
        _dose('3', 18, DateTime(2025, 2, 3, 9), strain: 'other'),
      ];

      final totals = grandTotals(doses, now: DateTime(2025, 2, 3, 20));

      expect(totals.grams, 50);
      expect(totals.doses, 3);
      expect(totals.daysTracked, 3, reason: 'Feb 1 to Feb 3 inclusive');
      expect(totals.activeDays, 2, reason: 'Feb 2 had nothing');
      expect(totals.strainsUsed, 2);
      expect(totals.firstDose, DateTime(2025, 2, 1, 8));
      expect(totals.lastDose, DateTime(2025, 2, 3, 9));
    });

    test('the active-day average sits above the all-days average', () {
      final doses = [
        _dose('1', 60, DateTime(2025, 2, 1, 8)),
        _dose('2', 60, DateTime(2025, 2, 3, 8)),
      ];

      final totals = grandTotals(doses, now: DateTime(2025, 2, 3, 20));
      final allDays = IntakeFactors.of(
        closedDayFacts(
          doses,
          DateTimeRange(start: DateTime(2025, 2, 1), end: DateTime(2025, 2, 3)),
          now: DateTime(2025, 2, 3, 20),
        ),
      );

      // 120g over two dosed days, or over three tracked days.
      expect(totals.gramsPerActiveDay, 60);
      expect(allDays.gramsPerDay, 40);
    });

    test('a dose dated in the future does not produce a negative span', () {
      final doses = [
        _dose('1', 16, DateTime(2025, 2, 1, 8)),
        _dose('2', 16, DateTime(2025, 3, 1, 8)),
      ];

      final totals = grandTotals(doses, now: DateTime(2025, 2, 10));

      expect(totals.daysTracked, 29);
      expect(totals.daysTracked, greaterThan(0));
    });

    test('an empty history is all zeroes, not NaN', () {
      final totals = grandTotals(const []);

      expect(totals.grams, 0);
      expect(totals.gramsPerActiveDay, 0);
      expect(totals.dosesPerActiveDay, 0);
      expect(totals.gramsPerDose, 0);
      expect(totals.firstDose, isNull);
    });
  });

  group('computeWeekdayRhythm', () {
    List<DayFacts> factsFor(List<Dosage> doses, DateTime start, DateTime end) =>
        closedDayFacts(
          doses,
          DateTimeRange(start: start, end: end),
          now: end.add(const Duration(days: 1)),
        );

    test('averages per occurrence so an extra Monday cannot win on its own',
        () {
      // Twelve full weeks from Monday 2025-02-03, plus one extra Monday, so
      // Monday occurs thirteen times against everyone else's twelve. Every
      // day carries 10g except Wednesdays, which carry 30g.
      final doses = <Dosage>[];
      var id = 0;
      for (var i = 0; i < 85; i++) {
        final day = DateTime(2025, 2, 3).add(Duration(days: i));
        final grams = day.weekday == DateTime.wednesday ? 30.0 : 10.0;
        doses.add(_dose('d${id++}', grams, day.add(const Duration(hours: 9))));
      }

      final rhythm = computeWeekdayRhythm(
        factsFor(doses, DateTime(2025, 2, 3), DateTime(2025, 4, 28)),
      );

      // Summing would hand Monday 130g against every other 10g weekday's 120g
      // purely on count. The per-occurrence mean is what we assert.
      expect(rhythm.busiest, DateTime.wednesday - 1);
      expect(rhythm.gramsByWeekday[DateTime.wednesday - 1], 30);
      expect(rhythm.gramsByWeekday[DateTime.monday - 1], 10);
      expect(rhythm.daysByWeekday[DateTime.monday - 1], 13);
      expect(rhythm.daysByWeekday[DateTime.wednesday - 1], 12);
    });

    test('names no busiest day when the week is flat', () {
      final doses = [
        for (var i = 0; i < 84; i++)
          _dose(
            'd$i',
            10,
            DateTime(2025, 2, 3).add(Duration(days: i, hours: 9)),
          ),
      ];

      final rhythm = computeWeekdayRhythm(
        factsFor(doses, DateTime(2025, 2, 3), DateTime(2025, 4, 27)),
      );

      expect(rhythm.busiest, isNull);
      expect(rhythm.quietest, isNull);
    });

    test('stays silent until every weekday has come round enough times', () {
      // Four weeks: four or five of each weekday. A clear Wednesday spike is
      // present and must still not be named — at that count the winner is
      // whatever the last few weeks happened to look like.
      final doses = [
        for (var i = 0; i < 28; i++)
          _dose(
            'd$i',
            DateTime(2025, 2, 3).add(Duration(days: i)).weekday ==
                    DateTime.wednesday
                ? 40
                : 10,
            DateTime(2025, 2, 3).add(Duration(days: i, hours: 9)),
          ),
      ];

      final rhythm = computeWeekdayRhythm(
        factsFor(doses, DateTime(2025, 2, 3), DateTime(2025, 3, 2)),
      );

      expect(rhythm.busiest, isNull);
    });
  });

  group('computeDoseSpacing', () {
    final range = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 2),
    );

    test('measures same-day gaps and ignores the overnight break', () {
      final doses = [
        _dose('1', 16, DateTime(2025, 2, 1, 8)),
        _dose('2', 16, DateTime(2025, 2, 1, 12)),
        _dose('3', 16, DateTime(2025, 2, 1, 18)),
        // Next morning: an 14h overnight gap that must not be counted.
        _dose('4', 16, DateTime(2025, 2, 2, 8)),
        _dose('5', 16, DateTime(2025, 2, 2, 13)),
      ];

      final spacing = computeDoseSpacing(doses, range);

      // Gaps are 4h, 6h (day one) and 5h (day two) — median 5h.
      expect(spacing.samples, 3);
      expect(spacing.median, const Duration(hours: 5));
      expect(spacing.shortest, const Duration(hours: 4));
    });

    test('a day with a single dose contributes no gap', () {
      final doses = [
        _dose('1', 16, DateTime(2025, 2, 1, 8)),
        _dose('2', 16, DateTime(2025, 2, 2, 9)),
      ];

      final spacing = computeDoseSpacing(doses, range);

      expect(spacing.samples, 0);
      expect(spacing.median, isNull);
    });

    test('UTC timestamps are bucketed by the local day', () {
      // 23:30 and 00:30 local are different days, so they are not a pair.
      final a = DateTime(2025, 2, 1, 23, 30).toUtc();
      final b = DateTime(2025, 2, 2, 0, 30).toUtc();
      expect(a.isUtc, isTrue);

      final spacing = computeDoseSpacing(
        [_dose('1', 16, a), _dose('2', 16, b)],
        range,
      );

      expect(spacing.samples, 0);
    });
  });
}
