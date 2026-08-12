import 'package:flutter/material.dart';

import '../models/dosage.dart';
import '../models/effect.dart';
import 'date_utils.dart';

class DoseStats {
  final int totalDoses;
  final double totalGrams;
  final double avgPerDay;
  final double avgDoseSize;
  final Duration? avgGapBetweenDoses;
  final int? peakHour;
  final int activeDays;
  final int restDays;
  final int currentStreakDays;
  final int longestRestStreak;

  const DoseStats({
    required this.totalDoses,
    required this.totalGrams,
    required this.avgPerDay,
    required this.avgDoseSize,
    required this.avgGapBetweenDoses,
    required this.peakHour,
    required this.activeDays,
    required this.restDays,
    required this.currentStreakDays,
    required this.longestRestStreak,
  });
}

/// [now] is injectable so the partial-day rule below is testable; it defaults
/// to the wall clock.
DoseStats computeDoseStats(
  List<Dosage> dosages,
  DateTimeRange range, {
  DateTime? now,
}) {
  final daily = dailyTotals(dosages, range);

  // A today that hasn't finished yet is not a completed rest day. Counted as
  // one it zeroed `currentStreakDays` every morning before the first dose,
  // padded `longestRestStreak`, and deflated `avgPerDay`. Drop it from the
  // closed-day metrics only while it is still empty and still the last day in
  // range; the moment it has a dose it counts like any other day.
  final closed = Map<DateTime, double>.from(daily);
  if (closed.isNotEmpty) {
    final today = startOfDay(now ?? DateTime.now());
    if (closed[today] == 0 && closed.keys.last == today) {
      closed.remove(today);
    }
  }
  final filtered = dosages
      .where((dose) => inRangeInclusive(dose.timestamp, range.start, range.end))
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final totalGrams = filtered.fold<double>(0, (sum, d) => sum + d.amount);
  final histogram = hourHistogram(filtered);
  final peakCount =
      histogram.fold<int>(0, (best, count) => count > best ? count : best);
  final activeDays = daily.values.where((grams) => grams > 0).length;

  Duration? averageGap;
  if (filtered.length > 1) {
    var totalMicroseconds = 0;
    for (var i = 1; i < filtered.length; i++) {
      totalMicroseconds += filtered[i]
          .timestamp
          .difference(filtered[i - 1].timestamp)
          .inMicroseconds;
    }
    averageGap = Duration(
      microseconds: (totalMicroseconds / (filtered.length - 1)).round(),
    );
  }

  var currentStreak = 0;
  for (final grams in closed.values.toList().reversed) {
    if (grams <= 0) break;
    currentStreak++;
  }

  var longestRest = 0;
  var runningRest = 0;
  for (final grams in closed.values) {
    if (grams == 0) {
      runningRest++;
      if (runningRest > longestRest) longestRest = runningRest;
    } else {
      runningRest = 0;
    }
  }

  return DoseStats(
    totalDoses: filtered.length,
    totalGrams: totalGrams,
    avgPerDay: closed.isEmpty ? 0 : totalGrams / closed.length,
    avgDoseSize: filtered.isEmpty ? 0 : totalGrams / filtered.length,
    avgGapBetweenDoses: averageGap,
    peakHour: peakCount == 0 ? null : histogram.indexOf(peakCount),
    activeDays: activeDays,
    restDays: closed.length - activeDays,
    currentStreakDays: currentStreak,
    longestRestStreak: longestRest,
  );
}

Map<DateTime, double> dailyTotals(List<Dosage> d, DateTimeRange range) {
  final start = startOfDay(range.start);
  final end = startOfDay(range.end);
  if (end.isBefore(start)) {
    throw ArgumentError('Date range end must not precede start');
  }

  final result = <DateTime, double>{};
  for (var day = start; !day.isAfter(end); day = _nextDay(day)) {
    result[day] = 0;
  }
  for (final dose in d) {
    if (inRangeInclusive(dose.timestamp, start, end)) {
      final day = startOfDay(dose.timestamp);
      // Tolerate a key the seeding loop didn't produce rather than crash the
      // stats screen; the DST fix in date_utils should make this unreachable.
      result[day] = (result[day] ?? 0) + dose.amount;
    }
  }
  return result;
}

List<int> hourHistogram(List<Dosage> dosages) {
  final result = List<int>.filled(24, 0);
  for (final dose in dosages) {
    // Localise first, like every other helper here: a UTC timestamp — which
    // an import can carry — reports the UTC hour and lands in the wrong bin.
    final t = dose.timestamp;
    result[(t.isUtc ? t.toLocal() : t).hour]++;
  }
  return result;
}

List<({DateTime day, double value})> rollingAverage(
  Map<DateTime, double> daily,
  int windowDays,
) {
  if (windowDays <= 0) {
    throw ArgumentError.value(
      windowDays,
      'windowDays',
      'must be greater than zero',
    );
  }
  final entries = daily.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final before = (windowDays - 1) ~/ 2;
  final after = windowDays ~/ 2;

  return [
    for (var i = 0; i < entries.length; i++)
      (
        day: entries[i].key,
        value: _mean(
          entries
              .sublist(
                (i - before).clamp(0, entries.length),
                (i + after + 1).clamp(0, entries.length),
              )
              .map((entry) => entry.value),
        ),
      ),
  ];
}

Map<String, Map<DateTime, double>> strainDailyTotals(
  List<Dosage> d,
  DateTimeRange range,
) {
  final strainIds = d
      .where((dose) => inRangeInclusive(dose.timestamp, range.start, range.end))
      .map((dose) => dose.strainId)
      .toSet();
  final result = <String, Map<DateTime, double>>{};
  for (final strainId in strainIds) {
    result[strainId] = dailyTotals(
      d.where((dose) => dose.strainId == strainId).toList(growable: false),
      range,
    );
  }
  return result;
}

class StrainInsight {
  final String strainId;
  final int totalDoses;
  final double totalGrams;
  final double avgDoseSize;
  final ({double p25, double median, double p75})? doseSpread;
  final Map<EffectMetric, double> avgEffects;
  final int effectSampleCount;
  final Duration? avgReportedDuration;
  final DateTime? firstUsed;
  final DateTime? lastUsed;

  const StrainInsight({
    required this.strainId,
    required this.totalDoses,
    required this.totalGrams,
    required this.avgDoseSize,
    required this.doseSpread,
    required this.avgEffects,
    required this.effectSampleCount,
    required this.avgReportedDuration,
    required this.firstUsed,
    required this.lastUsed,
  });
}

StrainInsight computeStrainInsight(
  String strainId,
  List<Dosage> all,
  List<Effect> effects,
) {
  final doses = all.where((dose) => dose.strainId == strainId).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final doseIds = doses.map((dose) => dose.id).toSet();
  final matchingEffects = effects
      .where((effect) => doseIds.contains(effect.dosageId))
      .toList(growable: false);
  final totalGrams = doses.fold<double>(0, (sum, dose) => sum + dose.amount);
  final sortedAmounts = doses.map((dose) => dose.amount).toList()..sort();
  final averages = <EffectMetric, double>{};

  for (final metric in EffectMetric.values) {
    final values = matchingEffects
        .map(metric.valueOf)
        .whereType<int>()
        .toList(growable: false);
    if (values.isNotEmpty) {
      averages[metric] = values.reduce((a, b) => a + b) / values.length;
    }
  }

  final durations = matchingEffects
      .map((effect) => effect.duration)
      .whereType<Duration>()
      .toList(growable: false);
  final totalDuration =
      durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);

  return StrainInsight(
    strainId: strainId,
    totalDoses: doses.length,
    totalGrams: totalGrams,
    avgDoseSize: doses.isEmpty ? 0 : totalGrams / doses.length,
    doseSpread: sortedAmounts.isEmpty
        ? null
        : (
            p25: _percentile(sortedAmounts, 0.25),
            median: _percentile(sortedAmounts, 0.5),
            p75: _percentile(sortedAmounts, 0.75),
          ),
    avgEffects: averages,
    effectSampleCount: matchingEffects.length,
    avgReportedDuration: durations.isEmpty
        ? null
        : Duration(microseconds: (totalDuration / durations.length).round()),
    firstUsed: doses.isEmpty ? null : doses.first.timestamp,
    lastUsed: doses.isEmpty ? null : doses.last.timestamp,
  );
}

DateTime _nextDay(DateTime day) => addDays(day, 1);

double _mean(Iterable<double> values) {
  var count = 0;
  var sum = 0.0;
  for (final value in values) {
    count++;
    sum += value;
  }
  return count == 0 ? 0 : sum / count;
}

double _percentile(List<double> sorted, double fraction) {
  if (sorted.length == 1) return sorted.single;
  final position = (sorted.length - 1) * fraction;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final weight = position - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * weight;
}
