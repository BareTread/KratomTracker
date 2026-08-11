// Dev tool, not an assertion. Renders the leaf mark set to a PNG so a human
// can look at it before the shapes get wired into the app.
//
//   flutter test test/tools/render_marks_test.dart
//   -> build/marks_preview.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/widgets/strain_mark.dart';

const veins = <String, Color>{
  'red': Color(0xFFE53935),
  'green': Color(0xFF43A047),
  'white': Color(0xFFB0BEC5),
  'yellow': Color(0xFFFDD835),
  'gold': Color(0xFFFB8C00),
};

void main() {
  test('render leaf mark preview sheet', () async {
    const tile = 52.0;
    const gap = 10.0;
    const pad = 32.0;
    const glyph = 40.0; // the size the timeline actually paints

    final cols = LeafShape.values.length;
    final rows = veins.length;
    final width = pad * 2 + cols * tile + (cols - 1) * gap;
    final height = pad * 2 + 40 + rows * tile + (rows - 1) * gap;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF090B0C),
    );

    void label(String text, double x, double y, {double size = 13}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: const Color(0xFF7B878E), fontSize: size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }

    for (var c = 0; c < cols; c++) {
      label(LeafShape.values[c].label, pad + c * (tile + gap), pad);
    }

    var r = 0;
    for (final entry in veins.entries) {
      final y = pad + 40 + r * (tile + gap);
      for (var c = 0; c < cols; c++) {
        final x = pad + c * (tile + gap);
        final colour = entry.value;

        // Timeline context: bare mark on near-black, plus a 1px frame so the
        // fit inside the box is provable.
        canvas.drawRect(
          Rect.fromLTWH(x, y, tile, tile),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF1B2124),
        );

        canvas.save();
        canvas.translate(x + (tile - glyph) / 2, y + (tile - glyph) / 2);
        LeafMarkPainter(shape: LeafShape.values[c], color: colour)
            .paint(canvas, const Size(glyph, glyph));
        canvas.restore();
      }
      label(entry.key, 4, y + tile / 2 - 8, size: 11);
      r++;
    }

    // A small-size row: this is the size that actually matters.
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    final out = File('build/marks_preview.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    expect(await out.exists(), isTrue);
  });
}
