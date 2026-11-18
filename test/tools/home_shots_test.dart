// Dev tool, not an assertion. Boots the real app on seeded data and writes one
// PNG per Home state and theme, so the logging flow can be looked at.
//
//   flutter test test/tools/home_shots_test.dart --dart-define=SHOTS_DIR=/abs/dir
//   -> <SHOTS_DIR>/<theme>_<state>.png
//
// States: live (last dose 1h20m ago), fabmenu, sheet (Select Strain), amount
// (amount step), logged (right after a one-tap repeat, snackbar up), just
// (last dose seconds ago), empty (today has no doses yet).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

const _outDir =
    String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/home_shots');

Future<void> _loadFonts() async {
  const dir = '/home/alin/dev-sdks/flutter/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('$dir/Roboto-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  for (final entry in {
    'Hanken': [400, 500, 600, 700].map((w) => 'HankenGrotesk-$w.ttf'),
    'InstrumentSerif': [
      'InstrumentSerif-Regular.ttf',
      'InstrumentSerif-Italic.ttf',
    ],
  }.entries) {
    final l = FontLoader(entry.key);
    for (final f in entry.value) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  }
  final icons = FontLoader('MaterialIcons');
  final ib = File('$dir/MaterialIcons-Regular.otf').readAsBytesSync();
  icons.addFont(Future.value(ByteData.view(ib.buffer)));
  await icons.load();
}

enum _Today { live, just, empty, grams, dense }

Map<String, Object> _dataset({required bool dark, required _Today today}) {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final strains = [
    {
      'id': 's0',
      'name': 'Red Malay',
      'code': 'RMD',
      'color': 0xFFC62828,
      'icon': 'plant',
    },
    {
      'id': 's1',
      'name': 'Yellow Borneo',
      'code': 'YB',
      'color': 0xFFFFD54F,
      'icon': 'flower',
    },
    {
      'id': 's2',
      'name': 'White Horn',
      'code': 'WH',
      'color': 0xFF90A4AE,
      'icon': 'leaf',
    },
    {
      'id': 's3',
      'name': 'Green Balance',
      'code': 'GBG',
      'color': 0xFF43A047,
      'icon': 'natural',
    },
    {
      'id': 's4',
      'name': 'Super Red',
      'code': 'SR',
      'color': 0xFFE53935,
      'icon': 'sprout',
    },
  ];
  final doses = <Map<String, Object?>>[];
  var n = 0;
  void add(DateTime t, int s, double g, [String? note]) => doses.add({
        'id': 'd${n++}',
        'strainId': 's$s',
        'amount': g,
        'timestamp': t.toIso8601String(),
        if (note != null) 'notes': note,
      });
  // Today's doses sit relative to the real clock so the live tail is honest.
  // Before 06:00 the offsets are squeezed into the time since midnight so an
  // early-morning run still spreads them over today's page.
  final sinceMidnight = now.difference(midnight);
  const day = Duration(hours: 6);
  DateTime ago(Duration d) {
    if (sinceMidnight >= day || d < const Duration(minutes: 1)) {
      return now.subtract(d);
    }
    final scaled = d.inSeconds / day.inSeconds * sinceMidnight.inSeconds;
    return now.subtract(Duration(seconds: scaled.round()));
  }

  switch (today) {
    case _Today.live:
      add(ago(const Duration(hours: 5, minutes: 30)), 2, 16.5);
      add(ago(const Duration(hours: 2, minutes: 40)), 1, 16.3);
      add(ago(const Duration(hours: 1, minutes: 20)), 1, 16.6, 'steady');
    case _Today.just:
      add(ago(const Duration(hours: 3, minutes: 10)), 2, 16.5);
      add(ago(const Duration(seconds: 20)), 1, 16.6);
    case _Today.grams:
      add(ago(const Duration(hours: 5, minutes: 30)), 1, 12);
      add(ago(const Duration(hours: 2, minutes: 40)), 2, 16);
      add(ago(const Duration(hours: 1, minutes: 20)), 3, 22);
    case _Today.dense:
      // A heavy 7-dose day: the leaves must shrink (or drop) without
      // touching the next row.
      for (var i = 0; i < 7; i++) {
        add(ago(Duration(minutes: 20 + (6 - i) * 50)), i % 5, 12 + i * 1.5);
      }
    case _Today.empty:
      break;
  }
  for (var d = 1; d < 150; d++) {
    final day = midnight.subtract(Duration(days: d));
    if (d % 11 == 0) continue;
    final k = 2 + (d % 3);
    for (var i = 0; i < k; i++) {
      add(
        day.add(Duration(hours: 7 + i * 4, minutes: (d * 7 + i * 13) % 50)),
        (d + i) % 5,
        14 + ((d + i * 3) % 6) * 0.9,
      );
    }
  }
  return {
    'darkMode': dark,
    'strains': jsonEncode(strains),
    'dosages': jsonEncode(doses),
    'settings': jsonEncode({
      'enableNotifications': false,
      'dailyLimit': 80.0,
      'enableToleranceTracking': true,
      'toleranceBreakInterval': 14,
      'measurementUnit': 'g',
      'performanceMode': false,
    }),
    'user_name': 'Alin',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dark in [true, false]) {
    for (final today in _Today.values) {
      final theme = dark ? 'dark' : 'light';
      testWidgets('home shots $theme ${today.name}', (tester) async {
        WidgetsApp.debugAllowBannerOverride = false;
        await _loadFonts();
        SharedPreferences.setMockInitialValues(
          _dataset(dark: dark, today: today),
        );
        final prefs = await SharedPreferences.getInstance();
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: app.AppBootstrap(prefs: prefs),
          ),
        );
        await tester.pump(const Duration(seconds: 3));

        Future<void> settle() => tester.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 5),
            );

        Future<void> snap(String name) async {
          await settle();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final bytes = await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            return image.toByteData(format: ui.ImageByteFormat.png);
          });
          Directory(_outDir).createSync(recursive: true);
          File('$_outDir/${theme}_$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        }

        await snap(today.name);
        if (today != _Today.live) return;

        // FAB menu open.
        await tester.longPress(find.byKey(const Key('home-fab')));
        await snap('fabmenu');

        // One-tap repeat, if the menu offers it: the just-logged state.
        final repeat = find.byKey(const Key('home-fab-repeat-last'));
        if (repeat.evaluate().isNotEmpty) {
          await tester.tap(repeat);
          await tester.pump(const Duration(milliseconds: 300));
          await snap('logged');
          final undo = find.text('Undo');
          if (undo.evaluate().isNotEmpty) {
            await tester.tap(undo.first);
            await settle();
          }
          // Let the snackbar leave before the sheet opens.
          await tester.pump(const Duration(seconds: 6));
          await settle();
        } else {
          await tester.tapAt(const Offset(40, 400));
          await settle();
        }

        // Select Strain sheet, then the amount step.
        await tester.tap(find.byKey(const Key('home-fab')));
        await snap('sheet');
        await tester.tap(find.text('GBG').last);
        await snap('amount');
      });
    }
  }
}
