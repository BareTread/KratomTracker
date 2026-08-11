import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The six leaf forms a strain's mark can take.
///
/// Material has no leaf family — it offers three near-identical trees
/// (`forest`, `park`, `nature`), a flower, and some grass — which is why the
/// old icon set felt same-y. These are drawn for this app instead, chosen so
/// their *silhouettes* differ: a blob, two lobes, a three-point star, a
/// feather, a spiral, and a curl. That difference is what survives at 44px.
///
/// Identity is shape x tone within a vein colour. Six shapes against the three
/// tones the colour picker already offers gives 18 distinct marks per vein
/// family, for the ~6 strains that share one.
enum LeafShape {
  single,
  sprout,
  trefoil,
  broad,
  furl,
  vine;

  String get label => switch (this) {
        LeafShape.single => 'Single leaf',
        LeafShape.sprout => 'Sprout',
        LeafShape.trefoil => 'Trefoil',
        LeafShape.broad => 'Broad leaf',
        LeafShape.furl => 'Furled bud',
        LeafShape.vine => 'Vine',
      };
}

/// Paints a [LeafShape] into any rect, scaled from a 24x24 design grid.
class LeafMarkPainter extends CustomPainter {
  const LeafMarkPainter({required this.shape, required this.color});

  final LeafShape shape;
  final Color color;

  static const _grid = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _grid;
    canvas.save();
    canvas.translate(
      (size.width - _grid * scale) / 2,
      (size.height - _grid * scale) / 2,
    );
    canvas.scale(scale);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (shape) {
      case LeafShape.single:
        _single(canvas, fill, stroke);
      case LeafShape.sprout:
        _sprout(canvas, fill, stroke);
      case LeafShape.trefoil:
        _trefoil(canvas, fill, stroke);
      case LeafShape.broad:
        _broad(canvas, fill, stroke);
      case LeafShape.furl:
        _furl(canvas, stroke);
      case LeafShape.vine:
        _vine(canvas, fill, stroke);
    }

    canvas.restore();
  }

  /// A leaf blade with the midrib cut out of it, so it reads as a leaf rather
  /// than as a filled blob. The cut is done with [BlendMode.clear] inside a
  /// layer — subtracting a stroked path is not otherwise expressible.
  void _bladeWithMidrib(
    Canvas canvas,
    Path blade,
    Offset from,
    Offset to,
    Paint fill,
  ) {
    canvas.saveLayer(const Rect.fromLTWH(0, 0, _grid, _grid), Paint());
    canvas.drawPath(blade, fill);
    canvas.drawLine(
      from,
      to,
      Paint()
        ..blendMode = BlendMode.clear
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _single(Canvas canvas, Paint fill, Paint stroke) {
    final blade = Path()
      ..moveTo(4, 20)
      ..quadraticBezierTo(4, 6.5, 20, 4)
      ..quadraticBezierTo(17.5, 20, 4, 20)
      ..close();
    _bladeWithMidrib(canvas, blade, const Offset(5, 19), const Offset(18, 6), fill);
  }

  void _sprout(Canvas canvas, Paint fill, Paint stroke) {
    final left = Path()
      ..moveTo(12, 14.5)
      ..quadraticBezierTo(5, 15, 3.5, 7)
      ..quadraticBezierTo(10.5, 8.5, 12, 14.5)
      ..close();
    final right = Path()
      ..moveTo(12, 14.5)
      ..quadraticBezierTo(19, 15, 20.5, 7)
      ..quadraticBezierTo(13.5, 8.5, 12, 14.5)
      ..close();
    canvas.drawPath(left, fill);
    canvas.drawPath(right, fill);
    canvas.drawLine(
      const Offset(12, 21.5),
      const Offset(12, 13),
      stroke..strokeWidth = 1.8,
    );
  }

  void _trefoil(Canvas canvas, Paint fill, Paint stroke) {
    const centre = Offset(12, 12.5);
    final top = Path()
      ..moveTo(centre.dx, centre.dy)
      ..quadraticBezierTo(7.5, 8, 12, 2.5)
      ..quadraticBezierTo(16.5, 8, centre.dx, centre.dy)
      ..close();
    final lowerLeft = Path()
      ..moveTo(centre.dx, centre.dy)
      ..quadraticBezierTo(7.5, 10.5, 2.8, 15.5)
      ..quadraticBezierTo(9, 18, centre.dx, centre.dy)
      ..close();
    final lowerRight = Path()
      ..moveTo(centre.dx, centre.dy)
      ..quadraticBezierTo(16.5, 10.5, 21.2, 15.5)
      ..quadraticBezierTo(15, 18, centre.dx, centre.dy)
      ..close();
    canvas.drawPath(top, fill);
    canvas.drawPath(lowerLeft, fill);
    canvas.drawPath(lowerRight, fill);
    canvas.drawLine(
      centre,
      const Offset(12, 22),
      stroke..strokeWidth = 1.6,
    );
  }

  /// A wide, upright, symmetrical blade. This slot was originally a pinnate
  /// frond; at 44px the leaflets collapsed into a zipper, and fern detail was
  /// never going to survive that size. What the set was actually missing was a
  /// broad solid mass to contrast with [_single]'s narrow diagonal one.
  void _broad(Canvas canvas, Paint fill, Paint stroke) {
    final blade = Path()
      ..moveTo(12, 17.6)
      ..cubicTo(6.2, 17.1, 3.2, 13.8, 3.4, 10.2)
      ..cubicTo(3.8, 6.0, 9.2, 4.0, 12, 2.4)
      ..cubicTo(14.8, 4.0, 20.2, 6.0, 20.6, 10.2)
      ..cubicTo(20.8, 13.8, 17.8, 17.1, 12, 17.6)
      ..close();
    _bladeWithMidrib(
      canvas,
      blade,
      const Offset(12, 16.6),
      const Offset(12, 4.4),
      fill,
    );
    canvas.drawLine(
      const Offset(12, 22),
      const Offset(12, 17),
      stroke..strokeWidth = 1.7,
    );
  }

  void _furl(Canvas canvas, Paint stroke) {
    // A fiddlehead: a long stem that coils about one and a quarter turns.
    // Too short a stem and too tight a coil and it just reads as the letter P.
    final path = Path()
      ..moveTo(9.8, 22.2)
      ..cubicTo(9.6, 18.2, 9.6, 15.4, 11.2, 13.4)
      ..cubicTo(13.0, 11.2, 16.6, 11.8, 17.0, 14.4)
      ..cubicTo(17.4, 16.7, 15.0, 18.2, 13.4, 16.9)
      ..cubicTo(12.4, 16.1, 12.8, 14.6, 14.2, 14.9);
    canvas.drawPath(path, stroke..strokeWidth = 1.8);
  }

  void _vine(Canvas canvas, Paint fill, Paint stroke) {
    final stem = Path()
      ..moveTo(5, 21.5)
      ..cubicTo(7.5, 17.5, 8.5, 14, 11.5, 11.5)
      ..cubicTo(13.8, 9.6, 15.2, 8.6, 15.8, 6.2);
    canvas.drawPath(stem, stroke..strokeWidth = 1.8);

    final tendril = Path()
      ..moveTo(15.8, 6.2)
      ..cubicTo(16.2, 4.0, 19.2, 3.9, 19.2, 6.2)
      ..cubicTo(19.2, 7.9, 17.0, 8.1, 17.1, 6.4);
    canvas.drawPath(tendril, stroke..strokeWidth = 1.6);

    // The leaf has to be a readable blade, not a bud — at 44px a small filled
    // lozenge next to a stroke just looks like a dot on a line.
    final leaf = Path()
      ..moveTo(9.9, 13.3)
      ..cubicTo(7.6, 10.6, 4.0, 11.5, 3.1, 14.5)
      ..cubicTo(6.0, 16.9, 9.1, 16.0, 9.9, 13.3)
      ..close();
    _bladeWithMidrib(
      canvas,
      leaf,
      const Offset(9.4, 13.6),
      const Offset(4.0, 14.3),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant LeafMarkPainter old) =>
      old.shape != shape || old.color != color;
}

/// Renders a [LeafShape] as a widget, drawn in [color] at [size].
///
/// This is the single shared mark widget every strain surface renders
/// through — both strain forms, the strains screen, the picker tiles, and
/// the strain detail view. Marks are drawn in the strain's own colour; for
/// marks used as foreground on a dark surface where the raw colour would
/// vanish, callers can pass [legibleStrainColor] from `app_theme.dart`.
class StrainMark extends StatelessWidget {
  const StrainMark({
    super.key,
    required this.shape,
    required this.color,
    this.size = 24,
  });

  final LeafShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: LeafMarkPainter(shape: shape, color: color),
      ),
    );
  }
}

/// The parts of a strain that decide whether a (colour, shape) pair is
/// already taken. Kept as a record so [markCollision] stays independent of
/// the `Strain` model and avoids an import cycle.
typedef StrainMarkRef = ({
  String id,
  String name,
  int color,
  String icon,
  String code,
});

/// Maps a stored icon string to a [LeafShape].
///
/// Accepts both the new [LeafShape.name] values ("single", "sprout", ...) and
/// the legacy Material icon names the app used to write. Anything
/// unrecognised — including whatever the original app wrote that isn't in the
/// legacy table — falls back to a shape derived deterministically from
/// [code], so a 30-strain library doesn't collapse onto one shape. The same
/// code always yields the same shape.
LeafShape resolveLeafShape(String stored, String code) {
  final key = stored.trim().toLowerCase();
  for (final shape in LeafShape.values) {
    if (shape.name == key) return shape;
  }
  const legacy = <String, LeafShape>{
    'leaf': LeafShape.single,
    'herb': LeafShape.single,
    'natural': LeafShape.sprout,
    'yard': LeafShape.sprout,
    'organic': LeafShape.trefoil,
    'plant': LeafShape.broad,
    'flower': LeafShape.broad,
    'nature': LeafShape.broad,
    'park': LeafShape.furl,
    'forest': LeafShape.vine,
  };
  final mapped = legacy[key];
  if (mapped != null) return mapped;
  return LeafShape.values[_stableHash(code) % LeafShape.values.length];
}

/// A stable, run-to-run identical string hash. `String.hashCode` is not
/// guaranteed stable across isolates, which would break the contract that the
/// same code always maps to the same shape.
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return h;
}

/// Checks [shape] at [color] against [strains].
///
/// Returns the id and name of the strain that already owns the pair (if any)
/// and the set of shapes already taken for [color] by strains other than
/// [excludeId]. Used by the strain forms to warn — not block — before saving
/// a duplicate mark.
({String? ownerId, String? ownerName, Set<LeafShape> takenForColor})
    markCollision(
  Iterable<StrainMarkRef> strains,
  int color,
  LeafShape shape, {
  String? excludeId,
}) {
  final taken = <LeafShape>{};
  String? ownerId;
  String? ownerName;
  for (final s in strains) {
    if (s.id == excludeId) continue;
    if (s.color != color) continue;
    final sShape = resolveLeafShape(s.icon, s.code);
    taken.add(sShape);
    if (sShape == shape) {
      ownerId = s.id;
      ownerName = s.name;
    }
  }
  return (ownerId: ownerId, ownerName: ownerName, takenForColor: taken);
}
