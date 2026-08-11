// Dev tool, not an assertion. Renders the home dose timeline to a PNG so a
// human can look at the composition before it goes on a device.
//
//   flutter test test/tools/render_home_test.dart
//   -> build/home_preview.png

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_dosage_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('render home timeline preview', (tester) async {
    const size = Size(369, 620);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final day = DateTime(2026, 8, 11);
    final strains = [
      {
        'id': 's1',
        'name': 'Green Malay',
        'code': 'GLMD',
        'color': 0xFFFFB300,
        'icon': 'Leaf',
      },
      {
        'id': 's2',
        'name': 'White Borneo',
        'code': 'WB',
        'color': 0xFFB0BEC5,
        'icon': 'Plant',
      },
      {
        'id': 's3',
        'name': 'Green Bali',
        'code': 'GBK',
        'color': 0xFF66BB6A,
        'icon': 'Flower',
      },
      {
        'id': 's4',
        'name': 'Red Maeng Da',
        'code': 'RMDP',
        'color': 0xFFE53935,
        'icon': 'Herb',
      },
    ];
    Map<String, Object?> dose(String id, String strain, double amount, int h,
            int m) =>
        {
          'id': id,
          'strainId': strain,
          'amount': amount,
          'timestamp':
              day.add(Duration(hours: h, minutes: m)).toIso8601String(),
        };

    SharedPreferences.setMockInitialValues({
      'strains': jsonEncode(strains),
      'dosages': jsonEncode([
        dose('d1', 's1', 16.5, 10, 35),
        dose('d2', 's2', 16.36, 13, 59),
        dose('d3', 's3', 16.5, 18, 4),
        dose('d4', 's4', 16.51, 20, 10),
      ]),
      'effects': '[]',
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: HomeDosageList(
                  dosages: List<Dosage>.unmodifiable(provider.dosages),
                  strainsById: <String, Strain>{
                    for (final s in provider.strains) s.id: s,
                  },
                  isToday: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/home_preview.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    expect(await out.exists(), isTrue);
  });
}
