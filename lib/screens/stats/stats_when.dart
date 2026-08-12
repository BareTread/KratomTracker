import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/analytics_service.dart';
import '../../theme/app_theme.dart';
import 'stats_common.dart';

/// The shape of an ordinary day. The caption says the same thing in words,
/// because the shape answers "when do I dose" only if you already know how to
/// read a histogram.
class WhenSection extends StatelessWidget {
  const WhenSection({super.key, required this.rhythm});

  static const double chartHeight = 84;

  final DayRhythm rhythm;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: whenCaption(rhythm) ?? 'No doses in this range.',
          child: SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _HoursPainter(
                hours: rhythm.hours,
                bar: c.accent,
                axis: c.hairline,
                labelColor: c.textTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          whenCaption(rhythm) ?? 'No doses in this range.',
          style: quietStyle(context),
        ),
      ],
    );
  }
}

/// "Most days run 8:10 am to 10:40 pm · busiest around 1 pm".
String? whenCaption(DayRhythm rhythm) {
  final first = rhythm.medianFirstMinute;
  final last = rhythm.medianLastMinute;
  final peak = rhythm.peakHour;
  if (first == null || last == null || peak == null) return null;

  final span = first == last
      ? 'Most days are a single dose around ${_clock(first)}'
      : 'Most days run ${_clock(first)} to ${_clock(last)}';
  return '$span · busiest around ${_hour(peak)}';
}

String _clock(int minuteOfDay) => DateFormat('h:mm a')
    .format(DateTime(2024, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60))
    .toLowerCase();

String _hour(int hour) =>
    DateFormat('h a').format(DateTime(2024, 1, 1, hour)).toLowerCase();

class _HoursPainter extends CustomPainter {
  const _HoursPainter({
    required this.hours,
    required this.bar,
    required this.axis,
    required this.labelColor,
  });

  final List<int> hours;
  final Color bar;
  final Color axis;
  final Color labelColor;

  static const double _bottomPad = 16;
  static const Map<int, String> _ticks = {
    0: '12a',
    6: '6a',
    12: '12p',
    18: '6p',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final plotBottom = size.height - _bottomPad;
    if (plotBottom <= 0 || size.width <= 0) return;

    var peak = 0;
    for (final count in hours) {
      if (count > peak) peak = count;
    }

    canvas.drawLine(
      Offset(0, plotBottom),
      Offset(size.width, plotBottom),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );

    final step = size.width / 24;
    final width = (step * 0.42).clamp(2.0, 6.0);
    for (var hour = 0; hour < 24; hour++) {
      final count = hours[hour];
      if (count <= 0 || peak <= 0) continue;
      final share = count / peak;
      final x = step * (hour + 0.5);
      canvas.drawLine(
        Offset(x, plotBottom - width / 2),
        Offset(x, plotBottom - width / 2 - share * (plotBottom - width)),
        Paint()
          // Busy hours read solid, quiet ones fade toward the ground rather
          // than standing as equals with a different height.
          ..color = bar.withValues(alpha: 0.32 + 0.58 * share)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }

    for (final tick in _ticks.entries) {
      final painter = TextPainter(
        text: TextSpan(
          text: tick.value,
          style: TextStyle(color: labelColor, fontSize: 10, height: 1.2),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final centre = step * (tick.key + 0.5) - painter.width / 2;
      painter.paint(
        canvas,
        Offset(
          centre.clamp(0.0, size.width - painter.width),
          plotBottom + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoursPainter old) =>
      old.hours != hours ||
      old.bar != bar ||
      old.axis != axis ||
      old.labelColor != labelColor;
}
