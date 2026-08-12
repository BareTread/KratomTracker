import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/vine_painter.dart';
import 'stats_bundle.dart';

/// Daily grams as a faint texture with the trailing 28-day median drawn over
/// it as a vine. The days are the ground, the line is the figure — no legend
/// needed to tell them apart, because one of them is obviously the subject.
class TrajectoryChart extends StatelessWidget {
  const TrajectoryChart({super.key, required this.bundle});

  static const double height = 156;

  final StatsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      container: true,
      label: 'Daily grams ${bundle.selected.phrase}, with a trailing '
          '$trajectoryWindowDays-day median trend line.',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrajectoryPainter(
            days: bundle.days,
            grams: bundle.dailyGrams,
            trend: bundle.trend,
            day: c.textTertiary,
            lineFrom: c.accentMuted,
            lineTo: c.accent,
            axis: c.hairline,
            labelColor: c.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  const _TrajectoryPainter({
    required this.days,
    required this.grams,
    required this.trend,
    required this.day,
    required this.lineFrom,
    required this.lineTo,
    required this.axis,
    required this.labelColor,
  });

  final List<DateTime> days;
  final List<double> grams;
  final List<double> trend;
  final Color day;
  final Color lineFrom;
  final Color lineTo;
  final Color axis;
  final Color labelColor;

  static const double _topPad = 15;
  static const double _bottomPad = 18;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.width <= 0) return;
    final plotBottom = size.height - _bottomPad;
    final plotHeight = plotBottom - _topPad;
    if (plotHeight <= 0) return;

    var peak = 0.0;
    for (final value in grams) {
      if (value > peak) peak = value;
    }
    for (final value in trend) {
      if (value > peak) peak = value;
    }
    final ceiling = _niceCeiling(peak <= 0 ? 1 : peak * 1.08);
    double y(double value) =>
        plotBottom - (value / ceiling).clamp(0.0, 1.0) * plotHeight;

    final step = size.width / days.length;
    double x(int i) => step * (i + 0.5);

    // Ceiling reference: dashed so it reads as a measure, not as a frame.
    canvas.drawPath(
      dashPath(
        Path()
          ..moveTo(0, y(ceiling))
          ..lineTo(size.width, y(ceiling)),
        pattern: const [2, 6],
      ),
      Paint()
        ..color = axis
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(0, plotBottom),
      Offset(size.width, plotBottom),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );

    // One day, one stroke — until the days are thinner than the strokes. Past
    // that, drawing them all just stacks translucent ink on the same pixel
    // until eighteen months reads as a solid grey slab. So bucket the days
    // into columns roughly 2.5px apart and let each column show its tallest
    // day: the spikes survive, the haze does not.
    const minStep = 2.5;
    final columns = step >= minStep
        ? [for (var i = 0; i < grams.length; i++) (x: x(i), value: grams[i])]
        : _bucket(grams, size.width, minStep);
    final barWidth = (step * 0.5).clamp(1.0, 3.5);
    final barPaint = Paint()
      ..color = day.withValues(alpha: 0.36)
      ..strokeWidth = barWidth
      ..strokeCap = barWidth >= 2 ? StrokeCap.round : StrokeCap.butt
      ..isAntiAlias = true;
    for (final column in columns) {
      if (column.value <= 0) continue;
      canvas.drawLine(
        Offset(column.x, plotBottom),
        Offset(column.x, y(column.value)),
        barPaint,
      );
    }

    if (trend.isNotEmpty) {
      final points = [
        for (var i = 0; i < trend.length; i++) Offset(x(i), y(trend[i])),
      ];
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      if (points.length == 1) {
        path.lineTo(points.first.dx + 0.5, points.first.dy);
      }
      // Quadratics through segment midpoints: smooth without inventing
      // wiggles the median does not have.
      for (var i = 1; i < points.length; i++) {
        final mid = Offset(
          (points[i - 1].dx + points[i].dx) / 2,
          (points[i - 1].dy + points[i].dy) / 2,
        );
        path.quadraticBezierTo(
          points[i - 1].dx,
          points[i - 1].dy,
          mid.dx,
          mid.dy,
        );
      }
      path.lineTo(points.last.dx, points.last.dy);

      paintVinePath(
        canvas,
        path,
        gradientStart: points.first,
        gradientEnd: points.last,
        fromColor: lineFrom,
        toColor: lineTo,
        coreWidth: 2.2,
      );

      // Terminal disc, same idiom as the vine's NOW tip: the line ends on
      // today rather than trailing off.
      canvas.drawCircle(points.last, 3.2, Paint()..color = lineTo);
      canvas.drawCircle(
        points.last,
        3.2,
        Paint()
          ..color = lineTo.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }

    _text(canvas, '${_trim(ceiling)}g', Offset(0, y(ceiling) - 14), false);
    final format = DateFormat('MMM d');
    _text(canvas, format.format(days.first), Offset(0, plotBottom + 4), false);
    if (days.length > 1) {
      _text(
        canvas,
        format.format(days.last),
        Offset(size.width, plotBottom + 4),
        true,
      );
    }
  }

  void _text(Canvas canvas, String value, Offset at, bool rightAlign) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: labelColor, fontSize: 10, height: 1.2),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      rightAlign ? Offset(at.dx - painter.width, at.dy) : at,
    );
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter old) =>
      old.days != days ||
      old.grams != grams ||
      old.trend != trend ||
      old.day != day ||
      old.lineFrom != lineFrom ||
      old.lineTo != lineTo ||
      old.axis != axis ||
      old.labelColor != labelColor;
}

/// Collapse a long day series into evenly spaced columns, each carrying the
/// heaviest day it covers.
List<({double x, double value})> _bucket(
  List<double> values,
  double width,
  double minStep,
) {
  final count = math.max(1, (width / minStep).floor());
  final peaks = List<double>.filled(count, 0);
  for (var i = 0; i < values.length; i++) {
    final slot = (i * count ~/ values.length).clamp(0, count - 1);
    if (values[i] > peaks[slot]) peaks[slot] = values[i];
  }
  final step = width / count;
  return [
    for (var i = 0; i < count; i++) (x: step * (i + 0.5), value: peaks[i]),
  ];
}

/// Round the axis ceiling up to a number a person would have picked.
double _niceCeiling(double value) {
  if (!value.isFinite || value <= 0) return 1;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  for (final multiple in const [1.0, 2.0, 2.5, 5.0]) {
    if (value <= multiple * magnitude) return multiple * magnitude;
  }
  return 10 * magnitude;
}

String _trim(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
