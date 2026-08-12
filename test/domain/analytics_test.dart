import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/analytics_service.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';

void main() {
  final range = DateTimeRange(
    start: DateTime(2025, 2, 1),
    end: DateTime(2025, 2, 3),
  );

  test('computes dose stats, gaps, peak hour, and rest days', () {
    final doses = [
      _dose('1', 1, DateTime(2025, 2, 1, 8)),
      _dose('2', 2, DateTime(2025, 2, 1, 10)),
      _dose('3', 3, DateTime(2025, 2, 3, 10)),
    ];

    final stats = computeDoseStats(doses, range);

    expect(stats.totalDoses, 3);
    expect(stats.totalGrams, 6);
    expect(stats.avgPerDay, 2);
    expect(stats.avgDoseSize, 2);
    expect(stats.avgGapBetweenDoses, const Duration(hours: 25));
    expect(stats.peakHour, 10);
    expect(stats.activeDays, 2);
    expect(stats.restDays, 1);
    expect(stats.currentStreakDays, 1);
    expect(stats.longestRestStreak, 1);
  });

  // Was [2, 3, 5, 7, 8] when the window was centred. The window is trailing
  // now: a centred window computes the newest points — the ones actually read
  // as "where am I today" — from a half-width sample and from days that have
  // not happened, so the line lied precisely where it mattered most.
  test('rolling average trails: a point never sees a later day', () {
    final daily = {
      DateTime(2025, 2, 1): 1.0,
      DateTime(2025, 2, 2): 3.0,
      DateTime(2025, 2, 3): 5.0,
      DateTime(2025, 2, 4): 7.0,
      DateTime(2025, 2, 5): 9.0,
    };

    final result = rollingAverage(daily, 3);

    expect(result.map((point) => point.value), [1, 2, 3, 5, 7]);
  });

  test('an unfinished today does not break the streak or count as rest', () {
    final now = DateTime(2025, 2, 4, 9);
    final rangeToToday = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 4),
    );
    // Three dosed days, then a today with nothing logged yet.
    final doses = [
      _dose('1', 1, DateTime(2025, 2, 1, 8)),
      _dose('2', 2, DateTime(2025, 2, 2, 8)),
      _dose('3', 3, DateTime(2025, 2, 3, 8)),
    ];

    final stats = computeDoseStats(doses, rangeToToday, now: now);

    expect(stats.currentStreakDays, 3, reason: 'today is not yet a rest day');
    expect(stats.longestRestStreak, 0);
    expect(stats.restDays, 0);
    expect(stats.avgPerDay, 2, reason: '6g over 3 closed days, not 4');
  });

  test('once today has a dose it counts as an ordinary day', () {
    final now = DateTime(2025, 2, 4, 9);
    final rangeToToday = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 4),
    );
    final doses = [
      _dose('1', 1, DateTime(2025, 2, 1, 8)),
      _dose('2', 2, DateTime(2025, 2, 2, 8)),
      _dose('3', 3, DateTime(2025, 2, 3, 8)),
      _dose('4', 4, DateTime(2025, 2, 4, 8)),
    ];

    final stats = computeDoseStats(doses, rangeToToday, now: now);

    expect(stats.currentStreakDays, 4);
    expect(stats.avgPerDay, 2.5);
  });

  test('a genuine rest day before today still breaks the streak', () {
    final now = DateTime(2025, 2, 4, 9);
    final rangeToToday = DateTimeRange(
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 4),
    );
    // Feb 2 is a real, completed zero day.
    final doses = [
      _dose('1', 1, DateTime(2025, 2, 1, 8)),
      _dose('3', 3, DateTime(2025, 2, 3, 8)),
    ];

    final stats = computeDoseStats(doses, rangeToToday, now: now);

    expect(stats.currentStreakDays, 1);
    expect(stats.longestRestStreak, 1);
    expect(stats.restDays, 1);
  });

  test('hour histogram bins UTC timestamps by local hour', () {
    final local = DateTime(2025, 2, 1, 7, 30);
    final asUtc = local.toUtc();
    expect(asUtc.isUtc, isTrue);

    final histogram = hourHistogram([_dose('u', 1, asUtc)]);

    expect(histogram[local.hour], 1, reason: 'binned by the local wall clock');
    expect(histogram.reduce((a, b) => a + b), 1);
  });

  test('date ranges are half-open at the day after end', () {
    final doses = [
      _dose('in-start', 1, DateTime(2025, 2, 1)),
      _dose('in-end', 2, DateTime(2025, 2, 3, 23, 59, 59)),
      _dose('out', 100, DateTime(2025, 2, 4)),
    ];

    final totals = dailyTotals(doses, range);
    final stats = computeDoseStats(doses, range);

    expect(totals[DateTime(2025, 2, 1)], 1);
    expect(totals[DateTime(2025, 2, 3)], 2);
    expect(stats.totalDoses, 2);
    expect(stats.totalGrams, 3);
  });
}

Dosage _dose(String id, double amount, DateTime timestamp) => Dosage(
      id: id,
      strainId: 'strain',
      amount: amount,
      timestamp: timestamp,
    );
