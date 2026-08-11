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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
          // Same external rhythm the dose rows use between cards.
          const SizedBox(height: 8),
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
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
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
          ),
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
    final dayLine =
        '${_formatAmount(dayTotal)}g · $count ${count == 1 ? 'dose' : 'doses'}';
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
        secondaryLine: '${_formatAmount(weekTotal)}g week ${_trendText(change)}',
      );
    }
    // Same two-line structure as today so the card does not restructure
    // when swiping between days — secondary stays quiet textTertiary empty.
    return _Secondary(primaryLine: dayLine, secondaryLine: ' ');
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
            fontSize: 28,
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
  const _Secondary({
    required this.primaryLine,
    required this.secondaryLine,
  });

  final String primaryLine;
  final String secondaryLine;

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
        const SizedBox(height: 3),
        // Always reserve the second line so today/past share the same height.
        Text(
          secondaryLine,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.c.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 24h timeline as the status card's base edge — no panel chrome. Ticks and
/// marks draw flush across the content width, ambient under the hero numbers.
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
      height: 36,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: CustomPaint(
          painter: TimelinePainter(
            dividerColor: context.c.hairline,
            dosages: timeline,
          ),
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
