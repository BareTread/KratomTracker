import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import 'home_calendar_section.dart';

/// Calendar card plus one quiet status line. The vine timeline carries the
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

    // Two left edges only: the card at 16, and the status line + its rule at
    // 12 — the vine's own grid (see _HomeDayPage's horizontal padding). The
    // rule then caps the timeline at exactly the timeline's width instead of
    // stopping short of it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
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
          ),
          const SizedBox(height: 10),
          _QuietStatusLine(
            key: const Key('home-status-card-surface'),
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

/// One greyscale line — the single summary for the day:
/// today → `3h 16m since last dose · 49.4g · 3 doses`
/// past  → `49.4g · 3 doses`
/// The elapsed figure is the only weight.
class _QuietStatusLine extends StatelessWidget {
  const _QuietStatusLine({
    super.key,
    required this.isToday,
    required this.dayDoses,
    required this.allDoses,
    this.now,
  });

  final bool isToday;
  final List<Dosage> dayDoses;
  final List<Dosage> allDoses;

  /// Ticking clock so the elapsed figure advances without a dose change.
  final ValueListenable<DateTime>? now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            // Only this Text rebuilds on a tick — never the calendar above.
            child: now == null
                ? _line(context, DateTime.now())
                : ValueListenableBuilder<DateTime>(
                    valueListenable: now!,
                    builder: (context, tick, _) => _line(context, tick),
                  ),
          ),
          const SizedBox(height: 8),
          // Soft hairline that fades at both ends — not a hard divider.
          const _StatusRule(),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, DateTime now) => Text.rich(
        TextSpan(children: _spans(context, now)),
        style: TextStyle(
          color: context.c.textTertiary,
          fontSize: 13,
          height: 1.3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  List<InlineSpan> _spans(BuildContext context, DateTime now) {
    if (isToday) {
      if (allDoses.isEmpty) {
        return const [TextSpan(text: 'No doses yet')];
      }
      final last = allDoses.reduce(
        (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
      );
      final elapsed = now.difference(last.timestamp);
      final total =
          dayDoses.fold<double>(0, (sum, dose) => sum + dose.amount);
      final count = dayDoses.length;
      return [
        TextSpan(
          text: _elapsedText(elapsed),
          style: TextStyle(
            color: context.c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const TextSpan(text: ' since last dose'),
        if (dayDoses.isNotEmpty)
          TextSpan(
            text:
                ' · ${_formatAmount(total)}g · $count ${count == 1 ? 'dose' : 'doses'}',
          ),
      ];
    }

    if (dayDoses.isEmpty) {
      return const [TextSpan(text: 'No doses this day')];
    }
    final total = dayDoses.fold<double>(0, (sum, dose) => sum + dose.amount);
    final count = dayDoses.length;
    return [
      TextSpan(
        text: '${_formatAmount(total)}g',
        style: TextStyle(
          color: context.c.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(
        text: ' · $count ${count == 1 ? 'dose' : 'doses'}',
      ),
    ];
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

/// Full-width 1px rule under the quiet status line, spanning the vine's grid.
/// Fades symmetrically at both ends via a linear gradient rather than stopping
/// on a hard divider edge.
class _StatusRule extends StatelessWidget {
  const _StatusRule();

  @override
  Widget build(BuildContext context) {
    final border = context.c.hairline;
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              border.withValues(alpha: 0),
              border,
              border,
              border.withValues(alpha: 0),
            ],
            stops: const [0, 0.1, 0.9, 1],
          ),
        ),
      ),
    );
  }
}
