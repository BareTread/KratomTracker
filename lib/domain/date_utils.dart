import 'package:flutter/material.dart';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

bool inRangeInclusive(DateTime t, DateTime start, DateTime end) {
  final lower = startOfDay(start);
  final upper = startOfDay(end).add(const Duration(days: 1));
  return !t.isBefore(lower) && t.isBefore(upper);
}

DateTimeRange lastNDays(int n, {DateTime? now}) {
  if (n <= 0) throw ArgumentError.value(n, 'n', 'must be greater than zero');
  final end = startOfDay(now ?? DateTime.now());
  return DateTimeRange(
    start: end.subtract(Duration(days: n - 1)),
    end: end,
  );
}
