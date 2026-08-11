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
  static const double stroke = 2.4;

  /// Centreline distance from band centre to stem so the stem (incl. aura)
  /// never runs under the 40px mark. leafRadius (20) + half aura (4) +
  /// air gap (3) ≈ 27. Stem is always on the LEFT of the centred leaf.
  static const double stemClearance = 27;

  /// Slow organic meander around [stemClearance] (≈2–3 px). No side flips.
  static const double stemMeander = 2.5;

  /// Stem is painted as three solid strokes back-to-front.
  static const double auraWidth = 8;
  static const double coreWidth = 2.4;
  static const double hairlineWidth = 0.8;
  static const double auraOpacity = 0.07;
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

  /// Horizontal offset of the continuous stem from the vine-band centre at
  /// node [index]. Always negative (LEFT of the centred leaf) with only a
  /// slow 2–3 px meander — every leaf reads as growing right from the stem.
  /// No full side flips, no herringbone diagonals, no stem under the mark.
  static double offsetFor(int index) {
    final meander = stemMeander * math.sin(index * 0.95 + 0.4) +
        0.5 * math.sin(index * 1.7 + 1.1);
    // Hard floor: leaf radius + half aura. Hard ceiling: band edge − aura.
    final minClear = leafSize / 2 + auraWidth / 2; // 24
    final maxOff = vineBand / 2 - auraWidth / 2 - 2; // ≈ 30
    final magnitude = (stemClearance + meander).clamp(minClear, maxOff);
    return -magnitude;
  }

  /// True when [offset] places the stem fully outside the leaf body
  /// (accounting for half the aura width). Used by tests and assertions.
  static bool stemClearsLeaf(double offset) {
    return offset.abs() >= leafSize / 2 + auraWidth / 2;
  }
}

/// Adaptive vertical rhythm for the dose ledger. On low-dose days the rows
/// and gaps expand (within min/max) so the story fills the available
/// viewport; at 6+ doses the base pitches are kept and the list scrolls.
///
/// Expansion is **not** time-proportional — every gap grows equally. Uses
/// real [viewportHeight] from a [LayoutBuilder], not a hard-coded phone.
class VineRhythm {
  const VineRhythm({
    required this.rowPitch,
    required this.gapStrip,
    required this.nowPitch,
  });

  final double rowPitch;
  final double gapStrip;
  final double nowPitch;

  /// Comfortable base sizes (4–5 dose days, and the floor for expansion).
  static const double baseRow = 92;
  static const double baseGap = 28;
  static const double baseNow = 72;

  static const double minRow = 80;
  static const double maxRow = 148;
  static const double minGap = 22;

  /// High enough that 1–3 dose days can stretch the vine through a phone
  /// body without looking like a sparse stick figure.
  static const double maxGap = 120;
  static const double minNow = 64;
  static const double maxNow = 108;

  /// ListView padding — must match [HomeDosageList].
  /// [listBottomPad] is scroll/FAB safety, not the composition target.
  static const double listTopPad = 4;
  static const double listBottomPad = 88;

  /// TODAY composition clearance: NOW sits near the body bottom with only
  /// a small air gap before the FAB zone. Scroll padding is separate.
  static const double todayClearance = 20;

  /// PAST composition clearance: last row carries a right-side amount that
  /// must stay clear of the circular FAB — keep the conservative pad.
  static const double pastClearance = 88;

  static const VineRhythm base = VineRhythm(
    rowPitch: baseRow,
    gapStrip: baseGap,
    nowPitch: baseNow,
  );

  /// Compute pitches for [doseCount] nodes inside a viewport of
  /// [viewportHeight] logical pixels. [showNow] adds the terminal NOW row.
  ///
  /// Composition target ≠ scroll padding: for TODAY the story is allowed
  /// to occupy almost the full list body (only [todayClearance] remains);
  /// for PAST days the conservative [pastClearance] keeps amounts off the
  /// FAB. Gaps are not time-proportional — every gap grows equally.
  factory VineRhythm.compute({
    required double viewportHeight,
    required int doseCount,
    required bool showNow,
  }) {
    // Unbounded / unknown height → base (safe for tests without constraints).
    if (!viewportHeight.isFinite || viewportHeight <= 0) {
      return base;
    }

    final rows = doseCount;
    final nows = showNow ? 1 : 0;
    // Gaps sit between consecutive nodes on the vine.
    final gaps = () {
      final nodes = rows + nows;
      if (nodes <= 1) return 0;
      return nodes - 1;
    }();

    // Empty today (NOW only) or empty past — keep compact.
    if (rows == 0) return base;

    // 6+ doses: scroll at base rhythm; do not compress into the viewport.
    if (rows >= 6) return base;

    // Visible composition target — do NOT subtract listBottomPad here.
    // That pad is retained on the ListView for scroll/FAB safety and may
    // leave a small scroll extent after content; that is acceptable.
    final clearance = showNow ? todayClearance : pastClearance;
    final available = viewportHeight - listTopPad - clearance;
    if (available <= 0) return base;

    var row = baseRow;
    var gap = baseGap;
    var now = baseNow;

    double total() => rows * row + gaps * gap + nows * now;

    // Already fills or overflows — keep base (list scrolls if needed).
    if (total() >= available) {
      return VineRhythm(rowPitch: row, gapStrip: gap, nowPitch: now);
    }

    // Cap how far we expand by dose count so 4–5 stay "comfortable"
    // rather than sparse, while 1–3 may fill the screen.
    // Very low counts get higher ceilings so a single leaf + NOW can still
    // walk the body of a phone without clustering under the day card.
    final double maxRowCap;
    final double maxGapCap;
    final double maxNowCap;
    if (rows <= 2) {
      maxRowCap = 200;
      maxGapCap = 160;
      maxNowCap = 140;
    } else if (rows <= 3) {
      maxRowCap = maxRow;
      maxGapCap = maxGap;
      maxNowCap = maxNow;
    } else {
      maxRowCap = baseRow * 1.18;
      maxGapCap = baseGap * 1.45;
      maxNowCap = baseNow * 1.15;
    }

    var leftover = available - total();

    // Prefer breathing the gaps (botanical spacing) before stretching rows.
    if (gaps > 0 && leftover > 0) {
      final roomPer = (maxGapCap - gap).clamp(0.0, double.infinity);
      final room = roomPer * gaps;
      final take = math.min(leftover, room);
      gap += take / gaps;
      leftover -= take;
    }

    if (rows > 0 && leftover > 0) {
      final roomPer = (maxRowCap - row).clamp(0.0, double.infinity);
      final room = roomPer * rows;
      final take = math.min(leftover, room);
      row += take / rows;
      leftover -= take;
    }

    if (nows > 0 && leftover > 0) {
      final room = (maxNowCap - now).clamp(0.0, double.infinity);
      final take = math.min(leftover, room);
      now += take;
    }

    // Final clamp uses the dose-aware caps (not the static max*) so 1–2
    // dose days can actually reach the higher ceilings above.
    return VineRhythm(
      rowPitch: row.clamp(minRow, maxRowCap),
      gapStrip: gap.clamp(minGap, maxGapCap),
      nowPitch: now.clamp(minNow, maxNowCap),
    );
  }

  /// Total content height (rows + gaps + optional NOW), excluding list pads.
  double contentHeight({required int doseCount, required bool showNow}) {
    final rows = doseCount;
    final nows = showNow ? 1 : 0;
    final nodes = rows + nows;
    final gaps = nodes <= 1 ? 0 : nodes - 1;
    return rows * rowPitch + gaps * gapStrip + nows * nowPitch;
  }

  @override
  bool operator ==(Object other) =>
      other is VineRhythm &&
      other.rowPitch == rowPitch &&
      other.gapStrip == gapStrip &&
      other.nowPitch == nowPitch;

  @override
  int get hashCode => Object.hash(rowPitch, gapStrip, nowPitch);
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
      ..shader = ui.Gradient.linear(gradientStart, gradientEnd, [
        auraFrom,
        auraTo,
      ]),
  );

  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = coreWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(gradientStart, gradientEnd, [
        coreFrom,
        coreTo,
      ]),
  );

  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = VineGeometry.hairlineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = VineGeometry.hairlineColor.withValues(
        alpha: VineGeometry.hairlineOpacity,
      ),
  );
}

/// Dash [source] with [pattern] (on, off, on, off…) and a phase [offset].
/// Positive offset advances the pattern along the path (i.e. animating offset
/// negative makes dashes travel toward the tip).
Path dashPath(Path source, {required List<double> pattern, double offset = 0}) {
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

/// Vertical stem segment inside a single dose row. The continuous vine runs
/// **beside** the leaf (at [xOffset] from band centre) and a short petiole
/// reaches from the stem to the leaf's near edge. Colour interpolates from
/// the neighbour above through this leaf to the neighbour below.
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

    // Stem x at the row mid — beside the leaf, never through it.
    final stemX = cx + xOffset;
    // Soft horizontal ease toward neighbours (join factor 0.7 matches gaps).
    // The first and last stubs stay near-vertical (0.95): easing them back
    // toward the band centre hung a hook off each end of the vine.
    final topX = cx + xOffset * (extendUp ? 0.7 : 0.95);
    final botX = cx + xOffset * (extendDown ? 0.7 : 0.95);

    final topPath = Path()
      ..moveTo(topX, topY)
      ..cubicTo(
        topX + (stemX - topX) * 0.2,
        topY + (midY - topY) * 0.4,
        stemX - (stemX - topX) * 0.15,
        midY - (midY - topY) * 0.25,
        stemX,
        midY,
      );
    paintVinePath(
      canvas,
      topPath,
      gradientStart: Offset(topX, topY),
      gradientEnd: Offset(stemX, midY),
      fromColor: colorAbove,
      toColor: colorMid,
    );

    final botPath = Path()
      ..moveTo(stemX, midY)
      ..cubicTo(
        stemX + (botX - stemX) * 0.15,
        midY + (botY - midY) * 0.25,
        botX - (botX - stemX) * 0.2,
        botY - (botY - midY) * 0.4,
        botX,
        botY,
      );
    paintVinePath(
      canvas,
      botPath,
      gradientStart: Offset(stemX, midY),
      gradientEnd: Offset(botX, botY),
      fromColor: colorMid,
      toColor: colorBelow,
    );

    // Petiole: short spur from the left-side stem to the leaf's near (left)
    // edge. Core + hairline only (no aura) so it reads as a fine stalk.
    final leafEdgeX = cx - (VineGeometry.leafSize / 2 - 1);
    // Slight upward lift keeps the petiole from reading as a hard T-joint.
    final petiolePath = Path()
      ..moveTo(stemX, midY)
      ..quadraticBezierTo(
        (stemX + leafEdgeX) / 2,
        midY - 2.5,
        leafEdgeX,
        midY - 0.5,
      );
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
        ..color = VineGeometry.hairlineColor.withValues(
          alpha: VineGeometry.hairlineOpacity,
        )
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
    final p1 = Offset(p0.dx + (p3.dx - p0.dx) * 0.2, size.height * 0.35);
    final p2 = Offset(p3.dx - (p3.dx - p0.dx) * 0.2, size.height * 0.65);
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
    // Tip sits on the stem path (small disc — no leaf to clear).
    final tip = Offset(cx + xOffset, size.height * 0.55);
    final top = Offset(cx + (hasPrior ? xOffset * 0.7 : 0), hasPrior ? 0 : 8);

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
