import 'package:flutter/material.dart';

/// Calendar-day arithmetic. Every helper here works in **local calendar
/// days**, never in elapsed hours: `Duration(days: 1)` is exactly 24h, which
/// is wrong on the two days a year a DST zone runs 23h or 25h. In
/// Europe/London that made the Mar 29 day-range reach into Mar 30 and the
/// Oct 25 range drop its last hour — and, because the analytics day map is
/// seeded with calendar days, a dose in that sliver hit an unseeded key and
/// crashed the stats screen.
///
/// Timestamps are also normalised to local time first: a UTC `DateTime`
/// read straight for its `.year/.month/.day` yields the UTC calendar day,
/// which is the wrong day for anything logged near midnight.
DateTime startOfDay(DateTime d) {
  final local = d.isUtc ? d.toLocal() : d;
  return DateTime(local.year, local.month, local.day);
}

/// The local midnight [n] calendar days after [d] ([n] may be negative).
DateTime addDays(DateTime d, int n) {
  final local = d.isUtc ? d.toLocal() : d;
  return DateTime(local.year, local.month, local.day + n);
}

/// Whole calendar days from [a] to [b]. Computed in UTC, which has no DST,
/// so the count is exact across a transition.
int daysBetween(DateTime a, DateTime b) {
  final from = startOfDay(a);
  final to = startOfDay(b);
  return DateTime.utc(to.year, to.month, to.day)
      .difference(DateTime.utc(from.year, from.month, from.day))
      .inDays;
}

bool inRangeInclusive(DateTime t, DateTime start, DateTime end) {
  final local = t.isUtc ? t.toLocal() : t;
  final lower = startOfDay(start);
  final upper = addDays(end, 1);
  return !local.isBefore(lower) && local.isBefore(upper);
}

DateTimeRange lastNDays(int n, {DateTime? now}) {
  if (n <= 0) throw ArgumentError.value(n, 'n', 'must be greater than zero');
  final end = startOfDay(now ?? DateTime.now());
  return DateTimeRange(start: addDays(end, -(n - 1)), end: end);
}
