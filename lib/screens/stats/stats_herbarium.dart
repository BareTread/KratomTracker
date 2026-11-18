import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/date_utils.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/day_sprig.dart';
import 'stats_bundle.dart';

/// The range as a page of pressed sprigs, one per closed day, seven to a row
/// (Monday first, like the Home week strip). Every leaf is a dose at its time
/// of day; leaf length is grams on one scale for the whole page, so a heavy
/// day is visibly heavier and a rest day is a bare stem with a bud.
class StatsHerbarium extends StatelessWidget {
  const StatsHerbarium({super.key, required this.bundle});

  final StatsBundle bundle;

  static const double sprigHeight = 76;
  static const double sprigWidth = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = bundle.days;
    if (days.isEmpty) return const SizedBox.shrink();

    final byDay = <DateTime, List<SprigDose>>{
      for (final day in days) day: <SprigDose>[],
    };
    final first = days.first;
    final last = days.last;
    for (final dose in context.watch<KratomProvider>().dosages) {
      final day = startOfDay(dose.timestamp);
      if (day.isBefore(first) || day.isAfter(last)) continue;
      final strain = bundle.strainsById[dose.strainId];
      byDay[day]?.add(
        SprigDose.fromDosage(
          dose,
          strain == null ? c.textTertiary : Color(strain.color),
        ),
      );
    }
    final scale = sprigScaleFor(byDay.values);

    // The exception worth naming: the heaviest day gets its total under it.
    DateTime? heaviest;
    var heaviestGrams = 0.0;
    for (var i = 0; i < days.length; i++) {
      if (bundle.dailyGrams[i] > heaviestGrams) {
        heaviestGrams = bundle.dailyGrams[i];
        heaviest = days[i];
      }
    }

    final today = startOfDay(DateTime.now());
    final leading = first.weekday - 1;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateFormat.E().format(DateTime(2024, 1, 1 + i)).substring(0, 1),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final label in weekdays)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppType.eyebrow(c.textTertiary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in cells.skip(row * 7).take(7))
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: sprigHeight + 16)
                        : _SprigCell(
                            day: day,
                            doses: byDay[day]!,
                            scale: scale,
                            isToday: day == today,
                            heaviestGrams:
                                day == heaviest ? heaviestGrams : null,
                          ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'A sprig a day, morning at the top. Leaf length is grams; '
          'the longest leaf is ${_grams(scale)} g.',
          style: TextStyle(
            fontFamily: AppType.sans,
            fontSize: 12,
            height: 1.35,
            color: c.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _SprigCell extends StatelessWidget {
  const _SprigCell({
    required this.day,
    required this.doses,
    required this.scale,
    required this.isToday,
    this.heaviestGrams,
  });

  final DateTime day;
  final List<SprigDose> doses;
  final double scale;

  /// Today is still growing: an empty today is not a rest day (no bud), and
  /// its date takes the accent the Home week strip uses for today.
  final bool isToday;
  final double? heaviestGrams;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final heaviest = heaviestGrams != null;
    final date = day.day == 1 ? DateFormat('d MMM').format(day) : '${day.day}';
    return Semantics(
      label: daySprigLabel(day, doses),
      excludeSemantics: true,
      child: Column(
        children: [
          DaySprig(
            key: ValueKey('stats-sprig-${day.year}-${day.month}-${day.day}'),
            doses: doses,
            scaleGrams: scale,
            rest: !isToday,
            size: const Size(
              StatsHerbarium.sprigWidth,
              StatsHerbarium.sprigHeight,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                heaviest ? '$date · ${_grams(heaviestGrams!)}g' : date,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight:
                      heaviest || isToday ? FontWeight.w600 : FontWeight.w500,
                  color: isToday
                      ? c.accent
                      : heaviest
                          ? c.textPrimary
                          : c.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _grams(double value) {
  final rounded = value.roundToDouble();
  return (value - rounded).abs() < 0.05
      ? rounded.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
