import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared layout constants for the vine band. Kept here so the list rows and
/// their stem painters agree on the same geometry without a third file.
class VineGeometry {
  const VineGeometry._();

  static const double timeGutter = 64;
  static const double vineBand = 72;
  static const double leafSize = 40;
  static const double amplitude = 14;
  static const double stroke = 2.4;
  static const double petiole = 10;

  /// Stem is painted as three solid strokes back-to-front.
  static const double auraWidth = 13;
  static const double coreWidth = 2.4;
  static const double hairlineWidth = 0.8;
  static const double auraOpacity = 0.12;
  static const double coreOpacity = 0.62;
  static const double hairlineOpacity = 0.22;

  /// Warm off-white used for the hairline that keeps the stem legible on
  /// near-black surfaces. Fixed colour — not theme-derived — so the stem
  /// material stays consistent in light and dark.
  static const Color hairlineColor = Color(0xFFEDE6DC);

  /// Live tail (last dose → NOW) stroke craft.
  static const double liveWidth = 1.7;
  static const double liveOpacity = 0.72;
  static const List<double> liveDash = [2, 7];
  static const double liveDashTravel = 36;
  static const Duration livePeriod = Duration(milliseconds: 2800);

  /// Deterministic horizontal wander for node [index]. Same index always
  /// lands at the same offset so neighbouring segments join cleanly.
  static double offsetFor(int index) {
    // Two slow frequencies keep the path organic without looking random.
    return amplitude *
        (0.65 * math.sin(index * 0.95 + 0.4) +
            0.35 * math.sin(index * 1.7 + 1.1));
  }
}

/// Paint a cubic stem three times: wide low-opacity aura, core, hairline.
/// Solid strokes only — no MaskFilter blur (expensive on real Android GPUs).
void paintVinePath(
  Canvas canvas,
  Path path, {
  required Offset gradientStart,
  required Offset gradientEnd,
  required Color fromColor,
  required Color toColor,
  double coreWidth = VineGeometry.coreWidth,
}) {
  final auraFrom = fromColor.withValues(alpha: VineGeometry.auraOpacity);
  final auraTo = toColor.withValues(alpha: VineGeometry.auraOpacity);
  final coreFrom = fromColor.withValues(alpha: VineGeometry.coreOpacity);
  final coreTo = toColor.withValues(alpha: VineGeometry.coreOpacity);

  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = VineGeometry.auraWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        gradientStart,
        gradientEnd,
        [auraFrom, auraTo],
      ),
  );

  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = coreWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        gradientStart,
        gradientEnd,
        [coreFrom, coreTo],
      ),
  );

  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = VineGeometry.hairlineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = VineGeometry.hairlineColor
          .withValues(alpha: VineGeometry.hairlineOpacity),
  );
}

/// Dash [source] with [pattern] (on, off, on, off…) and a phase [offset].
/// Positive offset advances the pattern along the path (i.e. animating offset
/// negative makes dashes travel toward the tip).
Path dashPath(
  Path source, {
  required List<double> pattern,
  double offset = 0,
}) {
  assert(pattern.isNotEmpty);
  final dashed = Path();
  final cycle = pattern.fold<double>(0, (a, b) => a + b);
  for (final metric in source.computeMetrics()) {
    final length = metric.length;
    // Convert offset into a positive phase within one full pattern cycle.
    var phase = cycle == 0 ? 0.0 : offset % cycle;
    if (phase < 0) phase += cycle;

    // Skip [phase] into the pattern before emitting.
    var patternIndex = 0;
    var intoSegment = phase;
    while (intoSegment >= pattern[patternIndex % pattern.length]) {
      intoSegment -= pattern[patternIndex % pattern.length];
      patternIndex++;
    }

    var distance = 0.0;
    var drawOn = patternIndex.isEven;
    var segmentLeft = pattern[patternIndex % pattern.length] - intoSegment;

    while (distance < length) {
      final take = math.min(segmentLeft, length - distance);
      if (drawOn) {
        dashed.addPath(
          metric.extractPath(distance, distance + take),
          Offset.zero,
        );
      }
      distance += take;
      segmentLeft -= take;
      if (segmentLeft <= 0) {
        patternIndex++;
        drawOn = patternIndex.isEven;
        segmentLeft = pattern[patternIndex % pattern.length];
      }
    }
  }
  return dashed;
}

void paintLiveTail(
  Canvas canvas,
  Path path, {
  required Color color,
  required double dashOffset,
}) {
  final dashed = dashPath(
    path,
    pattern: VineGeometry.liveDash,
    offset: dashOffset,
  );
  canvas.drawPath(
    dashed,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = VineGeometry.liveWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = color.withValues(alpha: VineGeometry.liveOpacity),
  );
}

/// Vertical stem segment inside a single dose row. Joins to the gap strips
/// above and below so the full vine reads as one continuous path. Colour
/// interpolates from the neighbour above through this leaf to the neighbour
/// below.
class VineRowStemPainter extends CustomPainter {
  const VineRowStemPainter({
    required this.xOffset,
    required this.colorAbove,
    required this.colorMid,
    required this.colorBelow,
    required this.extendUp,
    required this.extendDown,
  });

  final double xOffset;
  final Color colorAbove;
  final Color colorMid;
  final Color colorBelow;
  final bool extendUp;
  final bool extendDown;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final midY = size.height / 2;
    final topY = extendUp ? 0.0 : midY - 22;
    final botY = extendDown ? size.height : midY + 22;
    // Soft horizontal ease into the leaf's offset.
    final topX = cx + xOffset * (extendUp ? 0.7 : 0.3);
    final midX = cx + xOffset;
    final botX = cx + xOffset * (extendDown ? 0.7 : 0.3);

    final topPath = Path()
      ..moveTo(topX, topY)
      ..cubicTo(
        topX + (midX - topX) * 0.2,
        topY + (midY - topY) * 0.4,
        midX - (midX - topX) * 0.15,
        midY - (midY - topY) * 0.25,
        midX,
        midY,
      );
    paintVinePath(
      canvas,
      topPath,
      gradientStart: Offset(topX, topY),
      gradientEnd: Offset(midX, midY),
      fromColor: colorAbove,
      toColor: colorMid,
    );

    final botPath = Path()
      ..moveTo(midX, midY)
      ..cubicTo(
        midX + (botX - midX) * 0.15,
        midY + (botY - midY) * 0.25,
        botX - (botX - midX) * 0.2,
        botY - (botY - midY) * 0.4,
        botX,
        botY,
      );
    paintVinePath(
      canvas,
      botPath,
      gradientStart: Offset(midX, midY),
      gradientEnd: Offset(botX, botY),
      fromColor: colorMid,
      toColor: colorBelow,
    );

    // Short petiole out to the leaf — core + hairline only (no aura).
    final side = (xOffset >= 0) ? 1.0 : -1.0;
    final petiolePath = Path()
      ..moveTo(midX, midY)
      ..lineTo(midX + side * VineGeometry.petiole * 0.55, midY - 1);
    canvas.drawPath(
      petiolePath,
      Paint()
        ..color = colorMid.withValues(alpha: VineGeometry.coreOpacity)
        ..strokeWidth = VineGeometry.coreWidth * 0.85
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      petiolePath,
      Paint()
        ..color = VineGeometry.hairlineColor
            .withValues(alpha: VineGeometry.hairlineOpacity)
        ..strokeWidth = VineGeometry.hairlineWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant VineRowStemPainter old) =>
      old.xOffset != xOffset ||
      old.colorAbove != colorAbove ||
      old.colorMid != colorMid ||
      old.colorBelow != colorBelow ||
      old.extendUp != extendUp ||
      old.extendDown != extendDown;
}

/// Stem segment across an inter-row gap strip, colour-lerping between the
/// leaves it joins. When [live] is true the segment is the animated dashed
/// tail into NOW instead of the solid three-stroke stem.
class VineGapStemPainter extends CustomPainter {
  const VineGapStemPainter({
    required this.fromOffset,
    required this.toOffset,
    required this.fromColor,
    required this.toColor,
    this.live = false,
    this.dashOffset = 0,
    this.liveColor,
  });

  final double fromOffset;
  final double toOffset;
  final Color fromColor;
  final Color toColor;
  final bool live;
  final double dashOffset;
  final Color? liveColor;

  Path _path(Size size) {
    final cx = size.width / 2;
    // Join points: dose rows expose their stem at 0.7 × offset at the edge.
    final p0 = Offset(cx + fromOffset * 0.7, 0);
    final p3 = Offset(cx + toOffset * 0.7, size.height);
    final p1 = Offset(
      p0.dx + (p3.dx - p0.dx) * 0.2,
      size.height * 0.35,
    );
    final p2 = Offset(
      p3.dx - (p3.dx - p0.dx) * 0.2,
      size.height * 0.65,
    );
    return Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    if (live) {
      paintLiveTail(
        canvas,
        path,
        color: liveColor ?? toColor,
        dashOffset: dashOffset,
      );
      return;
    }
    final cx = size.width / 2;
    final p0 = Offset(cx + fromOffset * 0.7, 0);
    final p3 = Offset(cx + toOffset * 0.7, size.height);
    paintVinePath(
      canvas,
      path,
      gradientStart: p0,
      gradientEnd: p3,
      fromColor: fromColor,
      toColor: toColor,
    );
  }

  @override
  bool shouldRepaint(covariant VineGapStemPainter old) =>
      old.fromOffset != fromOffset ||
      old.toOffset != toOffset ||
      old.fromColor != fromColor ||
      old.toColor != toColor ||
      old.live != live ||
      old.dashOffset != dashOffset ||
      old.liveColor != liveColor;
}

/// Terminal shoot into the NOW disc. On an empty today [hasPrior] is false
/// and a short young-shoot curve rises into the tip. When [live] is true the
/// stem is the animated dashed cyan tail.
class VineNowStemPainter extends CustomPainter {
  const VineNowStemPainter({
    required this.xOffset,
    required this.fromColor,
    required this.tipColor,
    required this.hasPrior,
    this.live = false,
    this.dashOffset = 0,
    this.liveColor,
  });

  final double xOffset;
  final Color fromColor;
  final Color tipColor;
  final bool hasPrior;
  final bool live;
  final double dashOffset;
  final Color? liveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final tip = Offset(cx + xOffset, size.height * 0.55);
    final top = Offset(
      cx + (hasPrior ? xOffset * 0.5 : 0),
      hasPrior ? 0 : 8,
    );

    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..cubicTo(
        top.dx + (tip.dx - top.dx) * 0.2,
        top.dy + (tip.dy - top.dy) * 0.4,
        tip.dx - (tip.dx - top.dx) * 0.15,
        tip.dy - (tip.dy - top.dy) * 0.3,
        tip.dx,
        tip.dy,
      );

    if (live) {
      paintLiveTail(
        canvas,
        path,
        color: liveColor ?? tipColor,
        dashOffset: dashOffset,
      );
    } else {
      paintVinePath(
        canvas,
        path,
        gradientStart: top,
        gradientEnd: tip,
        fromColor: fromColor,
        toColor: tipColor,
      );
    }

    // Terminal disc.
    final discColor = live ? (liveColor ?? tipColor) : tipColor;
    canvas.drawCircle(
      tip,
      5.5,
      Paint()
        ..color = discColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      tip,
      5.5,
      Paint()
        ..color = discColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant VineNowStemPainter old) =>
      old.xOffset != xOffset ||
      old.fromColor != fromColor ||
      old.tipColor != tipColor ||
      old.hasPrior != hasPrior ||
      old.live != live ||
      old.dashOffset != dashOffset ||
      old.liveColor != liveColor;
}
