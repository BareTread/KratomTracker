import 'dart:math' as math;

import '../models/dosage.dart';
import 'date_utils.dart';

/// The insight tier: things eighteen months of timestamps can say that a total
/// cannot. Every function here returns null rather than a weak answer — an
/// insight that fires on six observations is worse than no insight, because it
/// will contradict itself next week and stop being believed.
///
/// Common rules, applied throughout:
///
///  * Today is excluded from every rate and comparison. A morning with one
///    dose logged is not a light day, it is an unfinished one, and letting it
///    in means the page answers a different question before and after dinner.
///  * Timestamps are localised before anything reads a date, hour or weekday —
///    imported backups carry UTC — but elapsed time is measured on the raw
///    instants, which is what makes it DST-safe.
///  * Doses are sorted once, up front. A backdated import leaves the stored
///    list out of order, and every adjacency here would be wrong without it.

/// Local dose times grouped by completed local day, ascending within each day.
Map<DateTime, List<DateTime>> _completedDays(
  List<Dosage> dosages,
  DateTime now,
) {
  final today = startOfDay(now);
  final byDay = <DateTime, List<DateTime>>{};
  for (final dose in dosages) {
    final local =
        dose.timestamp.isUtc ? dose.timestamp.toLocal() : dose.timestamp;
    final day = startOfDay(local);
    if (!day.isBefore(today)) continue;
    (byDay[day] ??= []).add(local);
  }
  for (final times in byDay.values) {
    times.sort();
  }
  return byDay;
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

// ---------------------------------------------------------------------------
// 1. Gap compression
// ---------------------------------------------------------------------------

/// The typical within-day gap now against the month before it.
///
/// This is the third way intake can climb, and the only one `G = F × A` cannot
/// see: same dose count, same dose size, but packed into a shorter stretch of
/// the day. Arguably it moves first.
class GapCompression {
  final Duration recent;
  final Duration previous;

  /// Negative when the gap is shrinking — doses moving closer together.
  final Duration delta;
  final int recentDays;
  final int previousDays;

  const GapCompression({
    required this.recent,
    required this.previous,
    required this.delta,
    required this.recentDays,
    required this.previousDays,
  });

  /// A schedule shift, not a wobble: at least half an hour and at least a
  /// tenth of the previous gap. Below both, the honest reading is "unchanged".
  bool get isMaterial {
    if (previous.inSeconds == 0) return false;
    final minutes = delta.inMinutes.abs();
    final fraction = delta.inSeconds.abs() / previous.inSeconds;
    return minutes >= 30 && fraction >= 0.10;
  }

  bool get isCompressing => delta.isNegative;
}

/// Minimum days carrying a same-day gap before a window can be compared.
const int _minGapDays = 15;

GapCompression? computeGapCompression(List<Dosage> dosages, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final byDay = _completedDays(dosages, effectiveNow);
  if (byDay.isEmpty) return null;

  final today = startOfDay(effectiveNow);
  final recentStart = addDays(today, -30);
  final previousStart = addDays(today, -60);

  final recent = <double>[];
  final previous = <double>[];
  for (final entry in byDay.entries) {
    final times = entry.value;
    if (times.length < 2) continue;
    final gaps = [
      for (var i = 1; i < times.length; i++)
        times[i].difference(times[i - 1]).inSeconds.toDouble(),
    ];
    // One median per day, so a six-dose day does not outvote a two-dose day.
    final daily = _median(gaps);
    if (!entry.key.isBefore(recentStart)) {
      recent.add(daily);
    } else if (!entry.key.isBefore(previousStart)) {
      previous.add(daily);
    }
  }

  if (recent.length < _minGapDays || previous.length < _minGapDays) return null;

  final recentMedian = Duration(seconds: _median(recent).round());
  final previousMedian = Duration(seconds: _median(previous).round());
  return GapCompression(
    recent: recentMedian,
    previous: previousMedian,
    delta: recentMedian - previousMedian,
    recentDays: recent.length,
    previousDays: previous.length,
  );
}

// ---------------------------------------------------------------------------
// 2. Strain return cycle
// ---------------------------------------------------------------------------

/// How long a strain typically rests before it comes back round.
///
/// This is the honest reading of "average time between strains". Consecutive
/// doses of the same strain collapse into one episode, and a return interval
/// runs from the end of one episode to the start of that strain's next —
/// which by construction has something else in between. The median is taken
/// across return events, so it describes the rotation actually in use rather
/// than giving a strain retired eight months ago an equal vote.
class ReturnCycle {
  final Duration median;
  final Duration? previousMedian;

  /// Positive when the cycle is lengthening — strains resting longer.
  final Duration? delta;
  final int events;
  final int strains;

  const ReturnCycle({
    required this.median,
    required this.previousMedian,
    required this.delta,
    required this.events,
    required this.strains,
  });

  bool get isMaterial {
    final change = delta;
    if (change == null || previousMedian == null) return false;
    final fraction = change.inSeconds.abs() / previousMedian!.inSeconds;
    return change.inHours.abs() >= 12 && fraction >= 0.15;
  }
}

const int _minReturnEvents = 20;
const int _minReturnStrains = 5;

ReturnCycle? computeReturnCycle(List<Dosage> dosages, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final today = startOfDay(effectiveNow);

  final sorted = [
    for (final dose in dosages)
      (
        strainId: dose.strainId,
        at: dose.timestamp.isUtc ? dose.timestamp.toLocal() : dose.timestamp,
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
  final completed = [
    for (final dose in sorted)
      if (startOfDay(dose.at).isBefore(today)) dose,
  ];
  if (completed.length < 2) return null;

  // Collapse runs of the same strain into episodes.
  final episodes = <({String strainId, DateTime start, DateTime end})>[];
  var runStrain = completed.first.strainId;
  var runStart = completed.first.at;
  var runEnd = completed.first.at;
  for (var i = 1; i < completed.length; i++) {
    final dose = completed[i];
    if (dose.strainId == runStrain) {
      runEnd = dose.at;
      continue;
    }
    episodes.add((strainId: runStrain, start: runStart, end: runEnd));
    runStrain = dose.strainId;
    runStart = dose.at;
    runEnd = dose.at;
  }
  episodes.add((strainId: runStrain, start: runStart, end: runEnd));

  // Per strain, the rest between one episode ending and the next beginning.
  final lastEnd = <String, DateTime>{};
  final recent = <double>[];
  final previous = <double>[];
  final recentStrains = <String>{};
  final recentStart = addDays(today, -90);
  final previousStart = addDays(today, -180);

  for (final episode in episodes) {
    final prior = lastEnd[episode.strainId];
    if (prior != null) {
      final rest = episode.start.difference(prior).inSeconds.toDouble();
      final returnedOn = startOfDay(episode.start);
      if (!returnedOn.isBefore(recentStart)) {
        recent.add(rest);
        recentStrains.add(episode.strainId);
      } else if (!returnedOn.isBefore(previousStart)) {
        previous.add(rest);
      }
    }
    lastEnd[episode.strainId] = episode.end;
  }

  if (recent.length < _minReturnEvents ||
      recentStrains.length < _minReturnStrains) {
    return null;
  }

  final median = Duration(seconds: _median(recent).round());
  final hasPrevious = previous.length >= _minReturnEvents;
  final previousMedian =
      hasPrevious ? Duration(seconds: _median(previous).round()) : null;

  return ReturnCycle(
    median: median,
    previousMedian: previousMedian,
    delta: previousMedian == null ? null : median - previousMedian,
    events: recent.length,
    strains: recentStrains.length,
  );
}

// ---------------------------------------------------------------------------
// 3. Effective rotation size
// ---------------------------------------------------------------------------

/// How many strains the month's grams were *functionally* spread across.
///
/// `1 / Σ(share²)` — the number of equal-share strains that would produce the
/// same concentration. Thirty strains where three carry most of the grams is a
/// three-strain rotation wearing a thirty-strain shelf, and this is the one
/// number that says so. Unlike "top strain is 24%", every strain moves it,
/// including the long tail.
class RotationBreadth {
  final int observed;
  final double effective;
  final int doses;
  final int activeDays;

  const RotationBreadth({
    required this.observed,
    required this.effective,
    required this.doses,
    required this.activeDays,
  });

  /// Worth saying only when the shelf is materially wider than the rotation.
  bool get isNarrow => observed >= 4 && effective <= observed * 0.6;
}

RotationBreadth? computeRotationBreadth(List<Dosage> dosages, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final today = startOfDay(effectiveNow);
  final start = addDays(today, -30);

  final grams = <String, double>{};
  final days = <DateTime>{};
  var doses = 0;
  var total = 0.0;
  for (final dose in dosages) {
    final local =
        dose.timestamp.isUtc ? dose.timestamp.toLocal() : dose.timestamp;
    final day = startOfDay(local);
    if (day.isBefore(start) || !day.isBefore(today)) continue;
    if (dose.amount <= 0) continue;
    grams[dose.strainId] = (grams[dose.strainId] ?? 0) + dose.amount;
    days.add(day);
    doses++;
    total += dose.amount;
  }

  if (doses < 30 || days.length < 5 || grams.length < 2 || total <= 0) {
    return null;
  }

  var sumOfSquares = 0.0;
  for (final value in grams.values) {
    final share = value / total;
    sumOfSquares += share * share;
  }

  return RotationBreadth(
    observed: grams.length,
    effective: 1 / sumOfSquares,
    doses: doses,
    activeDays: days.length,
  );
}

// ---------------------------------------------------------------------------
// 4. First-dose timing drift
// ---------------------------------------------------------------------------

/// When the day starts, and whether that is moving.
///
/// Compared on a 24-hour circle, so 11:55pm and 12:05am are ten minutes apart
/// rather than nearly a day. Only the first dose of each day counts, which
/// stops a heavy day from pulling extra weight.
class FirstDoseDrift {
  /// Minutes from local midnight.
  final int recentMinute;
  final int previousMinute;

  /// Negative when the day is starting earlier.
  final int deltaMinutes;
  final int recentDays;
  final int previousDays;

  const FirstDoseDrift({
    required this.recentMinute,
    required this.previousMinute,
    required this.deltaMinutes,
    required this.recentDays,
    required this.previousDays,
  });

  bool get isMaterial => deltaMinutes.abs() >= 30;
  bool get isEarlier => deltaMinutes < 0;
}

const int _minFirstDoseDays = 15;

FirstDoseDrift? computeFirstDoseDrift(List<Dosage> dosages, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final byDay = _completedDays(dosages, effectiveNow);
  if (byDay.isEmpty) return null;

  final today = startOfDay(effectiveNow);
  final recentStart = addDays(today, -30);
  final previousStart = addDays(today, -60);

  final recent = <double>[];
  final previous = <double>[];
  for (final entry in byDay.entries) {
    final first = entry.value.first;
    final minute = (first.hour * 60 + first.minute).toDouble();
    if (!entry.key.isBefore(recentStart)) {
      recent.add(minute);
    } else if (!entry.key.isBefore(previousStart)) {
      previous.add(minute);
    }
  }

  if (recent.length < _minFirstDoseDays ||
      previous.length < _minFirstDoseDays) {
    return null;
  }

  // Anchor both windows to one direction on the circle, unwrap every point to
  // within twelve hours of it, then take ordinary medians. Without this a
  // window straddling midnight medians to lunchtime.
  final anchor = _circularAnchor([...recent, ...previous]);
  final recentMedian = _median([for (final m in recent) _unwrap(m, anchor)]);
  final previousMedian =
      _median([for (final m in previous) _unwrap(m, anchor)]);

  return FirstDoseDrift(
    recentMinute: _wrapToDay(recentMedian).round(),
    previousMinute: _wrapToDay(previousMedian).round(),
    deltaMinutes: (recentMedian - previousMedian).round(),
    recentDays: recent.length,
    previousDays: previous.length,
  );
}

const double _minutesInDay = 1440;

/// Mean direction of a set of minute-of-day values, as a minute-of-day.
double _circularAnchor(List<double> minutes) {
  var x = 0.0;
  var y = 0.0;
  for (final minute in minutes) {
    final angle = 2 * math.pi * minute / _minutesInDay;
    x += math.cos(angle);
    y += math.sin(angle);
  }
  if (x == 0 && y == 0) return 0;
  final angle = math.atan2(y, x);
  return _wrapToDay(angle / (2 * math.pi) * _minutesInDay);
}

/// [minute] shifted by whole days until it sits within ±12h of [anchor].
double _unwrap(double minute, double anchor) {
  var value = minute;
  while (value - anchor > _minutesInDay / 2) {
    value -= _minutesInDay;
  }
  while (anchor - value > _minutesInDay / 2) {
    value += _minutesInDay;
  }
  return value;
}

double _wrapToDay(double minute) {
  var value = minute % _minutesInDay;
  if (value < 0) value += _minutesInDay;
  return value;
}
