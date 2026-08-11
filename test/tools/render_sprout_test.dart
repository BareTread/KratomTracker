// Dev tool, not an assertion. Renders the empty-day sprout cycle as a
// filmstrip so a human can check the choreography.
//
//   flutter test test/tools/render_sprout_test.dart
//   -> build/sprout_preview.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/widgets/vine_painter.dart';

void main() {
  test('render empty-day sprout filmstrip', () async {
    const band = 72.0;
    const frames = 12;
    const pad = 16.0;
    const accent = Color(0xFF00ACC1);

    final width = pad * 2 + frames * band;
    const height = pad * 2 + band + 20;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF090B0C),
    );

    for (var f = 0; f < frames; f++) {
      final t = f / frames;
      final x = pad + f * band;

      canvas.drawRect(
        Rect.fromLTWH(x, pad, band, band),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF1B2124),
      );

      canvas.save();
      canvas.translate(x, pad);
      VineNowStemPainter(
        xOffset: VineGeometry.offsetFor(0),
        fromColor: accent,
        tipColor: accent,
        hasPrior: false,
        live: true,
        dashOffset: -VineGeometry.liveDashTravel * t,
        liveColor: accent,
        sproutPhase: t,
      ).paint(canvas, const Size(band, band));
      canvas.restore();

      final tp = TextPainter(
        text: TextSpan(
          text: t.toStringAsFixed(2),
          style: const TextStyle(color: Color(0xFF7B878E), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 4, pad + band + 4));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    final out = File('build/sprout_preview.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    expect(await out.exists(), isTrue);
  });
}
