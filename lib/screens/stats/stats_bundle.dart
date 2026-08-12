import 'package:flutter/material.dart';

import '../../domain/analytics_service.dart';
import '../../domain/date_utils.dart';
import '../../models/strain.dart';
import '../../providers/kratom_provider.dart';

/// No 7d. At four to six doses a day a week holds one weekend, one bad
/// night's sleep and maybe a rest day — enough to swing a percentage by
/// double digits and nowhere near enough to mean anything. Offering it only
/// invites a correction to noise.
enum StatsRange { thirty, ninety, all }

extension StatsRangeX on StatsRange {
  String get label => switch (this) {
        StatsRange.thirty => '30d',
        StatsRange.ninety => '90d',
        StatsRange.all => 'All',
      };

  int? get days => switch (this) {
        StatsRange.thirty => 30,
        StatsRange.ninety => 90,
        StatsRange.all => null,
      };

  /// How the drift sentence names this window.
  String get phrase => switch (this) {
        StatsRange.thirty => 'over the last 30 days',
        StatsRange.ninety => 'over the last 90 days',
        StatsRange.all => 'across your whole history',
      };
}

/// Trailing window for the trajectory line. Four weeks smooths the weekly
/// shape out of the picture without smoothing away a real month-long climb.
const int trajectoryWindowDays = 28;

/// Everything the page draws, computed once per range or data change.
class StatsBundle {
  final StatsRange selected;
  final DateTimeRange range;
  final DriftReading drift;

  /// Closed days inside the range, ascending. [dailyGrams] and [trend] are
  /// aligned to it index for index.
  final List<DateTime> days;
  final List<double> dailyGrams;
  final List<double> trend;

  final DayRhythm rhythm;
  final RotationSummary rotation;
  final DoseStats stats;
  final Map<String, Strain> strainsById;

  /// Any dose ever logged, versus any dose inside the selected range. An
  /// empty 30d window on top of a year of history is a different page from a
  /// brand new install.
  final bool hasHistory;
  final bool hasDataInRange;

  const StatsBundle({
    required this.selected,
    required this.range,
    required this.drift,
    required this.days,
    required this.dailyGrams,
    required this.trend,
    required this.rhythm,
    required this.rotation,
    required this.stats,
    required this.strainsById,
    required this.hasHistory,
    required this.hasDataInRange,
  });

  factory StatsBundle.compute(KratomProvider provider, StatsRange selected) {
    final now = DateTime.now();
    final today = startOfDay(now);
    final dosages = provider.dosages;

    DateTime? earliest;
    DateTime? latest;
    for (final dose in dosages) {
      final day = startOfDay(dose.timestamp);
      if (earliest == null || day.isBefore(earliest)) earliest = day;
      if (latest == null || day.isAfter(latest)) latest = day;
    }

    final DateTimeRange range;
    final windowDays = selected.days;
    if (windowDays != null) {
      range = lastNDays(windowDays, now: now);
    } else if (earliest == null) {
      range = lastNDays(1, now: now);
    } else {
      // Imported data can carry future timestamps and DateTimeRange asserts
      // start <= end, so run to the later of today and the last dose.
      range = DateTimeRange(
        start: earliest,
        end: latest!.isAfter(today) ? latest : today,
      );
    }

    // The trailing median needs a full window of history behind the left edge
    // of the chart, or the first four weeks of the line are computed from a
    // handful of days and sag for no reason the data supports. Reach back one
    // window — but never past the first dose he ever logged, where there is
    // no history to reach into and zeros would drag the line down.
    var chartStart = addDays(range.start, -(trajectoryWindowDays - 1));
    if (earliest != null && chartStart.isBefore(earliest)) chartStart = earliest;
    if (chartStart.isAfter(range.start)) chartStart = range.start;

    final chartFacts = closedDayFacts(
      dosages,
      DateTimeRange(start: chartStart, end: range.end),
      now: now,
    );
    final medians = trailingMedian(
      {for (final fact in chartFacts) fact.day: fact.grams},
      trajectoryWindowDays,
    );

    final days = <DateTime>[];
    final dailyGrams = <double>[];
    final trend = <double>[];
    for (var i = 0; i < chartFacts.length; i++) {
      if (chartFacts[i].day.isBefore(range.start)) continue;
      days.add(chartFacts[i].day);
      dailyGrams.add(chartFacts[i].grams);
      trend.add(medians[i].value);
    }

    final rotation = rotationSummary(dosages, range);

    return StatsBundle(
      selected: selected,
      range: range,
      drift: computeDrift(dosages, range, now: now),
      days: days,
      dailyGrams: dailyGrams,
      trend: trend,
      rhythm: computeDayRhythm(dosages, range),
      rotation: rotation,
      stats: computeDoseStats(dosages, range, now: now),
      strainsById: {for (final strain in provider.strains) strain.id: strain},
      hasHistory: dosages.isNotEmpty,
      hasDataInRange: rotation.totalGrams > 0,
    );
  }
}
