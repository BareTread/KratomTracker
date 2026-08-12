// Scratch dev tool. Renders the stats page against 18 months of realistic
// history so a human can check density and legibility.
//
//   flutter test test/tools/render_stats_test.dart
//   -> build/stats_30d.png, build/stats_all.png

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/insights_service.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/stats_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _width = 411.0;
const _height = 1500.0;

const _shelf = [
  ('RBaK', 'Red Bali Kratom', 0xFFE05252),
  ('RMDG', 'Red Maeng Da', 0xFFE05252),
  ('RBoK', 'Red Borneo Kratom', 0xFFC94F4F),
  ('yy', 'yellow yarrow', 0xFFD9A441),
  ('PR', 'Pure Red', 0xFFE05252),
  ('GMDP', 'Green Maeng Da Plantation', 0xFF4CAF6A),
  ('RBI', 'Red Borneo Indo', 0xFFC94F4F),
  ('WMDP', 'White Maeng Da Plantation', 0xFFBFC7CC),
  ('GBK', 'Green Bali Kratom', 0xFF4CAF6A),
  ('GLMD', 'Gold Maeng Da', 0xFFD9A441),
  ('WBK', 'White Bali Kratom', 0xFFBFC7CC),
  ('RTh', 'Red Thai', 0xFFC94F4F),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render the stats page', (tester) async {
    for (final tab in ['30d', 'All']) {
      await _shoot(tester, tab);
    }
  });
}

Future<void> _shoot(WidgetTester tester, String tab) async {
  final rng = Random(7);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final strains = [
    for (var i = 0; i < _shelf.length; i++)
      {
        'id': 's$i',
        'name': _shelf[i].$2,
        'code': _shelf[i].$1,
        'color': _shelf[i].$3,
        'icon': 'Leaf',
      },
  ];

  // 18 months, 4-6 doses a day, a slow upward drift, occasional rest days,
  // and a rotation that leans hard on three strains.
  final dosages = <Map<String, Object>>[];
  var id = 0;
  for (var back = 550; back >= 0; back--) {
    final day = today.subtract(Duration(days: back));
    if (rng.nextDouble() < 0.06) continue; // a rest day
    final drift = 1.0 + (550 - back) / 550 * 0.35;
    final count = 4 + rng.nextInt(3);
    for (var d = 0; d < count; d++) {
      // Three workhorses take two thirds of the doses.
      final pick = rng.nextDouble() < 0.66
          ? rng.nextInt(3)
          : 3 + rng.nextInt(_shelf.length - 3);
      dosages.add({
        'id': 'd${id++}',
        'strainId': 's$pick',
        'amount':
            ((2.0 + rng.nextDouble() * 1.4) * drift * 10).roundToDouble() / 10,
        'timestamp': day
            .add(Duration(hours: 7 + d * 3, minutes: rng.nextInt(50)))
            .toIso8601String(),
      });
    }
  }

  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode(strains),
    'dosages': jsonEncode(dosages),
  });
  final provider = await KratomProvider.create(
    await SharedPreferences.getInstance(),
  );

  if (tab == '30d') {
    final all = provider.dosages;
    final gap = computeGapCompression(all, now: now);
    final cycle = computeReturnCycle(all, now: now);
    final breadth = computeRotationBreadth(all, now: now);
    final first = computeFirstDoseDrift(all, now: now);
    debugPrint(
        'GAP      ${gap == null ? "silent" : "${gap.recent} vs ${gap.previous} "
            "delta ${gap.delta} material=${gap.isMaterial}"}');
    debugPrint('CYCLE    ${cycle == null ? "silent" : "${cycle.median} over "
        "${cycle.events} returns across ${cycle.strains} strains, "
        "delta ${cycle.delta} material=${cycle.isMaterial}"}');
    debugPrint(
        'BREADTH  ${breadth == null ? "silent" : "${breadth.observed} observed, "
            "effective ${breadth.effective.toStringAsFixed(2)}, narrow=${breadth.isNarrow}"}');
    debugPrint(
        'FIRST    ${first == null ? "silent" : "${first.recentMinute} vs "
            "${first.previousMinute} delta ${first.deltaMinutes}m "
            "material=${first.isMaterial}"}');
  }

  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
  await tester.pumpWidget(
    ChangeNotifierProvider<KratomProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: RepaintBoundary(
          key: key,
          child: const Scaffold(body: StatsScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (tab != '30d') {
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  Directory('build').createSync(recursive: true);
  File('build/stats_${tab.toLowerCase()}.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}
