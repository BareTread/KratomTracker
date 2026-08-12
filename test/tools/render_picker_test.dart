// Scratch dev tool. Renders the strain picker list against a realistic shelf
// so a human can check the row rhythm and the load bar.
//
//   flutter test test/tools/render_picker_test.dart
//   -> build/strain_picker.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/strain_usage.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/strain_usage_tile.dart';

const _width = 411.0;
const _height = 900.0;

// A shelf shaped like the real one: a few workhorses, a long tail, mixed
// colours, one strain never touched.
const _shelf = [
  ('RBaK', 'Red Bali Kratom', 0xFFE05252, 7, 5),
  ('RMDG', 'Red Maeng Da Grüneshaus.com', 0xFFE05252, 5, 12),
  ('RBoK', 'Red Borneo Kratom', 0xFFC94F4F, 4, 2),
  ('yy', 'yellow yarrow', 0xFFD9A441, 2, 1),
  ('PR', 'Pure Red', 0xFFE05252, 0, 9),
  ('GMDP', 'Green Maeng Da Plantation', 0xFF4CAF6A, 7, 14),
  ('RBI', 'Red Borneo Indo', 0xFFC94F4F, 2, 3),
  ('WMDP', 'White Maeng Da Plantation', 0xFFBFC7CC, 4, 6),
  ('GBK', 'Green Bali Kratom', 0xFF4CAF6A, 1, 4),
  ('GLMD', 'Gold Maeng Da', 0xFFD9A441, 1, 8),
  ('WBK', 'White Bali Kratom', 0xFFBFC7CC, 21, 0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render the strain picker', (tester) async {
    final now = DateTime(2026, 8, 12, 21);
    final strains = <Strain>[];
    final dosages = <Dosage>[];
    for (var i = 0; i < _shelf.length; i++) {
      final (code, name, color, daysAgo, doses) = _shelf[i];
      final id = 's$i';
      strains.add(
        Strain(id: id, name: name, code: code, color: color, icon: 'Leaf'),
      );
      // The most recent dose sets recency; the rest spread back through the
      // month so grams30d varies the way a real rotation does.
      for (var d = 0; d < doses; d++) {
        dosages.add(
          Dosage(
            id: '$id-$d',
            strainId: id,
            amount: 2.5 + (d % 3) * 0.5,
            timestamp: now.subtract(Duration(days: daysAgo + d * 2, hours: 3)),
          ),
        );
      }
    }

    final usage = computeStrainUsage(strains, dosages, now: now);

    tester.view.physicalSize = const Size(_width, _height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeProvider.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: _width,
              height: _height,
              color: const Color(0xFF090B0C),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  for (final item in usage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: StrainUsageTile(usage: item, onTap: () {}),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory('build').createSync(recursive: true);
    File('build/strain_picker.png').writeAsBytesSync(
      bytes!.buffer.asUint8List(),
    );

    // Print the ranking so the ordering can be checked against the picture.
    for (final item in usage) {
      debugPrint(
        '${item.rank}  ${item.strain.code.padRight(5)} '
        '${item.daysSinceLastUse.toStringAsFixed(0).padLeft(3)}d  '
        '${item.grams30d.toStringAsFixed(1).padLeft(6)}g  '
        'conc ${item.concentration.toStringAsFixed(2)}  '
        'score ${item.rotationScore.toStringAsFixed(2)}',
      );
    }
  });
}
