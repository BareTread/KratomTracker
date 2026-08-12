import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/analytics_service.dart';
import 'package:kratom_tracker_plus/domain/date_utils.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';

void main() {
  group('trailingMedian', () {
    test('one wild day does not bend the line', () {
      final daily = {
        for (var i = 1; i <= 10; i++) DateTime(2025, 3, i): 3.0,
      };
      daily[DateTime(2025, 3, 5)] = 20.0;

      final median = trailingMedian(daily, 5);
      final mean = rollingAverage(daily, 5);

      // Every median point stays at the typical day. The mean carries the
      // outlier for the full width of the window — that is the whole reason
      // the trajectory line is a median.
      expect(median.map((p) => p.value), everyElement(3.0));
      expect(mean[4].value, closeTo(6.4, 0.001));
    });

    test('an even window averages the two middle days', () {
      final daily = {
        DateTime(2025, 3, 1): 1.0,
        DateTime(2025, 3, 2): 2.0,
        DateTime(2025, 3, 3): 8.0,
        DateTime(2025, 3, 4): 9.0,
      };

      expect(trailingMedian(daily, 4).last.value, closeTo(5.0, 0.001));
    });

    test('the first points use only the days that exist', () {
      final daily = {
        DateTime(2025, 3, 1): 4.0,
        DateTime(2025, 3, 2): 8.0,
      };

      final result = trailingMedian(daily, 28);

      expect(result.first.value, 4.0);
      expect(result.last.value, 6.0);
    });

    test('empty input yields no points, not a crash', () {
      expect(trailingMedian(const {}, 28), isEmpty);
    });

    test('a non-positive window is rejected', () {
      expect(() => trailingMedian(const {}, 0), throwsArgumentError);
    });
  });

  group('theilSen', () {
    test('recovers a straight line exactly', () {
      final fit = theilSen([
        for (var i = 0; i < 10; i++) (x: i.toDouble(), y: 2.0 + 0.5 * i),
      ]);

      expect(fit!.slope, closeTo(0.5, 1e-9));
      expect(fit.intercept, closeTo(2.0, 1e-9));
    });

    test('shrugs off a single 20g spike', () {
      final clean = [
        for (var i = 0; i < 20; i++) (x: i.toDouble(), y: 10.0 + 0.1 * i),
      ];
      final dirty = [...clean]..[9] = (x: 9.0, y: 40.0);

      final fit = theilSen(dirty)!;

      expect(fit.slope, closeTo(0.1, 0.02));
      expect(fit.intercept, closeTo(10.0, 0.3));
    });

    test('fewer than two points has no slope', () {
      expect(theilSen([(x: 1.0, y: 1.0)]), isNull);
      expect(theilSen(const []), isNull);
    });
  });

  group('closedDayFacts', () {
    test('counts grams and doses per day', () {
      final facts = closedDayFacts(
        [
          _dose('a', 2.5, DateTime(2025, 2, 1, 8)),
          _dose('b', 3.0, DateTime(2025, 2, 1, 14)),
          _dose('c', 2.0, DateTime(2025, 2, 3, 9)),
        ],
        DateTimeRange(start: DateTime(2025, 2, 1), end: DateTime(2025, 2, 3)),
        now: DateTime(2025, 3, 1),
      );

      expect(facts.map((f) => f.grams), [5.5, 0.0, 2.0]);
      expect(facts.map((f) => f.doses), [2, 0, 1]);
    });

    test('an unfinished, still-empty today is not a closed day', () {
      final facts = closedDayFacts(
        [_dose('a', 2.5, DateTime(2025, 2, 1, 8))],
        DateTimeRange(start: DateTime(2025, 2, 1), end: DateTime(2025, 2, 3)),
        now: DateTime(2025, 2, 3, 9),
      );

      expect(facts.length, 2);
      expect(facts.last.day, DateTime(2025, 2, 2));
    });

    test('today counts as soon as it has a dose', () {
      final facts = closedDayFacts(
        [
          _dose('a', 2.5, DateTime(2025, 2, 1, 8)),
          _dose('b', 1.0, DateTime(2025, 2, 3, 8)),
        ],
        DateTimeRange(start: DateTime(2025, 2, 1), end: DateTime(2025, 2, 3)),
        now: DateTime(2025, 2, 3, 9),
      );

      expect(facts.length, 3);
      expect(facts.last.grams, 1.0);
    });

    test('a UTC timestamp lands on its local day', () {
      final local = DateTime(2025, 2, 2, 0, 30);
      final facts = closedDayFacts(
        [_dose('a', 2.0, local.toUtc())],
        DateTimeRange(start: DateTime(2025, 2, 1), end: DateTime(2025, 2, 3)),
        now: DateTime(2025, 3, 1),
      );

      expect(facts[1].grams, 2.0);
      expect(facts[0].grams, 0.0);
    });

    test('a DST spring-forward day is still one day', () {
      // Europe/Bucharest loses an hour on 2025-03-30; a 24h-per-day walk
      // would skip or double a key here and drop the dose on the floor.
      final facts = closedDayFacts(
        [_dose('a', 3.0, DateTime(2025, 3, 30, 12))],
        DateTimeRange(start: DateTime(2025, 3, 29), end: DateTime(2025, 3, 31)),
        now: DateTime(2025, 4, 15),
      );

      expect(facts.map((f) => f.day), [
        DateTime(2025, 3, 29),
        DateTime(2025, 3, 30),
        DateTime(2025, 3, 31),
      ]);
      expect(facts[1].grams, 3.0);
    });

  });

  group('IntakeFactors', () {
    test('G is exactly F times A', () {
      final factors = IntakeFactors.of([
        (day: DateTime(2025, 2, 1), grams: 10.0, doses: 4),
        (day: DateTime(2025, 2, 2), grams: 8.0, doses: 3),
      ]);

      expect(factors.gramsPerDay, closeTo(9.0, 1e-9));
      expect(factors.dosesPerDay, closeTo(3.5, 1e-9));
      expect(
        factors.dosesPerDay * factors.gramsPerDose,
        closeTo(factors.gramsPerDay, 1e-9),
      );
    });

    test('no days and no doses are zero, never NaN', () {
      expect(IntakeFactors.of(const []).gramsPerDay, 0);
      final restOnly = IntakeFactors.of([
        (day: DateTime(2025, 2, 1), grams: 0.0, doses: 0),
      ]);
      expect(restOnly.gramsPerDose, 0);
      expect(restOnly.gramsPerDose.isNaN, isFalse);
    });
  });

  group('computeDrift', () {
    final range = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 3, 2),
    );
    final after = DateTime(2025, 4, 1);

    test('a flat month reads as steady', () {
      final drift = computeDrift(
        _series(30, doses: (_) => 4, size: (_) => 2.5),
        range,
        now: after,
      );

      expect(drift.direction, DriftDirection.steady);
      expect(drift.changePercent, closeTo(0, 0.001));
      expect(drift.driver, IntakeDriver.none);
      expect(drift.level.gramsPerDay, closeTo(10.0, 1e-9));
    });

    test('more doses at the same size reads as up, driven by frequency', () {
      final drift = computeDrift(
        _series(30, doses: (i) => 3 + (i ~/ 10), size: (_) => 2.5),
        range,
        now: after,
      );

      expect(drift.direction, DriftDirection.up);
      expect(drift.changePercent, greaterThan(20));
      expect(drift.driver, IntakeDriver.frequency);
      expect(drift.sizeChangePercent, closeTo(0, 0.001));
    });

    test('same doses at a bigger size reads as up, driven by size', () {
      final drift = computeDrift(
        _series(30, doses: (_) => 4, size: (i) => 2.0 + i * 0.05),
        range,
        now: after,
      );

      expect(drift.direction, DriftDirection.up);
      expect(drift.driver, IntakeDriver.size);
      expect(drift.dosesChangePercent, closeTo(0, 0.001));
      expect(drift.sizeChangePercent, greaterThan(50));
    });

    test('both factors moving together is reported as both', () {
      final drift = computeDrift(
        _series(30, doses: (i) => 3 + (i ~/ 15), size: (i) => 2.0 + i * 0.02),
        range,
        now: after,
      );

      expect(drift.direction, DriftDirection.up);
      expect(drift.driver, IntakeDriver.both);
    });

    test('a falling month reads as down', () {
      final drift = computeDrift(
        _series(30, doses: (i) => 6 - (i ~/ 10), size: (_) => 2.5),
        range,
        now: after,
      );

      expect(drift.direction, DriftDirection.down);
      expect(drift.changePercent, lessThan(-20));
    });

    test('one 20g day does not turn a steady month into a trend', () {
      final doses = _series(30, doses: (_) => 4, size: (_) => 2.5)
        ..add(_dose('spike', 20, DateTime(2025, 2, 25, 23)));

      final drift = computeDrift(doses, range, now: after);

      expect(drift.direction, DriftDirection.steady);
    });

    test('a rest day does not read as a shrinking dose', () {
      // Day 15 is a rest day. Dose size is unchanged on every day he dosed,
      // so the size factor must be flat rather than dragged toward zero.
      final doses = _series(30, doses: (i) => i == 14 ? 0 : 4, size: (_) => 2.5);

      final drift = computeDrift(doses, range, now: after);

      expect(drift.sizeChangePercent, closeTo(0, 0.001));
    });

    test('too little history says nothing', () {
      final short = DateTimeRange(
        start: DateTime(2025, 2, 1),
        end: DateTime(2025, 2, 5),
      );
      final drift = computeDrift(
        [_dose('a', 2.5, DateTime(2025, 2, 1, 8))],
        short,
        now: after,
      );

      expect(drift.direction, DriftDirection.unknown);
      expect(drift.changePercent, isNull);
      expect(drift.driver, IntakeDriver.none);
    });

    test('a month of days with three doses in it is not a month of data', () {
      final drift = computeDrift(
        [
          _dose('a', 2.5, DateTime(2025, 2, 3, 8)),
          _dose('b', 2.5, DateTime(2025, 2, 14, 8)),
          _dose('c', 2.5, DateTime(2025, 2, 27, 8)),
        ],
        range,
        now: after,
      );

      expect(drift.direction, DriftDirection.unknown);
      expect(drift.windowDays, 30);
    });

    test('a single empty day is zeros, not NaN', () {
      final oneDay = DateTimeRange(
        start: DateTime(2025, 2, 1),
        end: DateTime(2025, 2, 1),
      );
      final drift = computeDrift(const [], oneDay, now: after);

      expect(drift.direction, DriftDirection.unknown);
      expect(drift.level.gramsPerDay, 0);
      expect(drift.level.gramsPerDose.isNaN, isFalse);
    });

    test('an empty month has no drift and no divide by zero', () {
      final drift = computeDrift(const [], range, now: after);

      expect(drift.direction, DriftDirection.unknown);
      expect(drift.level.gramsPerDay, 0);
      expect(drift.windowDays, 30);
    });

    test('the level reads the present, not the whole range', () {
      // Four quiet weeks then four heavy ones: the level is where he is now.
      final doses = _series(56, doses: (i) => i < 28 ? 2 : 6, size: (_) => 2.0);
      final long = DateTimeRange(
        start: DateTime(2025, 2, 1),
        end: DateTime(2025, 3, 28),
      );

      final drift = computeDrift(doses, long, now: after);

      expect(drift.level.days, 28);
      expect(drift.level.gramsPerDay, closeTo(12.0, 1e-9));
      expect(drift.direction, DriftDirection.up);
    });
  });

  group('computeDayRhythm', () {
    final range = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 3),
    );

    test('finds the peak hour and the typical first and last dose', () {
      final rhythm = computeDayRhythm(
        [
          _dose('a', 2, DateTime(2025, 2, 1, 8, 0)),
          _dose('b', 2, DateTime(2025, 2, 1, 13, 0)),
          _dose('c', 2, DateTime(2025, 2, 1, 21, 0)),
          _dose('d', 2, DateTime(2025, 2, 2, 9, 0)),
          _dose('e', 2, DateTime(2025, 2, 2, 13, 30)),
          _dose('f', 2, DateTime(2025, 2, 2, 22, 0)),
          _dose('g', 2, DateTime(2025, 2, 3, 13, 45)),
        ],
        range,
      );

      expect(rhythm.peakHour, 13);
      expect(rhythm.dosedDays, 3);
      // Firsts 8:00 / 9:00 / 13:45 → median 9:00. Lasts 21:00 / 22:00 /
      // 13:45 → median 21:00.
      expect(rhythm.medianFirstMinute, 9 * 60);
      expect(rhythm.medianLastMinute, 21 * 60);
    });

    test('a UTC timestamp is binned by the local wall clock', () {
      final local = DateTime(2025, 2, 1, 7, 30);
      final rhythm = computeDayRhythm([_dose('u', 2, local.toUtc())], range);

      expect(rhythm.peakHour, local.hour);
      expect(rhythm.medianFirstMinute, local.hour * 60 + 30);
    });

    test('no doses leaves every field empty rather than zero-by-accident', () {
      final rhythm = computeDayRhythm(const [], range);

      expect(rhythm.peakHour, isNull);
      expect(rhythm.medianFirstMinute, isNull);
      expect(rhythm.hours, hasLength(24));
      expect(rhythm.dosedDays, 0);
    });
  });

  group('rotationSummary', () {
    final range = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 28),
    );

    List<Dosage> library(int strains, {double Function(int)? gramsFor}) {
      return [
        for (var s = 0; s < strains; s++)
          _dose(
            'd$s',
            gramsFor?.call(s) ?? (strains - s).toDouble(),
            DateTime(2025, 2, 1 + (s % 20), 9),
            strainId: 'strain-$s',
          ),
      ];
    }

    test('keeps the top eight and folds the rest into one row', () {
      final summary = rotationSummary(library(12), range);

      expect(summary.strainCount, 12);
      expect(summary.rows, hasLength(9));
      expect(
        summary.rows.take(8).map((r) => r.strainId),
        [
          'strain-0',
          'strain-1',
          'strain-2',
          'strain-3',
          'strain-4',
          'strain-5',
          'strain-6',
          'strain-7',
        ],
      );
      expect(summary.tail!.strainId, isNull);
      expect(summary.tail!.strainCount, 4);
    });

    test('shares add up to the whole range', () {
      final summary = rotationSummary(library(12), range);
      final total = summary.rows.fold<double>(0, (sum, r) => sum + r.share);

      expect(total, closeTo(1.0, 1e-9));
    });

    test('eight or fewer strains have no tail row', () {
      final summary = rotationSummary(library(8), range);

      expect(summary.rows, hasLength(8));
      expect(summary.tail, isNull);
    });

    test('a quarter of intake on one strain trips the flag', () {
      final leaning = [
        _dose('big', 40, DateTime(2025, 2, 1, 9), strainId: 'a'),
        _dose('s1', 30, DateTime(2025, 2, 2, 9), strainId: 'b'),
        _dose('s2', 30, DateTime(2025, 2, 3, 9), strainId: 'c'),
        _dose('s3', 30, DateTime(2025, 2, 4, 9), strainId: 'd'),
      ];

      final summary = rotationSummary(leaning, range);

      expect(summary.topShare, closeTo(40 / 130, 1e-9));
      expect(summary.concentrated, isTrue);
    });

    test('an even rotation does not trip the flag', () {
      final summary = rotationSummary(library(10, gramsFor: (_) => 5), range);

      expect(summary.concentrated, isFalse);
    });

    test('counts distinct days per strain, and across the folded tail', () {
      final summary = rotationSummary(
        [
          _dose('a1', 2, DateTime(2025, 2, 1, 9), strainId: 'a'),
          _dose('a2', 2, DateTime(2025, 2, 1, 18), strainId: 'a'),
          _dose('a3', 2, DateTime(2025, 2, 2, 9), strainId: 'a'),
          _dose('b1', 1, DateTime(2025, 2, 3, 9), strainId: 'b'),
        ],
        range,
        topCount: 1,
      );

      expect(summary.rows.first.daysUsed, 2);
      expect(summary.rows.first.doses, 3);
      expect(summary.tail!.daysUsed, 1);
    });

    test('doses outside the range are ignored', () {
      final summary = rotationSummary(
        [
          _dose('in', 5, DateTime(2025, 2, 10, 9), strainId: 'a'),
          _dose('out', 500, DateTime(2025, 1, 10, 9), strainId: 'b'),
        ],
        range,
      );

      expect(summary.strainCount, 1);
      expect(summary.totalGrams, 5);
    });

    test('no doses is an empty summary, not a crash', () {
      final summary = rotationSummary(const [], range);

      expect(summary.rows, isEmpty);
      expect(summary.topShare, 0);
      expect(summary.concentrated, isFalse);
    });
  });
}

/// [doses] and [size] are read per day index, so a test can move one factor
/// of `G = F × A` while pinning the other.
List<Dosage> _series(
  int days, {
  required int Function(int day) doses,
  required double Function(int day) size,
}) {
  final result = <Dosage>[];
  for (var i = 0; i < days; i++) {
    final day = addDays(DateTime(2025, 2, 1), i);
    for (var n = 0; n < doses(i); n++) {
      result.add(
        _dose(
          '$i-$n',
          size(i),
          DateTime(day.year, day.month, day.day, 8 + n * 3),
        ),
      );
    }
  }
  return result;
}

Dosage _dose(
  String id,
  double amount,
  DateTime timestamp, {
  String strainId = 'strain',
}) =>
    Dosage(
      id: id,
      strainId: strainId,
      amount: amount,
      timestamp: timestamp,
    );
