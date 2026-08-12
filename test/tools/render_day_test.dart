// Dev tool, not an assertion. Renders 1-, 2- and 3-dose today compositions
// side by side so a human can check the vertical rhythm.
//
//   flutter test test/tools/render_day_test.dart
//   -> build/day_rhythm.png

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

const _listWidth = 369.0;
const _listHeight = 540.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render 1/2/3-dose day rhythms', (tester) async {
    final shots = <ui.Image>[];
    for (final count in [1, 2, 3]) {
      shots.add(await _shoot(tester, count));
    }

    const pad = 12.0;
    final width = pad + (_listWidth + pad) * shots.length;
    const height = pad * 2 + _listHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF090B0C),
    );
    for (var i = 0; i < shots.length; i++) {
      final x = pad + i * (_listWidth + pad);
      canvas.drawImage(shots[i], Offset(x, pad), Paint());
      canvas.drawRect(
        Rect.fromLTWH(x, pad, _listWidth, _listHeight),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF1B2124),
      );
    }

    final picture = recorder.endRecording();
    // Rasterising has to happen outside the fake-async zone or the futures
    // never complete and the test hangs.
    final bytes = await tester.runAsync(() async {
      final image = await picture.toImage(width.round(), height.round());
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory('build').createSync(recursive: true);
    File('build/day_rhythm.png').writeAsBytesSync(
      bytes!.buffer.asUint8List(),
    );
  });
}

Future<ui.Image> _shoot(WidgetTester tester, int count) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  // Spread the doses across the morning; the last one is hours back so the
  // live strip carries a realistic amount of elapsed time.
  final entries = [
    for (var i = 0; i < count; i++)
      {
        'id': 'd$i',
        'strainId': 'strain-1',
        'amount': 16.0 + i,
        'timestamp': day.add(Duration(hours: i * 3)).toIso8601String(),
      },
  ];

  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode([
      {
        'id': 'strain-1',
        'name': 'Test Strain',
        'code': 'TEST',
        'color': 0xFF00ACC1,
        'icon': 'Leaf',
      },
    ]),
    'dosages': jsonEncode(entries),
  });
  final provider = await KratomProvider.create(
    await SharedPreferences.getInstance(),
  );
  final strains = <String, Strain>{for (final s in provider.strains) s.id: s};

  tester.view.physicalSize = const Size(_listWidth, _listHeight + 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
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
            key: key,
            child: SizedBox(
              width: _listWidth,
              height: _listHeight,
              child: HomeDosageList(
                dosages: List<Dosage>.unmodifiable(provider.dosages),
                strainsById: strains,
                isToday: true,
                header: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(boundary.toImage))!;
}
