import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dosage.dart';
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
  final today = startOfDay(now ?? DateTime.now());
  final requestedStart = startOfDay(range.start);
  final requestedEnd = startOfDay(range.end);
  final boundedRange = DateTimeRange(
    start: requestedStart.isAfter(today) ? today : requestedStart,
    end: requestedEnd.isAfter(today) ? today : requestedEnd,
  );
  final daily = dailyTotals(dosages, boundedRange);

  // A today that hasn't finished yet is not a completed rest day. Counted as
  // one it zeroed `currentStreakDays` every morning before the first dose,
  // padded `longestRestStreak`, and deflated `avgPerDay`. Drop it from the
  // closed-day metrics only while it is still empty and still the last day in
  // range; the moment it has a dose it counts like any other day.
  final closed = Map<DateTime, double>.from(daily);
  if (closed.isNotEmpty) {
    if (closed[today] == 0 && closed.keys.last == today) {
      closed.remove(today);
    }
  }
  final filtered = dosages
      .where(
        (dose) => inRangeInclusive(
          dose.timestamp,
          boundedRange.start,
          boundedRange.end,
        ),
      )
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

/// A trailing window over [daily], summarised by [reduce].
///
/// Trailing, never centred. A centred window borrows from days that have not
/// happened yet, so its right-hand end — the part actually being read, "where
/// am I now" — is computed from a truncated, half-width sample and lags or
/// overshoots the present. Every point here answers "this day and the
/// [windowDays] - 1 before it", which is a claim the data can support.
List<({DateTime day, double value})> trailingWindow(
  Map<DateTime, double> daily,
  int windowDays,
  double Function(List<double>) reduce,
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

  return [
    for (var i = 0; i < entries.length; i++)
      (
        day: entries[i].key,
        value: reduce(
          [
            for (var j = math.max(0, i - windowDays + 1); j <= i; j++)
              entries[j].value,
          ],
        ),
      ),
  ];
}

List<({DateTime day, double value})> rollingAverage(
  Map<DateTime, double> daily,
  int windowDays,
) =>
    trailingWindow(daily, windowDays, (window) => _mean(window));

/// Trailing median of daily grams — the trajectory line.
///
/// Median rather than mean: one 20g day is a story about that day, not about
/// the month, and a mean lets it bend the trend for the whole width of the
/// window. The median moves only when the middle of the distribution moves.
List<({DateTime day, double value})> trailingMedian(
  Map<DateTime, double> daily,
  int windowDays,
) =>
    trailingWindow(daily, windowDays, _median);

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
  final DateTime? firstUsed;
  final DateTime? lastUsed;

  const StrainInsight({
    required this.strainId,
    required this.totalDoses,
    required this.totalGrams,
    required this.avgDoseSize,
    required this.doseSpread,
    required this.firstUsed,
    required this.lastUsed,
  });
}

StrainInsight computeStrainInsight(
  String strainId,
  List<Dosage> all,
) {
  final doses = all.where((dose) => dose.strainId == strainId).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final totalGrams = doses.fold<double>(0, (sum, dose) => sum + dose.amount);
  final sortedAmounts = doses.map((dose) => dose.amount).toList()..sort();

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
    firstUsed: doses.isEmpty ? null : doses.first.timestamp,
    lastUsed: doses.isEmpty ? null : doses.last.timestamp,
  );
}

// ---------------------------------------------------------------------------
// Daily facts — the backbone every drift number is derived from
// ---------------------------------------------------------------------------

/// Grams and dose count for one calendar day.
typedef DayFacts = ({DateTime day, double grams, int doses});

/// One row per calendar day in [range], with the unfinished-today rule from
/// [computeDoseStats] applied: a today that is still empty and still the last
/// day in range has not had its chance to happen, so it is not a closed day
/// and is left out. Counting it drags every average down every morning.
List<DayFacts> closedDayFacts(
  List<Dosage> dosages,
  DateTimeRange range, {
  DateTime? now,
}) {
  // Same today-cap as [computeDoseStats]: an All range that runs to a
  // future-dated import must not seed empty days as rest.
  final today = startOfDay(now ?? DateTime.now());
  final requestedStart = startOfDay(range.start);
  final requestedEnd = startOfDay(range.end);
  final start = requestedStart.isAfter(today) ? today : requestedStart;
  final end = requestedEnd.isAfter(today) ? today : requestedEnd;
  if (end.isBefore(start)) {
    throw ArgumentError('Date range end must not precede start');
  }

  final grams = <DateTime, double>{};
  final counts = <DateTime, int>{};
  for (var day = start; !day.isAfter(end); day = _nextDay(day)) {
    grams[day] = 0;
    counts[day] = 0;
  }
  for (final dose in dosages) {
    if (!inRangeInclusive(dose.timestamp, start, end)) continue;
    final day = startOfDay(dose.timestamp);
    grams[day] = (grams[day] ?? 0) + dose.amount;
    counts[day] = (counts[day] ?? 0) + 1;
  }

  if (grams[end] == 0 && end == today) {
    grams.remove(end);
    counts.remove(end);
  }

  final days = grams.keys.toList()..sort();
  return [
    for (final day in days) (day: day, grams: grams[day]!, doses: counts[day]!),
  ];
}

// ---------------------------------------------------------------------------
// G = F × A
// ---------------------------------------------------------------------------

/// Daily grams split into its two factors: how often, and how much each time.
/// `gramsPerDay == dosesPerDay * gramsPerDose` exactly, by construction. The
/// split is the whole point — the same rise in [gramsPerDay] means something
/// different depending on which factor moved.
class IntakeFactors {
  final double gramsPerDay; // G
  final double dosesPerDay; // F
  final double gramsPerDose; // A
  final double grams;
  final int doses;
  final int days;

  const IntakeFactors({
    required this.gramsPerDay,
    required this.dosesPerDay,
    required this.gramsPerDose,
    required this.grams,
    required this.doses,
    required this.days,
  });

  static const none = IntakeFactors(
    gramsPerDay: 0,
    dosesPerDay: 0,
    gramsPerDose: 0,
    grams: 0,
    doses: 0,
    days: 0,
  );

  factory IntakeFactors.of(List<DayFacts> facts) {
    if (facts.isEmpty) return none;
    var grams = 0.0;
    var doses = 0;
    for (final fact in facts) {
      grams += fact.grams;
      doses += fact.doses;
    }
    return IntakeFactors(
      gramsPerDay: grams / facts.length,
      dosesPerDay: doses / facts.length,
      gramsPerDose: doses == 0 ? 0 : grams / doses,
      grams: grams,
      doses: doses,
      days: facts.length,
    );
  }
}

// ---------------------------------------------------------------------------
// Drift
// ---------------------------------------------------------------------------

enum DriftDirection { up, down, steady, unknown }

/// Which factor of `G = F × A` carries a drift.
enum IntakeDriver { none, frequency, size, both }

/// A straight line fitted to a day series.
typedef Fit = ({double slope, double intercept});

/// Theil–Sen: slope is the median of every pairwise slope, intercept the
/// median residual. Least squares would let a single 20g day tilt the whole
/// line; a median of pairwise slopes barely notices it. That robustness is
/// what makes the drift verb trustworthy enough to print as a sentence.
Fit? theilSen(List<({double x, double y})> points) {
  if (points.length < 2) return null;
  final slopes = <double>[];
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final dx = points[j].x - points[i].x;
      if (dx == 0) continue;
      slopes.add((points[j].y - points[i].y) / dx);
    }
  }
  if (slopes.isEmpty) return null;
  final slope = _median(slopes);
  return (
    slope: slope,
    intercept: _median([for (final p in points) p.y - slope * p.x]),
  );
}

/// The headline: which way intake is moving, by how much, and driven by what.
class DriftReading {
  final DriftDirection direction;

  /// Signed percent change in daily grams across [windowDays], from the
  /// robust fit. Null when the window starts at all but zero, where a
  /// percentage would be meaningless rather than merely large.
  final double? changePercent;
  final double? dosesChangePercent;
  final double? sizeChangePercent;
  final IntakeDriver driver;

  /// Where he is *now* — the most recent [IntakeFactors.days] closed days.
  /// Deliberately independent of the selected range: how far back you look
  /// changes the trend, not the present.
  final IntakeFactors level;

  /// Closed days the trend was fitted over.
  final int windowDays;

  const DriftReading({
    required this.direction,
    required this.changePercent,
    required this.dosesChangePercent,
    required this.sizeChangePercent,
    required this.driver,
    required this.level,
    required this.windowDays,
  });
}

/// Days of recent history the "now" level is averaged over. Four weeks: long
/// enough that a heavy weekend does not move it, short enough to be current.
const int driftLevelDays = 28;

/// Below this the trend is called steady. Four to six doses a day wobble by
/// a few percent on their own; naming that a trend would invite a correction
/// to noise.
const double driftSteadyBandPercent = 8;

/// Fewer closed days than this and there is nothing honest to say.
const int driftMinDays = 10;

/// A month of days is not a month of data if only two of them have a dose in
/// them. A trend needs days that actually happened.
const int driftMinDosedDays = 5;

DriftReading computeDrift(
  List<Dosage> dosages,
  DateTimeRange range, {
  DateTime? now,
  int levelDays = driftLevelDays,
  double steadyBandPercent = driftSteadyBandPercent,
}) {
  final facts = closedDayFacts(dosages, range, now: now);
  final level = IntakeFactors.of(
    facts.length <= levelDays ? facts : facts.sublist(facts.length - levelDays),
  );

  final dosedDays = facts.where((fact) => fact.doses > 0).length;
  if (facts.length < driftMinDays ||
      dosedDays < driftMinDosedDays ||
      level.doses == 0) {
    return DriftReading(
      direction: DriftDirection.unknown,
      changePercent: null,
      dosesChangePercent: null,
      sizeChangePercent: null,
      driver: IntakeDriver.none,
      level: level,
      windowDays: facts.length,
    );
  }

  final origin = facts.first.day;
  double x(DayFacts fact) => daysBetween(origin, fact.day).toDouble();
  final span = x(facts.last);

  final gramsFit = theilSen([for (final f in facts) (x: x(f), y: f.grams)]);
  final dosesFit =
      theilSen([for (final f in facts) (x: x(f), y: f.doses.toDouble())]);
  // Dose size is undefined on a rest day — a zero there would read as
  // "shrinking doses" when he simply did not take any.
  final sizeFit = theilSen([
    for (final f in facts)
      if (f.doses > 0) (x: x(f), y: f.grams / f.doses),
  ]);

  final gramsPercent = _fitChangePercent(gramsFit, span);
  final dosesPercent = _fitChangePercent(dosesFit, span);
  final sizePercent = _fitChangePercent(sizeFit, span);

  final DriftDirection direction;
  if (gramsPercent != null) {
    direction = gramsPercent.abs() < steadyBandPercent
        ? DriftDirection.steady
        : (gramsPercent > 0 ? DriftDirection.up : DriftDirection.down);
  } else if (gramsFit != null && gramsFit.slope != 0) {
    direction = gramsFit.slope > 0 ? DriftDirection.up : DriftDirection.down;
  } else {
    direction = DriftDirection.steady;
  }

  return DriftReading(
    direction: direction,
    changePercent: gramsPercent,
    dosesChangePercent: dosesPercent,
    sizeChangePercent: sizePercent,
    driver: _driverOf(direction, dosesPercent, sizePercent),
    level: level,
    windowDays: facts.length,
  );
}

IntakeDriver _driverOf(
  DriftDirection direction,
  double? dosesPercent,
  double? sizePercent,
) {
  if (direction != DriftDirection.up && direction != DriftDirection.down) {
    return IntakeDriver.none;
  }
  final frequency = (dosesPercent ?? 0).abs();
  final size = (sizePercent ?? 0).abs();
  final largest = math.max(frequency, size);
  if (largest == 0) return IntakeDriver.none;
  final agree = dosesPercent != null &&
      sizePercent != null &&
      (dosesPercent >= 0) == (sizePercent >= 0);
  // "Both" only when the two factors genuinely share the load; otherwise
  // naming one of them is the more useful sentence.
  if (agree && math.min(frequency, size) >= 0.45 * largest) {
    return IntakeDriver.both;
  }
  return frequency >= size ? IntakeDriver.frequency : IntakeDriver.size;
}

double? _fitChangePercent(Fit? fit, double span) {
  if (fit == null || span <= 0) return null;
  final start = fit.intercept;
  // Percent change off a baseline of essentially zero is a divide-by-noise,
  // not a large number. Say nothing rather than "+4000%".
  if (start <= 0.05) return null;
  return ((start + fit.slope * span) - start) / start * 100;
}

// ---------------------------------------------------------------------------
// Rhythm — when the doses land
// ---------------------------------------------------------------------------

class DayRhythm {
  /// 24 counts, one per local hour.
  final List<int> hours;
  final int? peakHour;

  /// Median minute-of-day of the first and last dose of a dosed day, so the
  /// span reads as "most days run 8am to 10pm" rather than as two extremes.
  final int? medianFirstMinute;
  final int? medianLastMinute;
  final int dosedDays;

  const DayRhythm({
    required this.hours,
    required this.peakHour,
    required this.medianFirstMinute,
    required this.medianLastMinute,
    required this.dosedDays,
  });
}

DayRhythm computeDayRhythm(List<Dosage> dosages, DateTimeRange range) {
  final inRange = dosages
      .where((dose) => inRangeInclusive(dose.timestamp, range.start, range.end))
      .toList(growable: false);
  final hours = hourHistogram(inRange);
  final peakCount = hours.fold<int>(0, (best, n) => n > best ? n : best);

  final firsts = <DateTime, int>{};
  final lasts = <DateTime, int>{};
  for (final dose in inRange) {
    final local =
        dose.timestamp.isUtc ? dose.timestamp.toLocal() : dose.timestamp;
    final day = startOfDay(local);
    final minute = local.hour * 60 + local.minute;
    firsts[day] = math.min(firsts[day] ?? minute, minute);
    lasts[day] = math.max(lasts[day] ?? minute, minute);
  }

  return DayRhythm(
    hours: hours,
    peakHour: peakCount == 0 ? null : hours.indexOf(peakCount),
    medianFirstMinute: firsts.isEmpty
        ? null
        : _median(firsts.values.map((m) => m.toDouble()).toList()).round(),
    medianLastMinute: lasts.isEmpty
        ? null
        : _median(lasts.values.map((m) => m.toDouble()).toList()).round(),
    dosedDays: firsts.length,
  );
}

// ---------------------------------------------------------------------------
// Rotation
// ---------------------------------------------------------------------------

/// One strain's slice of the range, or the folded tail when [strainId] is null.
class StrainShare {
  final String? strainId;

  /// How many strains this row stands for — 1, or the size of the tail.
  final int strainCount;
  final double grams;
  final int doses;
  final int daysUsed;

  /// 0–1 of the range's total grams.
  final double share;

  const StrainShare({
    required this.strainId,
    required this.strainCount,
    required this.grams,
    required this.doses,
    required this.daysUsed,
    required this.share,
  });
}

class RotationSummary {
  /// Top strains by grams, then the folded tail last when there is one.
  final List<StrainShare> rows;
  final StrainShare? tail;
  final int strainCount;
  final double totalGrams;

  const RotationSummary({
    required this.rows,
    required this.tail,
    required this.strainCount,
    required this.totalGrams,
  });

  double get topShare => rows.isEmpty ? 0 : rows.first.share;

  /// One strain carrying a quarter of everything is the shape tolerance
  /// builds in. Two strains at 30 doses each is rotation; one at 60 is not.
  bool get concentrated =>
      rows.isNotEmpty &&
      rows.first.strainId != null &&
      rows.first.share >= rotationConcentrationShare;
}

const int rotationTopCount = 8;
const double rotationConcentrationShare = 0.25;

RotationSummary rotationSummary(
  List<Dosage> dosages,
  DateTimeRange range, {
  int topCount = rotationTopCount,
}) {
  final grams = <String, double>{};
  final doses = <String, int>{};
  final days = <String, Set<DateTime>>{};
  var totalGrams = 0.0;

  for (final dose in dosages) {
    if (!inRangeInclusive(dose.timestamp, range.start, range.end)) continue;
    grams[dose.strainId] = (grams[dose.strainId] ?? 0) + dose.amount;
    doses[dose.strainId] = (doses[dose.strainId] ?? 0) + 1;
    (days[dose.strainId] ??= <DateTime>{}).add(startOfDay(dose.timestamp));
    totalGrams += dose.amount;
  }

  if (grams.isEmpty) {
    return const RotationSummary(
      rows: [],
      tail: null,
      strainCount: 0,
      totalGrams: 0,
    );
  }

  final ranked = grams.keys.toList()
    ..sort((a, b) {
      final byGrams = grams[b]!.compareTo(grams[a]!);
      // Stable, so a redraw cannot shuffle two strains that tie.
      return byGrams != 0 ? byGrams : a.compareTo(b);
    });

  double shareOf(double g) => totalGrams <= 0 ? 0 : g / totalGrams;

  final head = ranked.take(topCount).toList();
  final rows = [
    for (final id in head)
      StrainShare(
        strainId: id,
        strainCount: 1,
        grams: grams[id]!,
        doses: doses[id]!,
        daysUsed: days[id]!.length,
        share: shareOf(grams[id]!),
      ),
  ];

  StrainShare? tail;
  final rest = ranked.skip(topCount).toList();
  if (rest.isNotEmpty) {
    var tailGrams = 0.0;
    var tailDoses = 0;
    final tailDays = <DateTime>{};
    for (final id in rest) {
      tailGrams += grams[id]!;
      tailDoses += doses[id]!;
      tailDays.addAll(days[id]!);
    }
    tail = StrainShare(
      strainId: null,
      strainCount: rest.length,
      grams: tailGrams,
      doses: tailDoses,
      daysUsed: tailDays.length,
      share: shareOf(tailGrams),
    );
    rows.add(tail);
  }

  return RotationSummary(
    rows: rows,
    tail: tail,
    strainCount: ranked.length,
    totalGrams: totalGrams,
  );
}

// ---------------------------------------------------------------------------
// Totals
// ---------------------------------------------------------------------------

/// Everything ever logged, independent of the selected range.
///
/// [daysTracked] counts calendar days from the first dose to today inclusive,
/// so it is the span he has been keeping records over — not the number of days
/// he dosed, which is [activeDays]. The two differ by his rest days, and the
/// gap between them is the point of showing both.
class GrandTotals {
  final double grams;
  final int doses;
  final int daysTracked;
  final int activeDays;
  final int strainsUsed;
  final DateTime? firstDose;
  final DateTime? lastDose;

  const GrandTotals({
    required this.grams,
    required this.doses,
    required this.daysTracked,
    required this.activeDays,
    required this.strainsUsed,
    required this.firstDose,
    required this.lastDose,
  });

  static const none = GrandTotals(
    grams: 0,
    doses: 0,
    daysTracked: 0,
    activeDays: 0,
    strainsUsed: 0,
    firstDose: null,
    lastDose: null,
  );

  /// Mean grams on the days he actually dosed. Distinct from
  /// [IntakeFactors.gramsPerDay], which spreads the same grams across rest
  /// days too and therefore always reads lower.
  double get gramsPerActiveDay => activeDays == 0 ? 0 : grams / activeDays;

  double get dosesPerActiveDay => activeDays == 0 ? 0 : doses / activeDays;

  double get gramsPerDose => doses == 0 ? 0 : grams / doses;
}

GrandTotals grandTotals(List<Dosage> dosages, {DateTime? now}) {
  if (dosages.isEmpty) return GrandTotals.none;

  var grams = 0.0;
  DateTime? first;
  DateTime? last;
  final activeDays = <DateTime>{};
  final strains = <String>{};
  for (final dose in dosages) {
    grams += dose.amount;
    final local =
        dose.timestamp.isUtc ? dose.timestamp.toLocal() : dose.timestamp;
    if (first == null || local.isBefore(first)) first = local;
    if (last == null || local.isAfter(last)) last = local;
    activeDays.add(startOfDay(local));
    strains.add(dose.strainId);
  }

  // An import can carry a dose dated ahead of the wall clock; clamp so the
  // span never reads as negative.
  final today = startOfDay(now ?? DateTime.now());
  final end = last!.isAfter(today) ? startOfDay(last) : today;

  return GrandTotals(
    grams: grams,
    doses: dosages.length,
    daysTracked: daysBetween(first!, end) + 1,
    activeDays: activeDays.length,
    strainsUsed: strains.length,
    firstDose: first,
    lastDose: last,
  );
}

/// The same factors as [IntakeFactors.of], but over dosed days only.
IntakeFactors activeDayFactors(List<DayFacts> facts) => IntakeFactors.of([
      for (final f in facts)
        if (f.doses > 0) f,
    ]);

// ---------------------------------------------------------------------------
// Weekday
// ---------------------------------------------------------------------------

/// Mean grams per weekday, indexed [DateTime.monday] - 1 .. [DateTime.sunday] - 1.
///
/// Averaged per occurrence, never summed: a 30-day window holds five of some
/// weekdays and four of others, so totals would crown whichever weekday the
/// window happened to contain more of.
class WeekdayRhythm {
  final List<double> gramsByWeekday;
  final List<int> daysByWeekday;

  /// Null until every weekday has been seen [minOccurrences] times. A 30-day
  /// window holds four or five of each weekday, which is not enough for the
  /// heaviest one to mean anything — the winner changes week to week. At a
  /// full quarter it starts to hold still.
  final int? busiest;
  final int? quietest;

  static const minOccurrences = 12;

  const WeekdayRhythm({
    required this.gramsByWeekday,
    required this.daysByWeekday,
    required this.busiest,
    required this.quietest,
  });

  static const none = WeekdayRhythm(
    gramsByWeekday: [0, 0, 0, 0, 0, 0, 0],
    daysByWeekday: [0, 0, 0, 0, 0, 0, 0],
    busiest: null,
    quietest: null,
  );
}

WeekdayRhythm computeWeekdayRhythm(List<DayFacts> facts) {
  if (facts.isEmpty) return WeekdayRhythm.none;

  final totals = List<double>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  for (final fact in facts) {
    final index = fact.day.weekday - 1;
    totals[index] += fact.grams;
    counts[index]++;
  }

  final means = [
    for (var i = 0; i < 7; i++) counts[i] == 0 ? 0.0 : totals[i] / counts[i],
  ];

  final enough = counts.every((count) => count >= WeekdayRhythm.minOccurrences);
  int? busiest;
  int? quietest;
  if (enough) {
    for (var i = 0; i < 7; i++) {
      if (busiest == null || means[i] > means[busiest]) busiest = i;
      if (quietest == null || means[i] < means[quietest]) quietest = i;
    }
    // A flat week has no busiest day worth naming.
    if (means[busiest!] - means[quietest!] < means[busiest] * 0.08) {
      busiest = null;
      quietest = null;
    }
  }

  return WeekdayRhythm(
    gramsByWeekday: means,
    daysByWeekday: counts,
    busiest: busiest,
    quietest: quietest,
  );
}

// ---------------------------------------------------------------------------
// Spacing
// ---------------------------------------------------------------------------

/// How far apart doses sit, counting only pairs inside the same calendar day.
///
/// The naive version — every consecutive pair across the whole range — folds
/// the overnight break into the average and converges on `24h / dosesPerDay`
/// regardless of how the day is actually shaped. That number looks like a
/// spacing measurement and is really just the dose count in disguise. Same-day
/// pairs measure the thing the name promises.
class DoseSpacing {
  final Duration? median;
  final Duration? shortest;

  /// Same-day consecutive pairs seen, and the days they came from. The days
  /// are the effective sample size — see [computeDoseSpacing].
  final int samples;
  final int days;

  const DoseSpacing({
    required this.median,
    required this.shortest,
    required this.samples,
    required this.days,
  });

  static const none =
      DoseSpacing(median: null, shortest: null, samples: 0, days: 0);
}

DoseSpacing computeDoseSpacing(List<Dosage> dosages, DateTimeRange range) {
  final byDay = <DateTime, List<DateTime>>{};
  for (final dose in dosages) {
    if (!inRangeInclusive(dose.timestamp, range.start, range.end)) continue;
    final local =
        dose.timestamp.isUtc ? dose.timestamp.toLocal() : dose.timestamp;
    (byDay[startOfDay(local)] ??= []).add(local);
  }

  // Each day contributes its own median, and the answer is the median of
  // those. Pooling every gap instead would let a six-dose day outvote a
  // two-dose day five to one, so the figure would drift toward whatever the
  // busiest days looked like rather than the typical day.
  final dailyMedians = <double>[];
  var shortest = double.infinity;
  var pairs = 0;
  for (final times in byDay.values) {
    if (times.length < 2) continue;
    times.sort();
    final gaps = <double>[];
    for (var i = 1; i < times.length; i++) {
      final seconds = times[i].difference(times[i - 1]).inSeconds.toDouble();
      gaps.add(seconds);
      if (seconds < shortest) shortest = seconds;
    }
    pairs += gaps.length;
    dailyMedians.add(_median(gaps));
  }
  if (dailyMedians.isEmpty) return DoseSpacing.none;

  return DoseSpacing(
    median: Duration(seconds: _median(dailyMedians).round()),
    shortest: Duration(seconds: shortest.round()),
    samples: pairs,
    days: dailyMedians.length,
  );
}

DateTime _nextDay(DateTime day) => addDays(day, 1);

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

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
