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

  test('rolling average is centred and uses available edge days', () {
    final daily = {
      DateTime(2025, 2, 1): 1.0,
      DateTime(2025, 2, 2): 3.0,
      DateTime(2025, 2, 3): 5.0,
      DateTime(2025, 2, 4): 7.0,
      DateTime(2025, 2, 5): 9.0,
    };

    final result = rollingAverage(daily, 3);

    expect(result.map((point) => point.value), [2, 3, 5, 7, 8]);
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
