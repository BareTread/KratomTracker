import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dosage.dart';
import '../theme/app_theme.dart';

/// A whole day drawn as a pressed sprig. The stem is the day (midnight at the
/// top, midnight at the bottom), each leaf is one dose placed at its time of
/// day, a leaf's length is its grams on a scale shared by every sprig on the
/// screen, and its colour is the strain's. A day with no doses is a bare stem
/// with a closed bud: rest, not absence.
///
/// Nothing here is ornament. There is no wobble, no vein, no text inside the
/// glyph, and no randomness: the same day always draws the same sprig.

/// Leaf width over leaf length. One fixed aspect so a leaf's size reads as
/// one number (its length) and never as a second, invented one.
const double sprigLeafAspect = 0.34;

/// How far a leaf leans away from the stem, from vertical. Leaves point up
/// and out, the way a sprig grows toward the light.
const double sprigLeafLean = 56 * math.pi / 180;

/// Grams → leaf length on a shared, linear scale: 0 g is 0, [scaleGrams] (the
/// largest single dose on the screen) is [maxLength]. A tiny dose is floored
/// at [minLength] so it stays visible; nothing ever exceeds [maxLength].
double sprigLeafLength(
  double grams, {
  required double scaleGrams,
  required double maxLength,
  double minLength = 0,
}) {
  if (!(grams > 0) || !(maxLength > 0)) return 0;
  final scale = scaleGrams > 0 ? scaleGrams : grams;
  final raw = maxLength * (grams / scale).clamp(0.0, 1.0);
  return math.max(raw, math.min(minLength, maxLength));
}

/// Outline of one leaf: base at [base], tip [length] away along [angle]
/// (radians, screen coordinates, 0 = pointing right, -π/2 = straight up).
/// A pointed lanceolate blade, widest a little below the middle. [bend]
/// curls the tip sideways by that many half-widths (sign picks the side), so
/// a leaf can turn up toward the light instead of reading as a flat lozenge.
Path sprigLeafPath(
  Offset base,
  double length,
  double angle, {
  double aspect = sprigLeafAspect,
  double bend = 0,
}) {
  final dir = Offset(math.cos(angle), math.sin(angle));
  final normal = Offset(-dir.dy, dir.dx);
  final halfWidth = length * aspect / 2;
  Offset at(double along, double across) =>
      base + dir * (length * along) + normal * (halfWidth * across);
  final tip = at(1, bend);
  final a1 = at(0.22, 1.3 + bend * 0.1);
  final a2 = at(0.72, 1.15 + bend * 0.6);
  final b1 = at(0.72, -1.15 + bend * 0.6);
  final b2 = at(0.22, -1.3 + bend * 0.1);
  return Path()
    ..moveTo(base.dx, base.dy)
    ..cubicTo(a1.dx, a1.dy, a2.dx, a2.dy, tip.dx, tip.dy)
    ..cubicTo(b1.dx, b1.dy, b2.dx, b2.dy, base.dx, base.dy)
    ..close();
}

/// A leaf's fill is the strain's own colour; its edge is the same hue clamped
/// into the readable band for the theme ([legibleStrainColor]), so a pale
/// yellow on paper and a dark red on ink both keep a visible outline without
/// the fill losing its identity. Given the [surface] it sits on, a fill too
/// close to that surface (a white strain on paper) is drawn a third of the way
/// toward its edge colour, so it reads as a leaf, not as an empty outline.
({Color fill, Color edge}) sprigLeafColors(
  Color strain,
  Brightness brightness, {
  Color? surface,
}) {
  final edge = legibleStrainColor(strain, brightness);
  final faint = surface != null &&
      (strain.computeLuminance() - surface.computeLuminance()).abs() < 0.12;
  return (fill: faint ? Color.lerp(strain, edge, 0.35)! : strain, edge: edge);
}

/// One dose as a sprig sees it.
@immutable
class SprigDose {
  const SprigDose({
    required this.time,
    required this.grams,
    required this.color,
  });

  factory SprigDose.fromDosage(Dosage dose, Color color) =>
      SprigDose(time: dose.timestamp, grams: dose.amount, color: color);

  final DateTime time;
  final double grams;
  final Color color;

  /// Minutes since local midnight, 0 to 1440.
  double get minuteOfDay {
    final local = time.toLocal();
    return local.hour * 60 + local.minute + local.second / 60;
  }

  @override
  bool operator ==(Object other) =>
      other is SprigDose &&
      other.time == time &&
      other.grams == grams &&
      other.color == color;

  @override
  int get hashCode => Object.hash(time, grams, color);
}

/// "Mon 16 Nov, 3 doses, 49.4 g" or "Mon 16 Nov, rest day".
String daySprigLabel(DateTime day, List<SprigDose> doses) {
  final date = DateFormat('EEE d MMM').format(day);
  if (doses.isEmpty) return '$date, rest day';
  var total = 0.0;
  for (final dose in doses) {
    total += dose.grams;
  }
  final count = doses.length;
  return '$date, $count dose${count == 1 ? '' : 's'}, ${_grams(total)} g';
}

String _grams(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// The largest single dose among [days]: the shared scale every sprig on one
/// screen uses, so a long leaf means the same grams everywhere.
double sprigScaleFor(Iterable<List<SprigDose>> days) {
  var peak = 0.0;
  for (final day in days) {
    for (final dose in day) {
      if (dose.grams > peak) peak = dose.grams;
    }
  }
  return peak;
}

/// One day as a sprig. Size it with the parent (or [size]); the drawing scales
/// to the box: leaves fill the half-width, the stem the height.
class DaySprig extends StatelessWidget {
  const DaySprig({
    super.key,
    required this.doses,
    required this.scaleGrams,
    this.rest = true,
    this.semanticLabel,
    this.size = const Size(40, 90),
    this.surface,
  });

  /// The day's doses, any order.
  final List<SprigDose> doses;

  /// Largest single dose on this screen ([sprigScaleFor]).
  final double scaleGrams;

  /// Whether an empty day is a rest day (bud) or simply not over yet / not
  /// part of the record (bare stem, no bud).
  final bool rest;

  final String? semanticLabel;
  final Size size;

  /// The colour behind the sprig; defaults to the scaffold background.
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final painter = CustomPaint(
      size: size,
      painter: DaySprigPainter(
        doses: doses,
        scaleGrams: scaleGrams,
        rest: rest,
        stemColor: c.textSecondary,
        brightness: Theme.of(context).brightness,
        surface: surface ?? Theme.of(context).scaffoldBackgroundColor,
      ),
    );
    if (semanticLabel == null) return painter;
    return Semantics(label: semanticLabel, image: true, child: painter);
  }
}

/// Paints [doses] as a sprig into whatever box it is given.
class DaySprigPainter extends CustomPainter {
  DaySprigPainter({
    required List<SprigDose> doses,
    required this.scaleGrams,
    required this.rest,
    required this.stemColor,
    required this.brightness,
    this.surface,
  }) : doses = List.unmodifiable(
          [...doses]..sort((a, b) => a.time.compareTo(b.time)),
        );

  final List<SprigDose> doses;
  final double scaleGrams;
  final bool rest;
  final Color stemColor;
  final Brightness brightness;

  /// What the sprig is drawn on; lets a near-invisible fill be deepened.
  final Color? surface;

  /// Below this width the glyph is a micro-sprig: thinner edge, smaller floor.
  static const double _microWidth = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final micro = size.width < _microWidth;
    final halfWidth = size.width / 2;
    // Crisp 1px stem: centre it on a half pixel.
    final stemX = halfWidth.floorToDouble() + 0.5;
    final reach = math.min(stemX, size.width - stemX) - 0.75;
    final maxLeaf = reach / math.sin(sprigLeafLean);
    final rise = maxLeaf * math.cos(sprigLeafLean);
    // A short stalk at herbarium size: each dose meets the stem at one point
    // (its time) and the blade starts just clear of the stem, so two doses
    // close in time stay two leaves. Too small to read at micro size.
    final petiole = micro ? 0.0 : 2.5;
    final minLeaf = micro ? 3.0 : 5.0;
    final budLength = micro ? 5.0 : 9.0;

    // A leaf at 00:00 still has room to rise; the bud sits in the same room.
    final top = math.max(rise, budLength) + 0.5;
    final bottom = size.height - 0.5;
    if (bottom <= top) return;
    double yAt(double minute) =>
        top + (minute / 1440).clamp(0.0, 1.0) * (bottom - top);

    final stemPaint = Paint()
      ..color = stemColor.withValues(alpha: 0.7)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(stemX, top), Offset(stemX, bottom), stemPaint);

    if (doses.isEmpty) {
      if (rest) {
        final bud = sprigLeafPath(
          Offset(stemX, top),
          budLength,
          -math.pi / 2,
          aspect: 0.5,
        );
        canvas.drawPath(
          bud,
          Paint()..color = stemColor.withValues(alpha: 0.85),
        );
      }
      return;
    }

    // Leaves alternate right, left, right… in time order. A leaf on the same
    // side as the one before it must clear that leaf's blade, or a 20-minute
    // pair (or three doses inside the hour) prints as one blob. Leaning at
    // [sprigLeafLean], a blade of width w spans about w / sin(lean) of stem,
    // so a crowded leaf is nudged down by the least amount that clears it.
    // Across the stem the rule is lighter: a later dose always sits at least
    // [step] lower, so a 20-minute pair reads in order instead of as a
    // symmetrical bow.
    final step = micro ? 1.5 : 2.5;
    final lastY = <int, double>{};
    final lastLength = <int, double>{};
    double? lastAny;
    final edgeWidth = micro ? 0.6 : 0.8;
    for (var i = 0; i < doses.length; i++) {
      final dose = doses[i];
      final side = i.isEven ? 1 : -1;
      final length = sprigLeafLength(
        dose.grams,
        scaleGrams: scaleGrams,
        maxLength: maxLeaf - petiole,
        minLength: minLeaf,
      );
      if (length <= 0) continue;
      var y = yAt(dose.minuteOfDay);
      if (lastAny != null && y < lastAny + step) y = lastAny + step;
      final previous = lastY[side];
      if (previous != null) {
        final width = math.max(length, lastLength[side]!) * sprigLeafAspect;
        final gap = width * 1.35 / math.sin(sprigLeafLean);
        if (y < previous + gap) y = previous + gap;
      }
      y = math.min(y, bottom);
      lastY[side] = y;
      lastLength[side] = length;
      lastAny = y;

      final angle = side > 0
          ? -math.pi / 2 + sprigLeafLean
          : -math.pi / 2 - sprigLeafLean;
      final node = Offset(stemX, y);
      final base = node + Offset(math.cos(angle), math.sin(angle)) * petiole;
      // Tips turn up toward the light: that is -normal on the right side
      // and +normal on the left.
      final path = sprigLeafPath(
        base,
        length,
        angle,
        bend: side > 0 ? -1.2 : 1.2,
      );
      final colors = sprigLeafColors(
        dose.color,
        brightness,
        surface: surface,
      );
      if (petiole > 0) {
        canvas.drawLine(
          node,
          base,
          Paint()
            ..color = colors.edge
            ..strokeWidth = 0.9
            ..strokeCap = StrokeCap.round,
        );
      }
      // A touch under full strength, so the leaves sit in the same pen as
      // the Home leaf marks instead of reading as flat plastic.
      canvas.drawPath(
        path,
        Paint()..color = colors.fill.withValues(alpha: 0.86),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgeWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DaySprigPainter old) =>
      !listEquals(old.doses, doses) ||
      old.scaleGrams != scaleGrams ||
      old.rest != rest ||
      old.stemColor != stemColor ||
      old.brightness != brightness ||
      old.surface != surface;
}
