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

/// One card consolidating the calendar week strip, the time-since-last-dose
/// hero, today's totals, the weekly trend, and the 24h timeline as its bottom
/// edge. Replaces the former four stacked cards.
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

    return Container(
      key: const Key('home-day-card-surface'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: context.c.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.c.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeCalendarSection(
            focusedDay: focusedDay,
            onDaySelected: onDaySelected,
            totalForDate: provider.totalForDate,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: context.c.hairline),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _SummaryBlock(
              isToday: isToday,
              day: day,
              dayDoses: dayDoses,
              allDoses: provider.dosages,
              strainsById: strainsById,
              provider: provider,
            ),
          ),
          _TimelineEdge(dosages: dayDoses, strainsById: strainsById),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.isToday,
    required this.day,
    required this.dayDoses,
    required this.allDoses,
    required this.strainsById,
    required this.provider,
  });

  final bool isToday;
  final DateTime day;
  final List<Dosage> dayDoses;
  final List<Dosage> allDoses;
  final Map<String, Strain> strainsById;
  final KratomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _hero(context)),
        const SizedBox(width: 16),
        _secondary(context),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    if (isToday) {
      final last = allDoses.isEmpty
          ? null
          : allDoses.reduce(
              (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
            );
      if (last == null) {
        return _Hero(
          value: 'No doses yet',
          sub: 'Tap the button below to log one',
          valueColor: context.c.textPrimary,
        );
      }
      final elapsed = DateTime.now().difference(last.timestamp);
      final strain = provider.getStrain(last.strainId);
      final code = strain?.code ?? 'Unknown strain';
      return _Hero(
        value: _elapsedText(elapsed),
        sub: 'since $code · ${_formatAmount(last.amount)}g',
        valueColor: context.c.textPrimary,
      );
    }
    // Past day: show the span of that day's doses, first-to-last.
    if (dayDoses.isEmpty) {
      return _Hero(
        value: 'No doses',
        sub: 'nothing logged this day',
        valueColor: context.c.textPrimary,
      );
    }
    final first = dayDoses.first.timestamp;
    final last = dayDoses.last.timestamp;
    final span = last.difference(first);
    return _Hero(
      value: _spanText(span),
      sub: '${DateFormat.jm().format(first)} – ${DateFormat.jm().format(last)}',
      valueColor: context.c.textPrimary,
    );
  }

  Widget _secondary(BuildContext context) {
    final dayTotal =
        dayDoses.fold<double>(0, (sum, dose) => sum + dose.amount);
    final count = dayDoses.length;
    final dayLine = '${_formatAmount(dayTotal)}g · $count ${count == 1 ? 'dose' : 'doses'}';
    if (isToday) {
      final today = DateUtils.dateOnly(DateTime.now());
      final week = List.generate(
        7,
        (i) => provider.totalForDate(today.subtract(Duration(days: 6 - i))),
      );
      final previous = List.generate(
        7,
        (i) => provider.totalForDate(today.subtract(Duration(days: 13 - i))),
      );
      final weekTotal = week.fold<double>(0, (a, b) => a + b);
      final previousTotal = previous.fold<double>(0, (a, b) => a + b);
      final change = previousTotal == 0
          ? 0.0
          : (weekTotal - previousTotal) / previousTotal * 100;
      return _Secondary(
        primaryLine: dayLine,
        secondaryLine: '${_formatAmount(weekTotal)}g wk · ${_trendText(change)}',
        trendChange: change,
      );
    }
    return _Secondary(primaryLine: dayLine, secondaryLine: '');
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

  String _spanText(Duration span) {
    if (span.inHours > 0) {
      return '${span.inHours}h ${span.inMinutes % 60}m span';
    }
    return '${span.inMinutes}m span';
  }

  String _trendText(double change) {
    final abs = change.abs().toStringAsFixed(0);
    if (change > 10) return '↑ $abs%';
    if (change < -10) return '↓ $abs%';
    return '→ $abs%';
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.value,
    required this.sub,
    required this.valueColor,
  });

  final String value;
  final String sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -0.5,
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              color: context.c.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({required this.primaryLine, required this.secondaryLine, this.trendChange});

  final String primaryLine;
  final String secondaryLine;
  final double? trendChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primaryLine,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.c.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (secondaryLine.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            secondaryLine,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: _trendColor(context, trendChange),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Color _trendColor(BuildContext context, double? change) {
    if (change == null) return context.c.textTertiary;
    if (change > 10) return context.c.caution;
    if (change < -10) return context.c.positive;
    return context.c.textTertiary;
  }
}

/// The 24h timeline as the card's bottom edge — no title, no gram badge. The
/// total now lives in the secondary column; this strip is ambient texture.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
        height: 46,
        child: CustomPaint(
          size: const Size(double.infinity, 46),
          painter: TimelinePainter(
            backgroundColor: context.c.surfaceSunken,
            bandColor: context.c.surfaceRaised,
            dividerColor: context.c.hairline,
            labelColor: context.c.textTertiary,
            dosages: timeline,
          ),
        ),
      ),
    );
  }

  Map<String, double> _calculateHeights(List<Dosage> values) {
    if (values.isEmpty) return const {};
    if (values.length == 1) return {values.single.id: 24};
    final maximum = values.map((d) => d.amount).reduce(max);
    final minimum = values.map((d) => d.amount).reduce(min);
    final range = maximum - minimum;
    final ratio = maximum / minimum;
    return {
      for (final dose in values)
        dose.id: range == 0
            ? 22
            : 12 +
                20 *
                    (ratio > 5
                        ? log(dose.amount / minimum) / log(ratio)
                        : (dose.amount - minimum) / range),
    };
  }
}
