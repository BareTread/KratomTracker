import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import 'home_calendar_section.dart';

/// Week strip plus one quiet status line. The vine timeline carries the
/// day's story; this line is insurance so "how long since last" is never
/// below the fold.
class HomeDayCard extends StatelessWidget {
  const HomeDayCard({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.now,
  });

  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Ticking clock the elapsed label listens to. Null (tests, static
  /// embeds) keeps the label computed once at build, as before.
  final ValueListenable<DateTime>? now;

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

    // One content edge at 16 (this 12 + the 4 below): the week grid, the
    // chevron glyph, and the status text. Hairlines stay on the vine's 12
    // grid so they match the timeline width.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: HomeCalendarSection(
              key: const Key('home-day-card-surface'),
              focusedDay: focusedDay,
              onDaySelected: onDaySelected,
              totalForDate: provider.totalForDate,
            ),
          ),
          const _StatusRule(),
          _QuietStatusLine(
            key: const Key('home-status-card-surface'),
            day: day,
            isToday: isToday,
            dayDoses: dayDoses,
            allDoses: provider.dosages,
            now: now,
          ),
        ],
      ),
    );
  }
}

/// The day's headline. A quiet label says what the figure is; the figure
/// itself is the one thing set large, in the display face.
/// today → `3h 16m` over Since last dose, with `49.4g · 3 doses` at the right
/// past  → `49.4g` over the date, with `3 doses` at the right
class _QuietStatusLine extends StatelessWidget {
  const _QuietStatusLine({
    super.key,
    required this.day,
    required this.isToday,
    required this.dayDoses,
    required this.allDoses,
    this.now,
  });

  final DateTime day;
  final bool isToday;
  final List<Dosage> dayDoses;
  final List<Dosage> allDoses;

  /// Ticking clock so the elapsed figure advances without a dose change.
  final ValueListenable<DateTime>? now;

  @override
  Widget build(BuildContext context) {
    final total = dayDoses.fold<double>(0, (sum, dose) => sum + dose.amount);
    final count = dayDoses.length;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // Same left edge as the week strip (16), not the rule's (12).
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: isToday
                ? _today(context, total, count)
                : _past(context, total, count),
          ),
          const _StatusRule(),
        ],
      ),
    );
  }

  // ── Today ───────────────────────────────────────────────────────────────

  Widget _today(BuildContext context, double total, int count) {
    if (allDoses.isEmpty) {
      return _row(
        context,
        eyebrow: 'Today',
        figure: Text(
          'No doses yet',
          style: AppType.display(size: 26, color: context.c.textSecondary),
        ),
      );
    }
    final last = allDoses.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
    Widget figure(DateTime tick) => _figured(
          _elapsedText(tick.difference(last.timestamp)),
          _figureStyle(context.c.textPrimary, 30),
        );
    return _row(
      context,
      eyebrow: 'Since last dose',
      // Only this Text rebuilds on a tick — never the calendar above.
      figure: now == null
          ? figure(DateTime.now())
          : ValueListenableBuilder<DateTime>(
              valueListenable: now!,
              builder: (context, tick, _) => figure(tick),
            ),
      trailing: dayDoses.isEmpty
          ? null
          : _Tally(
              amount: '${_formatAmount(total)}g',
              count: count,
            ),
    );
  }

  // ── Past day ────────────────────────────────────────────────────────────

  Widget _past(BuildContext context, double total, int count) {
    final eyebrow = DateFormat('EEEE d MMMM').format(day);
    if (dayDoses.isEmpty) {
      return _row(
        context,
        eyebrow: eyebrow,
        figure: Text(
          'No doses this day',
          style: AppType.display(size: 26, color: context.c.textSecondary),
        ),
      );
    }
    // A finished day's headline is what it added up to. It counts up from the
    // day it replaces, so paging reads as one number changing, not two
    // screens swapping.
    final duration =
        AppMotion.reduced(context) ? Duration.zero : AppMotion.slow;
    return _row(
      context,
      eyebrow: eyebrow,
      figure: TweenAnimationBuilder<double>(
        tween: Tween(end: total),
        duration: duration,
        curve: AppMotion.emphasized,
        builder: (context, value, _) => _figured(
          '${_formatAmount(value)}g',
          _figureStyle(context.c.textPrimary, 30),
        ),
      ),
      trailing: Text(
        '$count ${count == 1 ? 'dose' : 'doses'}',
        style: TextStyle(
          fontFamily: AppType.sans,
          color: context.c.textTertiary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String eyebrow,
    required Widget figure,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.2,
                  color: context.c.textTertiary,
                ),
              ),
              const SizedBox(height: 5),
              figure,
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Padding(
            // Sits on the figure's baseline rather than the box bottom.
            padding: const EdgeInsets.only(bottom: 3),
            child: trailing,
          ),
        ],
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
    // Under a minute (or a future-dated dose) is "0m": the figure stays a
    // duration like every other state, and the word "now" is left to the
    // NOW tip on the vine. '<1m' set in the serif read as "<lm".
    return elapsed.inMinutes < 1 ? '0m' : '${elapsed.inMinutes}m';
  }

  String _formatAmount(double value) {
    // Same precision as the dose rows below, so one 2.25 g dose never reads
    // "2.3g" in the summary and "2.25g" on its row.
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

/// Today's running total, right-aligned beside the elapsed figure.
class _Tally extends StatelessWidget {
  const _Tally({required this.amount, required this.count});

  final String amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _figured(
          amount,
          _figureStyle(context.c.textSecondary, 20),
        ),
        const SizedBox(height: 3),
        Text(
          '$count ${count == 1 ? 'dose' : 'doses'}',
          style: TextStyle(
            fontFamily: AppType.sans,
            color: context.c.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Full-width 1px hairline. Same rule under the week strip and the status line.
class _StatusRule extends StatelessWidget {
  const _StatusRule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: ColoredBox(color: context.c.hairline),
    );
  }
}

TextStyle _figureStyle(Color color, double size) => AppType.display(
      size: size,
      color: color,
      height: 1.0,
      letterSpacing: -0.2,
    ).copyWith(
      fontFeatures: const [
        FontFeature.liningFigures(),
        FontFeature.tabularFigures(),
      ],
    );

/// Serif figure. Unit letters (g, h, m, d) sit at 70% on the same baseline.
/// No characters are inserted, so plain text is unchanged.
Text _figured(String text, TextStyle style) {
  final unit = style.copyWith(fontSize: (style.fontSize ?? 0) * 0.7);
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        for (final match in RegExp(r'[ghmd]|[^ghmd]+').allMatches(text))
          TextSpan(
            text: match[0],
            style: _isUnitLetter(match[0]!) ? unit : null,
          ),
      ],
    ),
  );
}

bool _isUnitLetter(String part) => part.length == 1 && 'ghmd'.contains(part);
