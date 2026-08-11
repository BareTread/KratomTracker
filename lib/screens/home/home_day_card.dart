import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../models/strain.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/timeline_painter.dart';
import 'home_calendar_section.dart';

/// Two peer cards: the calendar (navigation) and the day status (summary +
/// ambient timeline). Split deliberately so each job keeps its own weight and
/// the home top no longer reads as one tall slab.
class HomeDayCard extends StatelessWidget {
  const HomeDayCard({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    context.select<KratomProvider, int>(
      (p) => Object.hashAll(p.dosages),
    );
    context.select<KratomProvider, int>(
      (p) => Object.hashAll(p.strains),
    );
    final provider = context.read<KratomProvider>();
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(focusedDay);
    final isToday = day == today;
    final dayDoses = provider.getDosagesForDate(day);
    final strainsById = <String, Strain>{
      for (final s in provider.strains) s.id: s,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('home-day-card-surface'),
            decoration: BoxDecoration(
              color: context.c.surfaceRaised,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.c.hairline),
            ),
            child: HomeCalendarSection(
              focusedDay: focusedDay,
              onDaySelected: onDaySelected,
              totalForDate: provider.totalForDate,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            key: const Key('home-status-card-surface'),
            decoration: BoxDecoration(
              color: context.c.surfaceRaised,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.c.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: _SummaryBlock(
                    isToday: isToday,
                    dayDoses: dayDoses,
                    allDoses: provider.dosages,
                    provider: provider,
                  ),
                ),
                _TimelineEdge(dosages: dayDoses, strainsById: strainsById),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.isToday,
    required this.dayDoses,
    required this.allDoses,
    required this.provider,
  });

  final bool isToday;
  final List<Dosage> dayDoses;
  final List<Dosage> allDoses;
  final KratomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _hero(context)),
        if (isToday && dayDoses.isNotEmpty) ...[
          const SizedBox(width: 16),
          _todayTotals(context),
        ],
      ],
    );
  }

  /// The number this app is opened for: how long since the last dose. The
  /// strain that produced it sits underneath, named in its own colour.
  Widget _hero(BuildContext context) {
    if (isToday) {
      final last = allDoses.isEmpty
          ? null
          : allDoses.reduce(
              (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
            );
      if (last == null) {
        return const _Hero(
          value: 'No doses yet',
          sub: [TextSpan(text: 'Tap + below to log one')],
        );
      }
      final elapsed = DateTime.now().difference(last.timestamp);
      final strain = provider.getStrain(last.strainId);
      final code = strain?.code ?? 'Unknown strain';
      final codeColor = strain == null
          ? context.c.textTertiary
          : legibleStrainColor(
              Color(strain.color),
              Theme.of(context).brightness,
            );
      return _Hero(
        value: _elapsedText(elapsed),
        sub: [
          TextSpan(
            text: 'since ',
            style: TextStyle(color: context.c.textTertiary),
          ),
          TextSpan(
            text: code,
            style: TextStyle(color: codeColor, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' · ${_formatAmount(last.amount)}g',
            style: TextStyle(color: context.c.textTertiary),
          ),
        ],
      );
    }
    // Past day: the day's total is the fact that matters; the first-to-last
    // window stays as quiet context on the sub-line.
    if (dayDoses.isEmpty) {
      return const _Hero(
        value: 'No doses',
        sub: [TextSpan(text: 'nothing logged this day')],
      );
    }
    final total = dayDoses.fold<double>(0, (sum, dose) => sum + dose.amount);
    final count = dayDoses.length;
    final window =
        '${DateFormat.jm().format(dayDoses.first.timestamp)} – ${DateFormat.jm().format(dayDoses.last.timestamp)}';
    return _Hero(
      value: '${_formatAmount(total)}g',
      sub: [
        TextSpan(text: '$count ${count == 1 ? 'dose' : 'doses'} · $window'),
      ],
    );
  }

  /// Today's running total, kept secondary to the elapsed hero.
  Widget _todayTotals(BuildContext context) {
    final total = dayDoses.fold<double>(0, (sum, dose) => sum + dose.amount);
    final count = dayDoses.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatAmount(total)}g',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.c.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$count ${count == 1 ? 'dose' : 'doses'}',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.c.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _elapsedText(Duration elapsed) {
    if (elapsed.inDays > 0) {
      return '${elapsed.inDays}d ${elapsed.inHours % 24}h';
    }
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
    }
    return elapsed.inMinutes < 1 ? 'now' : '${elapsed.inMinutes}m';
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.value, required this.sub});

  final String value;
  final List<InlineSpan> sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.c.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: sub),
          style: TextStyle(
            color: context.c.textTertiary,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

/// 24h timeline as the status card's base edge — full card width, flush with
/// the card's bottom, no panel chrome. Pure texture under the hero numbers.
class _TimelineEdge extends StatelessWidget {
  const _TimelineEdge({required this.dosages, required this.strainsById});

  final List<Dosage> dosages;
  final Map<String, Strain> strainsById;

  @override
  Widget build(BuildContext context) {
    final heights = _calculateHeights(dosages);
    final timeline = [
      for (final dose in dosages)
        (
          timestamp: dose.timestamp,
          amount: dose.amount,
          color: strainsById[dose.strainId] == null
              ? context.c.textTertiary
              : Color(strainsById[dose.strainId]!.color),
          height: heights[dose.id] ?? 0,
        ),
    ];
    return SizedBox(
      height: 30,
      width: double.infinity,
      child: CustomPaint(
        painter: TimelinePainter(
          dividerColor: context.c.hairline,
          dosages: timeline,
        ),
      ),
    );
  }

  Map<String, double> _calculateHeights(List<Dosage> values) {
    if (values.isEmpty) return const {};
    if (values.length == 1) return {values.single.id: 22};
    final maximum = values.map((d) => d.amount).reduce(max);
    final minimum = values.map((d) => d.amount).reduce(min);
    final range = maximum - minimum;
    final ratio = maximum / minimum;
    return {
      for (final dose in values)
        dose.id: range == 0
            ? 20
            : 10 +
                18 *
                    (ratio > 5
                        ? log(dose.amount / minimum) / log(ratio)
                        : (dose.amount - minimum) / range),
    };
  }
}
