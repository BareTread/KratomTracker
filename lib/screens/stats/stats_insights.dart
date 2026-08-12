import 'package:flutter/material.dart';

import '../../domain/insights_service.dart';
import '../../theme/app_theme.dart';
import 'stats_common.dart';

/// The reading tier. Each line is one sentence about a change, and each stays
/// silent until it has enough behind it to be worth believing — the compute
/// side returns null rather than guess, so an absent line here means "not yet",
/// never "nothing happening".
class InsightsSection extends StatelessWidget {
  const InsightsSection({
    super.key,
    required this.gap,
    required this.cycle,
    required this.breadth,
    required this.firstDose,
  });

  final GapCompression? gap;
  final ReturnCycle? cycle;
  final RotationBreadth? breadth;
  final FirstDoseDrift? firstDose;

  /// Whether anything at all can be said, so the page can skip the section
  /// rather than print a heading over empty space.
  bool get hasAny =>
      gap != null || cycle != null || breadth != null || firstDose != null;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lines = <({String text, Color accent})>[];

    final spacing = gap;
    if (spacing != null) {
      lines.add(
        (
          text: spacing.isMaterial
              ? 'Your doses sit ${_gap(spacing.recent)} apart, '
                  '${_gap(spacing.delta.abs())} '
                  '${spacing.isCompressing ? 'closer together' : 'further apart'} '
                  'than the month before.'
              : 'Your doses sit ${_gap(spacing.recent)} apart, '
                  'much as they did the month before.',
          // Doses drawing closer is the one direction worth a second look.
          accent: spacing.isMaterial && spacing.isCompressing
              ? c.caution
              : c.textSecondary,
        ),
      );
    }

    final returns = cycle;
    if (returns != null) {
      final base = 'A strain usually rests ${_days(returns.median)} '
          'before you come back to it';
      lines.add(
        (
          text: returns.isMaterial
              ? '$base — ${_days(returns.delta!.abs())} '
                  '${returns.delta!.isNegative ? 'less' : 'more'} '
                  'than three months ago.'
              : '$base.',
          accent: c.textSecondary,
        ),
      );
    }

    final rotation = breadth;
    if (rotation != null && rotation.isNarrow) {
      lines.add(
        (
          text:
              'You reached for ${rotation.observed} strains this month, but the '
              'grams were spread like an even rotation of '
              '${rotation.effective.round()}.',
          accent: c.caution,
        ),
      );
    }

    final start = firstDose;
    if (start != null && start.isMaterial) {
      lines.add(
        (
          text: 'Your first dose lands around ${_clock(start.recentMinute)}, '
              '${_minutes(start.deltaMinutes.abs())} '
              '${start.isEarlier ? 'earlier' : 'later'} than a month ago.',
          accent: start.isEarlier ? c.caution : c.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A short tick rather than a bullet — the same restrained mark
                // the rest of the page uses to attach a note to a line.
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: SizedBox(
                    width: 10,
                    height: 1.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: line.accent.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.text,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _gap(Duration gap) {
  final hours = gap.inHours;
  final minutes = gap.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _minutes(int minutes) {
  if (minutes < 60) return '$minutes minutes';
  final hours = minutes ~/ 60;
  final rest = minutes.remainder(60);
  final hourLabel = hours == 1 ? '1 hour' : '$hours hours';
  return rest == 0 ? hourLabel : '$hourLabel ${rest}m';
}

String _days(Duration span) {
  final days = span.inHours / 24;
  if (days < 1) return '${span.inHours}h';
  if (days < 10) return '${formatAmount(days)} days';
  return '${days.round()} days';
}

String _clock(int minuteOfDay) {
  final hour24 = (minuteOfDay ~/ 60) % 24;
  final minute = minuteOfDay.remainder(60);
  final suffix = hour24 < 12 ? 'am' : 'pm';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final padded = minute.toString().padLeft(2, '0');
  return '$hour12:$padded$suffix';
}
