import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/analytics_service.dart';
import 'package:kratom_tracker_plus/domain/date_utils.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:flutter/material.dart';

Dosage _dose(DateTime at, double amount) => Dosage(
  id: at.toIso8601String(),
  strainId: 's1',
  timestamp: at,
  amount: amount,
);

void main() {
  group('calendar-day arithmetic', () {
    test('addDays lands on the same wall-clock midnight', () {
      final start = DateTime(2026, 3, 28);
      for (var n = 0; n < 400; n++) {
        final day = addDays(start, n);
        expect(day.hour, 0, reason: 'day $n drifted off midnight');
        expect(day.minute, 0);
      }
    });

    test('daysBetween is exact and antisymmetric', () {
      final a = DateTime(2026, 3, 28);
      for (var n = -400; n <= 400; n++) {
        expect(daysBetween(a, addDays(a, n)), n);
        expect(daysBetween(addDays(a, n), a), -n);
      }
    });

    test('startOfDay reads a UTC stamp as its local day', () {
      final utc = DateTime.utc(2026, 3, 1, 23, 30);
      expect(startOfDay(utc), startOfDay(utc.toLocal()));
      expect(startOfDay(utc).isUtc, isFalse);
    });

    // The precise shape of the original bug: the upper bound was
    // `startOfDay(end) + Duration(days: 1)`, i.e. 24 elapsed hours. On a
    // 25-hour fall-back day that lands an hour *early* and drops late doses;
    // on a 23-hour spring-forward day it reaches into the next day.
    // These assertions hold in any zone but only bite in one with DST —
    // running the suite under TZ=UTC will pass them either way.
    test('a day ends at the next local midnight, not 24 hours later', () {
      final days = [
        DateTime(2026, 3, 29), // Europe/London: 23 hours
        DateTime(2026, 10, 25), // Europe/London: 25 hours
        DateTime(2026, 7, 1), // ordinary 24 hours
      ];
      for (final day in days) {
        final next = addDays(day, 1);
        expect(next.hour, 0, reason: '$day + 1 must be a local midnight');

        final lastMoment = next.subtract(const Duration(minutes: 1));
        expect(
          inRangeInclusive(lastMoment, day, day),
          isTrue,
          reason: 'a dose at $lastMoment belongs to $day',
        );
        expect(
          inRangeInclusive(next, day, day),
          isFalse,
          reason: 'the next midnight belongs to the next day',
        );
      }
    });

    test('lastNDays spans exactly n calendar days', () {
      for (final n in [1, 7, 30, 90, 365]) {
        final r = lastNDays(n, now: DateTime(2026, 10, 26, 13, 5));
        expect(daysBetween(r.start, r.end), n - 1);
      }
    });
  });

  group('dailyTotals', () {
    // The crash this guards: inRangeInclusive used 24-hour arithmetic while
    // the day map was seeded with calendar days, so on a DST transition a
    // dose could pass the range check with no matching key and blow up on
    // a null assertion. Totals must be conserved and nothing may throw.
    test('every in-range dose lands in a seeded day, across a DST window', () {
      final start = DateTime(2026, 3, 27);
      final end = DateTime(2026, 4, 1);
      final doses = <Dosage>[];
      for (var d = 0; d < 6; d++) {
        for (final hour in [0, 1, 2, 12, 22, 23]) {
          doses.add(_dose(addDays(start, d).add(Duration(hours: hour)), 1));
        }
      }

      final totals = dailyTotals(doses, DateTimeRange(start: start, end: end));

      final inRange = doses
          .where((x) => inRangeInclusive(x.timestamp, start, end))
          .length;
      final summed = totals.values.fold(0.0, (a, b) => a + b);
      expect(summed, inRange.toDouble());
      expect(totals.keys.every((k) => k.hour == 0), isTrue);
    });

    test('October fall-back window conserves totals', () {
      final start = DateTime(2026, 10, 23);
      final end = DateTime(2026, 10, 27);
      final doses = [
        for (var d = 0; d < 5; d++)
          for (final hour in [0, 1, 23])
            _dose(addDays(start, d).add(Duration(hours: hour)), 2),
      ];

      final totals = dailyTotals(doses, DateTimeRange(start: start, end: end));
      final inRange = doses
          .where((x) => inRangeInclusive(x.timestamp, start, end))
          .length;
      expect(totals.values.fold(0.0, (a, b) => a + b), inRange * 2.0);
    });
  });
}
