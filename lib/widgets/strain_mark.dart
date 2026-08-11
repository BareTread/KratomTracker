import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The ten ribbed-stroke leaf forms a strain's mark can take.
///
/// Family B from the mark sheet: open path-work only — outer contour, heavier
/// midrib, optional laterals. Round caps and joins, no fills. Chosen so their
/// *silhouettes* stay distinguishable at 20px on a near-black ground.
///
/// Identity is shape × tone within a vein colour. Ten shapes against the three
/// tones the colour picker already offers gives 30 distinct marks per vein
/// family.
enum LeafShape {
  oval,
  lance,
  cordate,
  oblique,
  trifol,
  palmate,
  capsule,
  paired,
  toothed,
  spathe;

  String get label => switch (this) {
        LeafShape.oval => 'Oval',
        LeafShape.lance => 'Lance',
        LeafShape.cordate => 'Cordate',
        LeafShape.oblique => 'Oblique',
        LeafShape.trifol => 'Trifol',
        LeafShape.palmate => 'Palmate',
        LeafShape.capsule => 'Capsule',
        LeafShape.paired => 'Paired',
        LeafShape.toothed => 'Toothed',
        LeafShape.spathe => 'Spathe',
      };
}

/// One stroked path in grid units, with its design stroke weight.
class _StrokePath {
  const _StrokePath(this.path, this.weight);
  final Path path;
  final double weight;
}

/// Paints a [LeafShape] into any rect.
///
/// Marks are authored on a 24×24 design grid and scaled by **one factor
/// shared by the whole family** — the factor that fits the family's combined
/// ink bounds into the destination — then centred on each mark's own ink.
///
/// The shared factor is the point. Fitting each mark to its own bounds
/// inflates every silhouette to the same square: a narrow lance and a broad
/// oval both come out as the same disc and stop being tellable apart at a
/// glance, which is the whole job of the mark. One factor keeps narrow marks
/// narrow and broad marks broad while none of them floats undersized.
class LeafMarkPainter extends CustomPainter {
  const LeafMarkPainter({required this.shape, required this.color});

  final LeafShape shape;
  final Color color;

  /// Design-grid reference size used only to set absolute stroke weight.
  static const _grid = 24.0;

  // Grid-unit stroke weights. The contour carries the silhouette, so it is
  // the heaviest line and the midrib sits under it. A midrib heavier than the
  // contour turns an upright mark on a vertical timeline into a shape with a
  // pole driven through it.
  static const _contourW = 2.3;
  static const _midribW = 1.8;
  static const _lateralW = 1.5;

  /// Inset fraction of the destination short side, applied equally on all
  /// four edges so ink never kisses the box edge.
  static const _padFrac = 0.04;

  /// Combined ink bounds of every mark in the family, in grid units. Computed
  /// once; the shared fit scale comes from this, never from one mark's bounds.
  static final Rect _familyInk = _inkOf(LeafShape.values.expand(_strokesFor));

  static Rect _inkOf(Iterable<_StrokePath> strokes) {
    Rect? ink;
    for (final s in strokes) {
      final b = s.path.getBounds().inflate(s.weight / 2);
      ink = ink == null ? b : ink.expandToInclude(b);
    }
    return ink ?? const Rect.fromLTWH(0, 0, _grid, _grid);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokes = _strokesFor(shape);
    if (strokes.isEmpty) return;

    // Destination rect with a small consistent padding inset.
    final pad = math.min(size.width, size.height) * _padFrac;
    final dest = Rect.fromLTWH(
      pad,
      pad,
      size.width - 2 * pad,
      size.height - 2 * pad,
    );
    if (dest.isEmpty) return;

    // One scale for the whole family: the largest mark just fits the box and
    // every other mark keeps its true proportion relative to it.
    final fit = math.min(
      dest.width / _familyInk.width,
      dest.height / _familyInk.height,
    );

    // Centred on this mark's own ink, so nothing sits off-axis.
    final ink = _inkOf(strokes);
    final ox = dest.center.dx - ink.center.dx * fit;
    final oy = dest.center.dy - ink.center.dy * fit;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(fit);

    // Weights are grid units under the shared scale, so every mark paints at
    // the same optical stroke without per-mark compensation.
    for (final s in strokes) {
      canvas.drawPath(s.path, _paint(s.weight));
    }

    canvas.restore();
  }

  Paint _paint(double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  // ── marks ──────────────────────────────────────────────────────────
  // Family B (Ribbed Stroke) from the mark sheet, redrawn where a silhouette
  // failed on the device: blades now come to a point at both ends, lateral
  // veins run outward *and apex-ward* (drawn downward they turned every mark
  // into a struck-through symbol), and the three marks that had degenerated
  // into a gear, a snowflake and a pair of spectacles are leaves again.

  static List<_StrokePath> _strokesFor(LeafShape shape) => switch (shape) {
        LeafShape.oval => _oval(),
        LeafShape.lance => _lance(),
        LeafShape.cordate => _cordate(),
        LeafShape.oblique => _oblique(),
        LeafShape.trifol => _trifol(),
        LeafShape.palmate => _palmate(),
        LeafShape.capsule => _capsule(),
        LeafShape.paired => _paired(),
        LeafShape.toothed => _toothed(),
        LeafShape.spathe => _spathe(),
      };

  static _StrokePath _line(Offset a, Offset b, double w) =>
      _StrokePath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), w);

  /// Broad kratom-like blade — apex and base both come to a point, which is
  /// what separates a leaf from a disc.
  static List<_StrokePath> _oval() => [
        _StrokePath(
          Path()
            ..moveTo(12, 2)
            ..cubicTo(16.8, 5.2, 19.8, 8.8, 19.8, 12.6)
            ..cubicTo(19.8, 16.6, 16.4, 20.2, 12, 22.2)
            ..cubicTo(7.6, 20.2, 4.2, 16.6, 4.2, 12.6)
            ..cubicTo(4.2, 8.8, 7.2, 5.2, 12, 2)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 5), const Offset(12, 20.4), _midribW),
        _line(const Offset(12, 14.6), const Offset(8.4, 11.4), _lateralW),
        _line(const Offset(12, 14.6), const Offset(15.6, 11.4), _lateralW),
        _line(const Offset(12, 10.4), const Offset(9.2, 7.6), _lateralW),
        _line(const Offset(12, 10.4), const Offset(14.8, 7.6), _lateralW),
      ];

  /// Long narrow lanceolate — the classic slim leaf. Contour + midrib only.
  static List<_StrokePath> _lance() => [
        _StrokePath(
          Path()
            ..moveTo(12, 1.8)
            ..cubicTo(13.8, 1.8, 15.2, 5.4, 16, 9.4)
            ..cubicTo(16.8, 13.6, 17, 17.6, 15.2, 20.2)
            ..cubicTo(14.1, 21.8, 13, 22.4, 12, 22.6)
            ..cubicTo(11, 22.4, 9.9, 21.8, 8.8, 20.2)
            ..cubicTo(7, 17.6, 7.2, 13.6, 8, 9.4)
            ..cubicTo(8.8, 5.4, 10.2, 1.8, 12, 1.8)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 4.2), const Offset(12, 20.4), _midribW),
      ];

  /// Cordate — notched top, pointed tip. One pair of laterals.
  static List<_StrokePath> _cordate() => [
        _StrokePath(
          Path()
            ..moveTo(12, 4.4)
            ..cubicTo(13.3, 2.8, 15.8, 2.4, 17.5, 3.8)
            ..cubicTo(19.6, 5.4, 20, 8.6, 18.7, 11.4)
            ..cubicTo(17.2, 14.6, 14.4, 17.8, 12, 21.6)
            ..cubicTo(9.6, 17.8, 6.8, 14.6, 5.3, 11.4)
            ..cubicTo(4, 8.6, 4.4, 5.4, 6.5, 3.8)
            ..cubicTo(8.2, 2.4, 10.7, 2.8, 12, 4.4)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 7), const Offset(12, 18.2), _midribW),
        _line(const Offset(12, 13.8), const Offset(9, 10.8), _lateralW),
        _line(const Offset(12, 13.8), const Offset(15, 10.8), _lateralW),
      ];

  /// Oblique — asymmetric blade, midrib offset.
  static List<_StrokePath> _oblique() => [
        _StrokePath(
          Path()
            ..moveTo(13.4, 2)
            ..cubicTo(17.6, 2.8, 20.4, 7, 20.2, 11.6)
            ..cubicTo(20, 16, 17.2, 20, 13, 21.6)
            ..lineTo(11.4, 22.1)
            ..lineTo(10, 21.3)
            ..cubicTo(6.4, 19.2, 4.2, 15.2, 4.4, 10.8)
            ..cubicTo(4.6, 7, 6.8, 3.6, 10.2, 2.5)
            ..cubicTo(11.2, 2.1, 12.4, 1.9, 13.4, 2)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12.6, 4.6), const Offset(10.8, 19.4), _midribW),
        _line(const Offset(11.5, 13.6), const Offset(8.4, 10.6), _lateralW),
        _line(const Offset(11.9, 10.6), const Offset(15.2, 8.4), _lateralW),
      ];

  /// Trifoliate — three leaflets on a stem.
  static List<_StrokePath> _trifol() => [
        // Top leaflet.
        _StrokePath(
          Path()
            ..moveTo(12, 2.2)
            ..cubicTo(14.6, 2.2, 16.6, 4.8, 16.6, 7.6)
            ..cubicTo(16.6, 9.8, 15.2, 11.6, 13.2, 12.2)
            ..lineTo(12, 12.6)
            ..lineTo(10.8, 12.2)
            ..cubicTo(8.8, 11.6, 7.4, 9.8, 7.4, 7.6)
            ..cubicTo(7.4, 4.8, 9.4, 2.2, 12, 2.2)
            ..close(),
          _contourW,
        ),
        // Left leaflet.
        _StrokePath(
          Path()
            ..moveTo(4.4, 10.6)
            ..cubicTo(4.4, 8.4, 6.2, 6.8, 8.4, 7.2)
            ..cubicTo(10.4, 7.6, 11.6, 9.6, 11.6, 11.6)
            ..cubicTo(11.6, 13.2, 10.6, 14.6, 9.2, 15)
            ..cubicTo(7.6, 15.5, 5.8, 14.8, 4.9, 13.4)
            ..cubicTo(4.4, 12.6, 4.4, 11.4, 4.4, 10.6)
            ..close(),
          _contourW,
        ),
        // Right leaflet.
        _StrokePath(
          Path()
            ..moveTo(19.6, 10.6)
            ..cubicTo(19.6, 8.4, 17.8, 6.8, 15.6, 7.2)
            ..cubicTo(13.6, 7.6, 12.4, 9.6, 12.4, 11.6)
            ..cubicTo(12.4, 13.2, 13.4, 14.6, 14.8, 15)
            ..cubicTo(16.4, 15.5, 18.2, 14.8, 19.1, 13.4)
            ..cubicTo(19.6, 12.6, 19.6, 11.4, 19.6, 10.6)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 12.4), const Offset(12, 21.4), _midribW),
        // Leaflet midribs — lighter, one each.
        _line(const Offset(12, 4.6), const Offset(12, 10.4), _lateralW),
        _line(const Offset(7.8, 8.8), const Offset(7.8, 12.6), _lateralW),
        _line(const Offset(16.2, 8.8), const Offset(16.2, 12.6), _lateralW),
      ];

  /// Palmate — five lobes, maple-ish. Curved shoulders into shallow sinuses:
  /// straight edges into deep notches made this a snowflake.
  static List<_StrokePath> _palmate() => [
        _StrokePath(
          Path()
            ..moveTo(12, 2.4)
            ..quadraticBezierTo(13.2, 6.2, 14.6, 8)
            ..quadraticBezierTo(16.6, 6.6, 18.8, 6.2)
            ..quadraticBezierTo(17.6, 9.2, 16.2, 11.2)
            ..quadraticBezierTo(18.4, 12.6, 20.2, 14.4)
            ..quadraticBezierTo(17.2, 14.9, 15, 15.3)
            ..quadraticBezierTo(14.8, 17.8, 14.2, 20)
            ..quadraticBezierTo(12.9, 17.8, 12, 16.4)
            ..quadraticBezierTo(11.1, 17.8, 9.8, 20)
            ..quadraticBezierTo(9.2, 17.8, 9, 15.3)
            ..quadraticBezierTo(6.8, 14.9, 3.8, 14.4)
            ..quadraticBezierTo(5.6, 12.6, 7.8, 11.2)
            ..quadraticBezierTo(6.4, 9.2, 5.2, 6.2)
            ..quadraticBezierTo(7.4, 6.6, 9.4, 8)
            ..quadraticBezierTo(10.8, 6.2, 12, 2.4)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 16), const Offset(12, 9.4), _midribW),
        // One rib into each side lobe, angled toward its tip.
        _line(const Offset(12, 14.2), const Offset(7.6, 12.4), _lateralW),
        _line(const Offset(12, 14.2), const Offset(16.4, 12.4), _lateralW),
      ];

  /// Capsule / closed bud. One pair of laterals (was two crossing pairs).
  static List<_StrokePath> _capsule() => [
        _StrokePath(
          Path()
            ..moveTo(12, 2.2)
            ..cubicTo(16.2, 2.2, 19.6, 6.2, 19.6, 11.2)
            ..cubicTo(19.6, 15.6, 16.8, 19.4, 13.4, 21.2)
            ..lineTo(12, 22)
            ..lineTo(10.6, 21.2)
            ..cubicTo(7.2, 19.4, 4.4, 15.6, 4.4, 11.2)
            ..cubicTo(4.4, 6.2, 7.8, 2.2, 12, 2.2)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 5), const Offset(12, 19), _midribW),
        // Single scale-pair, mid-height.
        _line(const Offset(12, 14.4), const Offset(8.8, 11.4), _lateralW),
        _line(const Offset(12, 14.4), const Offset(15.2, 11.4), _lateralW),
      ];

  /// Paired opposite leaflets on a stem. Pointed teardrops, not closed loops —
  /// as loops the pair read as spectacles.
  static List<_StrokePath> _paired() => [
        // Left leaflet — tip out at the top-left, base at the stem.
        _StrokePath(
          Path()
            ..moveTo(11.4, 10.6)
            ..cubicTo(7.6, 11, 4.2, 8.8, 3.4, 4)
            ..cubicTo(7.6, 4.6, 10.8, 6.8, 11.4, 10.6)
            ..close(),
          _contourW,
        ),
        // Right leaflet — mirrored.
        _StrokePath(
          Path()
            ..moveTo(12.6, 10.6)
            ..cubicTo(16.4, 11, 19.8, 8.8, 20.6, 4)
            ..cubicTo(16.4, 4.6, 13.2, 6.8, 12.6, 10.6)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 9.8), const Offset(12, 21.6), _midribW),
        _line(const Offset(10.6, 9.6), const Offset(5.2, 5.4), _lateralW),
        _line(const Offset(13.4, 9.6), const Offset(18.8, 5.4), _lateralW),
      ];

  /// Toothed — a blade with a serrate margin. The teeth belong on the edges
  /// of a leaf; ringed all the way round they made a gear.
  static List<_StrokePath> _toothed() => [
        _StrokePath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(14.6, 5.4)
            ..lineTo(13.7, 6.4)
            ..lineTo(16.8, 9)
            ..lineTo(15.7, 10.2)
            ..lineTo(18.6, 13.2)
            ..lineTo(17.3, 14.3)
            ..lineTo(19.4, 17.4)
            ..lineTo(12, 22)
            ..lineTo(4.6, 17.4)
            ..lineTo(6.7, 14.3)
            ..lineTo(5.4, 13.2)
            ..lineTo(8.3, 10.2)
            ..lineTo(7.2, 9)
            ..lineTo(10.3, 6.4)
            ..lineTo(9.4, 5.4)
            ..close(),
          _contourW,
        ),
        _line(const Offset(12, 4.6), const Offset(12, 20.4), _midribW),
        _line(const Offset(12, 15.4), const Offset(8, 12.2), _lateralW),
        _line(const Offset(12, 15.4), const Offset(16, 12.2), _lateralW),
      ];

  /// Spathe — a furled hood around a spadix, the way an anthurium reads.
  /// Drawn as a slim ellipse it was indistinguishable from [_lance].
  static List<_StrokePath> _spathe() => [
        _StrokePath(
          Path()
            ..moveTo(12, 2.2)
            ..cubicTo(17.4, 4.4, 20, 9.6, 18.8, 14.6)
            ..cubicTo(17.8, 18.8, 14.8, 21.8, 11.4, 22.3)
            ..cubicTo(8, 21.5, 6, 18.4, 6.2, 14.8)
            ..cubicTo(6.4, 10.2, 8.6, 5.2, 12, 2.2)
            ..close(),
          _contourW,
        ),
        // Furl: the near edge rolling back over the throat.
        _StrokePath(
          Path()
            ..moveTo(12, 5.4)
            ..cubicTo(15.2, 8, 16.4, 12.2, 15.1, 16.2),
          _lateralW,
        ),
        _line(const Offset(11.2, 9), const Offset(10.6, 19.2), _midribW),
      ];

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
/// Accepts the current [LeafShape.name] values ("oval", "lance", ...), the
/// prior six-shape names this app once wrote ("single", "sprout", ...), and
/// the original Material icon names the legacy app wrote. Anything
/// unrecognised — including whatever the original app wrote that isn't in the
/// tables — falls back to a shape derived deterministically from [code], so a
/// 30-strain library doesn't collapse onto one shape. The same code always
/// yields the same shape.
LeafShape resolveLeafShape(String stored, String code) {
  final key = stored.trim().toLowerCase();
  for (final shape in LeafShape.values) {
    if (shape.name == key) return shape;
  }
  // One-to-one: every legacy Material icon name gets its own silhouette.
  const legacy = <String, LeafShape>{
    // Original app Material icon names (exactly ten).
    'leaf': LeafShape.lance,
    'plant': LeafShape.palmate,
    'natural': LeafShape.oval,
    'organic': LeafShape.cordate,
    'flower': LeafShape.spathe,
    'herb': LeafShape.trifol,
    'forest': LeafShape.paired,
    'nature': LeafShape.toothed,
    'park': LeafShape.capsule,
    'yard': LeafShape.oblique,
    // Prior six-shape names this build used to write, so already-migrated
    // libraries keep a stable silhouette rather than falling through to the
    // code hash.
    'single': LeafShape.lance,
    'sprout': LeafShape.paired,
    'trefoil': LeafShape.trifol,
    'broad': LeafShape.oval,
    'furl': LeafShape.capsule,
    'vine': LeafShape.spathe,
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
