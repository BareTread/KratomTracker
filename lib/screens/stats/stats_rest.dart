import 'package:flutter/material.dart';

import '../../domain/analytics_service.dart';
import 'stats_common.dart';

/// Rest days and streaks in one line. Three numbers he already knows how to
/// read do not need three boxes to sit in.
class RestLine extends StatelessWidget {
  const RestLine({super.key, required this.stats});

  final DoseStats stats;

  @override
  Widget build(BuildContext context) {
    return Text(restLine(stats), style: quietStyle(context));
  }
}

String restLine(DoseStats stats) {
  final total = stats.activeDays + stats.restDays;
  if (total == 0) return 'No days in this range yet.';

  final parts = <String>[
    stats.restDays == 0
        ? 'No rest days in $total'
        : '${stats.restDays} rest ${_days(stats.restDays)} in $total',
    if (stats.currentStreakDays > 0)
      'on a ${stats.currentStreakDays}-day run',
    if (stats.longestRestStreak > 0)
      'longest rest ${stats.longestRestStreak} ${_days(stats.longestRestStreak)}',
  ];
  return parts.join(' · ');
}

String _days(int n) => n == 1 ? 'day' : 'days';
