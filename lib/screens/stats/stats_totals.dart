import 'package:flutter/material.dart';

import '../../domain/analytics_service.dart';
import '../../theme/app_theme.dart';
import 'stats_common.dart';

/// The plain readout: the numbers that need no interpretation, set as a dense
/// label/value list. Everything above this section on the page argues a case;
/// this one just answers "how much".
class TotalsSection extends StatelessWidget {
  const TotalsSection({
    super.key,
    required this.range,
    required this.active,
    required this.spacing,
    required this.weekday,
  });

  final IntakeFactors range;
  final IntakeFactors active;
  final DoseSpacing spacing;
  final WeekdayRhythm weekday;

  @override
  Widget build(BuildContext context) {
    final restDays = range.days - active.days;

    return Column(
      children: [
        FactRow(
          label: 'Total intake',
          value: '${formatGrams(range.grams)}g',
          caption: '${range.doses} doses over ${range.days} days',
        ),
        FactRow(
          label: 'Per active day',
          value: '${formatAmount(active.gramsPerDay)}g',
          caption: active.days == range.days
              ? 'no rest days in range'
              : '${active.days} active, $restDays rest',
        ),
        FactRow(
          label: 'Doses per active day',
          value: formatAmount(active.dosesPerDay),
          caption: '${formatAmount(active.gramsPerDose)}g each',
        ),
        if (spacing.median != null)
          FactRow(
            label: 'Typical gap',
            value: formatGap(spacing.median!),
            // Named precisely: the overnight break is excluded, or this would
            // just be 24h divided by the dose count wearing a disguise.
            caption: 'between doses on the same day',
          ),
        if (weekday.busiest != null)
          FactRow(
            label: 'Heaviest day',
            value: _weekdayName(weekday.busiest!),
            caption: '${formatAmount(weekday.gramsByWeekday[weekday.busiest!])}'
                'g average, against '
                '${formatAmount(weekday.gramsByWeekday[weekday.quietest!])}g on '
                '${_weekdayName(weekday.quietest!)}',
          ),
      ],
    );
  }
}

/// Everything ever logged, so the range picker above cannot make it move.
class AllTimeSection extends StatelessWidget {
  const AllTimeSection({super.key, required this.totals});

  final GrandTotals totals;

  @override
  Widget build(BuildContext context) {
    if (totals.doses == 0) return const SizedBox.shrink();

    return Column(
      children: [
        FactRow(
          label: 'Logged',
          value: '${formatGrams(totals.grams)}g',
          caption: '${totals.doses} doses, ${totals.strainsUsed} strains',
        ),
        FactRow(
          label: 'Tracked',
          value: '${totals.daysTracked} days',
          caption: totals.firstDose == null
              ? null
              : 'since ${_dateLabel(totals.firstDose!)}',
        ),
        FactRow(
          label: 'Active days',
          value: '${totals.activeDays}',
          caption: '${totals.daysTracked - totals.activeDays} rest days',
        ),
        FactRow(
          label: 'Lifetime average',
          value: '${formatAmount(totals.gramsPerActiveDay)}g',
          caption: 'per active day, '
              '${formatAmount(totals.dosesPerActiveDay)} doses',
        ),
      ],
    );
  }
}

/// One label/value pair. The value is tabular so a column of them lines up.
class FactRow extends StatelessWidget {
  const FactRow({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grams with a thousands separator — at eighteen months the lifetime total
/// runs to five figures and reads as noise without one.
String formatGrams(double value) {
  final text = formatAmount(value);
  final dot = text.indexOf('.');
  final whole = dot == -1 ? text : text.substring(0, dot);
  final rest = dot == -1 ? '' : text.substring(dot);

  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '$buffer$rest';
}

String formatGap(Duration gap) {
  final hours = gap.inHours;
  final minutes = gap.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _weekdayName(int index) => _weekdays[index];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dateLabel(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';
