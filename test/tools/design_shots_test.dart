// Dev tool, not an assertion. Boots the real app on a seeded dataset and
// writes one PNG per tab and theme.
//
//   flutter test test/tools/design_shots_test.dart --dart-define=SHOTS_DIR=/abs/dir
//   -> <SHOTS_DIR>/<theme>_<surface>.png
//
// Also: privacy, terms (pushed from Manage).
//
// --dart-define=TEXT_SCALE=1.3 boots at that system font scale and, instead of
// failing on the first layout overflow, prints every one at the end.
// Surfaces are reached by stable keys first (`strains-add`,
// `strain-details-edit`, `stats-history`) and fall back to visible text, so a
// redesign that keeps the keys keeps the harness working.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

const _outDir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots');
final _textScale =
    double.parse(const String.fromEnvironment('TEXT_SCALE', defaultValue: '1'));

Future<void> _loadRoboto() async {
  const dir = '/home/alin/dev-sdks/flutter/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('$dir/Roboto-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  for (final entry in {
    'Hanken': [400, 500, 600, 700].map((w) => 'HankenGrotesk-$w.ttf'),
    'InstrumentSerif': ['InstrumentSerif-Regular.ttf', 'InstrumentSerif-Italic.ttf'],
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

Map<String, Object> _dataset({required bool dark}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final strains = [
    {'id': 's0', 'name': 'Red Malay', 'code': 'RMD', 'color': 0xFFC62828, 'icon': 'plant'},
    {'id': 's1', 'name': 'Yellow Borneo', 'code': 'YB', 'color': 0xFFFFD54F, 'icon': 'flower'},
    {'id': 's2', 'name': 'White Horn', 'code': 'WH', 'color': 0xFF90A4AE, 'icon': 'leaf'},
    // Out of stock: the exception case every list must show quietly.
    {'id': 's3', 'name': 'Green Balance', 'code': 'GBG', 'color': 0xFF43A047, 'icon': 'natural', 'inStock': false},
    {'id': 's4', 'name': 'Super Red', 'code': 'SR', 'color': 0xFFE53935, 'icon': 'sprout'},
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
  // Today: three doses already behind now.
  add(today.add(const Duration(hours: 7, minutes: 32)), 2, 16.5);
  add(today.add(const Duration(hours: 10, minutes: 40)), 1, 16.3);
  add(today.add(const Duration(hours: 12, minutes: 5)), 1, 16.6, 'steady');
  for (var d = 1; d < 150; d++) {
    final day = today.subtract(Duration(days: d));
    if (d % 11 == 0) continue;
    final k = 2 + (d % 3);
    for (var i = 0; i < k; i++) {
      add(day.add(Duration(hours: 7 + i * 4, minutes: (d * 7 + i * 13) % 50)),
          (d + i) % 5, 14 + ((d + i * 3) % 6) * 0.9,);
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

Future<GlobalKey> _boot(
  WidgetTester tester,
  Map<String, Object> values,
) async {
  WidgetsApp.debugAllowBannerOverride = false;
  await _loadRoboto();
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  if (_textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = _textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (!text.contains('overflowed')) return previous?.call(details);
      final full = details.toString().split('\n');
      final i = full.indexWhere((l) => l.contains('relevant error-causing'));
      final where =
          i < 0 ? '' : full.skip(i + 1).take(2).map((l) => l.trim()).join(' ');
      overflows.add('${text.split('\n').first} | $where');
    };
    addTearDown(() {
      FlutterError.onError = previous;
      // ignore: avoid_print
      print('OVERFLOWS@$_textScale (${overflows.length}):\n'
          '${overflows.toSet().join('\n')}');
    });
  }
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: app.AppBootstrap(prefs: prefs),
  ),);
  await tester.pump(const Duration(seconds: 3));
  await _settle(tester);
  return key;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

Future<void> Function(String) _snapper(
  WidgetTester tester,
  GlobalKey key,
  bool dark,
) =>
    (name) async {
      await _settle(tester);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      Directory(_outDir).createSync(recursive: true);
      File('$_outDir/${dark ? 'dark' : 'light'}_$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    };

/// Taps the first finder that matches, scrolling it into view first.
Future<void> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final f in finders) {
    if (f.evaluate().isNotEmpty) {
      await tester.ensureVisible(f.first);
      await _settle(tester);
      await tester.tap(f.first, warnIfMissed: false);
      await _settle(tester);
      return;
    }
  }
  throw StateError('none of $finders found');
}

/// Pops the top route (sheet, dialog or pushed page) on the root navigator.
Future<void> _popTop(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await _settle(tester);
}

/// Scrolls the primary scrollable of the current tab to its end.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable).hitTestable();
  if (scrollables.evaluate().isEmpty) return;
  final state = tester.state<ScrollableState>(scrollables.first);
  state.position.jumpTo(state.position.maxScrollExtent);
  await _settle(tester);
}

Future<void> _scrollToStart(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable).hitTestable();
  if (scrollables.evaluate().isEmpty) return;
  final state = tester.state<ScrollableState>(scrollables.first);
  state.position.jumpTo(0);
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dark in [true, false]) {
    testWidgets('shots ${dark ? 'dark' : 'light'}', (tester) async {
      final key = await _boot(tester, _dataset(dark: dark));
      final snap = _snapper(tester, key, dark);

      await snap('home');

      // Strains: list, details, edit form, add form.
      await tester.tap(find.text('Strains'));
      await snap('strains');
      await _tapAny(tester, [find.text('Red Malay')]);
      await snap('strain_details');
      await _tapAny(tester, [
        find.byKey(const Key('strain-details-edit')),
        find.byIcon(Icons.edit_outlined),
      ]);
      await snap('strain_edit');
      await _popTop(tester);
      await _tapAny(tester, [
        find.byKey(const Key('strains-add')),
        find.text('Add Strain'),
      ]);
      await snap('strain_add');
      await _popTop(tester);

      // Stats: top, the rest of the page, and the report behind it.
      await tester.tap(find.text('Stats'));
      await snap('stats');
      await _scrollToEnd(tester);
      await snap('stats2');
      await _tapAny(tester, [
        find.byKey(const Key('stats-history')),
        find.text('Dosage history'),
      ]);
      await snap('report');
      await _popTop(tester);
      await _scrollToStart(tester);

      // Manage: top, bottom, profile sheet.
      await tester.tap(find.text('Manage'));
      await snap('manage');
      await _scrollToEnd(tester);
      await snap('manage2');
      await _tapAny(tester,
          [find.text('Privacy policy'), find.text('Privacy Policy')],);
      await snap('privacy');
      await _popTop(tester);
      await _tapAny(tester,
          [find.text('Terms of service'), find.text('Terms of Service')],);
      await snap('terms');
      await _popTop(tester);
      await _scrollToStart(tester);
      await _tapAny(tester, [find.text('Profile')]);
      await snap('profile');
      await _popTop(tester);

      await tester.tap(find.text('Home'));
      await snap('home2');
      // Yesterday: the past-day headline (total, not elapsed).
      final y = DateTime.now().subtract(const Duration(days: 1));
      await tester.tap(
        find.byKey(ValueKey('home-day-bar-${y.year}-${y.month}-${y.day}')),
      );
      await snap('home_past');
      await tester.tap(find.text('Today'));
      // Add-dose sheet.
      await tester.tap(find.byKey(const Key('home-fab')));
      await snap('adddose');
    });

    // First run: no strains, no doses, no name. Each tab must say what will
    // appear and offer one next action.
    testWidgets('shots ${dark ? 'dark' : 'light'} empty', (tester) async {
      final key = await _boot(tester, {
        'darkMode': dark,
        'strains': '[]',
        'dosages': '[]',
      });
      final snap = _snapper(tester, key, dark);
      await tester.tap(find.text('Strains'));
      await snap('empty_strains');
      await tester.tap(find.text('Stats'));
      await snap('empty_stats');
    });
  }
}
