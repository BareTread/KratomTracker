// Dev tool, not an assertion. Renders the day-sprig glyph on its own, a sheet
// of test days at herbarium and week-strip size, in both themes.
//
//   flutter test test/tools/sprig_shots_test.dart --dart-define=SHOTS_DIR=/abs/dir
//   -> <SHOTS_DIR>/<theme>_sprig_sheet.png

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kratom_tracker_plus/domain/date_utils.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_calendar_section.dart';
import 'package:kratom_tracker_plus/screens/stats/stats_bundle.dart';
import 'package:kratom_tracker_plus/screens/stats/stats_herbarium.dart';
import 'package:kratom_tracker_plus/screens/stats_screen.dart';
import 'package:kratom_tracker_plus/theme/app_theme.dart';
import 'package:kratom_tracker_plus/widgets/day_sprig.dart';

const _outDir =
    String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots');

Future<void> _loadFonts() async {
  final hanken = FontLoader('Hanken');
  for (final w in [400, 500, 600, 700]) {
    final b = File('assets/fonts/HankenGrotesk-$w.ttf').readAsBytesSync();
    hanken.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await hanken.load();
  final serif = FontLoader('InstrumentSerif');
  for (final f in ['Regular', 'Italic']) {
    final b = File('assets/fonts/InstrumentSerif-$f.ttf').readAsBytesSync();
    serif.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await serif.load();
  final icons = FontLoader('MaterialIcons');
  final ib = File(
    '/home/alin/dev-sdks/flutter/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  icons.addFont(Future.value(ByteData.view(ib.buffer)));
  await icons.load();
}

const _red = Color(0xFFC62828);
const _yellow = Color(0xFFFFD54F);
const _grey = Color(0xFF90A4AE);
const _green = Color(0xFF43A047);
const _white = Color(0xFFF5F5F0);

SprigDose _d(int h, int m, double g, Color c) =>
    SprigDose(time: DateTime(2026, 11, 16, h, m), grams: g, color: c);

/// (caption, doses). The scale is shared across the whole sheet.
final _days = <(String, List<SprigDose>)>[
  ('rest', const []),
  ('1 dose', [_d(9, 10, 6, _green)]),
  (
    '3 doses',
    [_d(8, 0, 5, _red), _d(13, 30, 5.5, _yellow), _d(19, 15, 6, _grey)]
  ),
  (
    '7 doses',
    [
      _d(6, 40, 4, _red),
      _d(9, 0, 4.5, _yellow),
      _d(11, 20, 5, _red),
      _d(13, 50, 4, _grey),
      _d(16, 10, 5, _yellow),
      _d(19, 0, 4.5, _red),
      _d(22, 30, 3.5, _grey),
    ],
  ),
  ('20 min apart', [_d(10, 0, 5, _red), _d(10, 20, 5, _yellow)]),
  (
    '3 in 40 min',
    [_d(10, 0, 5, _red), _d(10, 20, 5, _yellow), _d(10, 40, 5, _grey)]
  ),
  ('12 g', [_d(9, 0, 6, _green), _d(17, 0, 6, _green)]),
  ('16 g', [_d(9, 0, 8, _green), _d(17, 0, 8, _green)]),
  ('22 g', [_d(9, 0, 11, _green), _d(17, 0, 11, _green)]),
  (
    'yellow',
    [_d(8, 0, 9, _yellow), _d(14, 0, 9, _yellow), _d(20, 0, 9, _yellow)]
  ),
  ('white', [_d(8, 0, 9, _white), _d(14, 0, 9, _white), _d(20, 0, 9, _white)]),
  ('pinch', [_d(9, 0, 0.5, _red), _d(15, 0, 11, _red)]),
  ('night', [_d(0, 30, 6, _grey), _d(23, 40, 6, _grey)]),
  ('today', const []),
];

Widget _sheet(Size size, double gap) {
  final scale = sprigScaleFor(_days.map((d) => d.$2));
  return Builder(
    builder: (context) => Wrap(
      spacing: gap,
      runSpacing: 10,
      children: [
        for (final (caption, doses) in _days)
          SizedBox(
            width: size.width + 34,
            child: Column(
              children: [
                DaySprig(
                  doses: doses,
                  scaleGrams: scale,
                  rest: caption != 'today',
                  surface: context.c.surfaceRaised,
                  size: size,
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(
                    fontFamily: AppType.sans,
                    fontSize: 10,
                    color: context.c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Five months of a realistic rhythm: 2-5 doses a day of the five strains the
/// design shots use, a rest day every 11th day, one heavy day, one day with two
/// doses 20 minutes apart.
Future<KratomProvider> _provider() async {
  final today = startOfDay(DateTime.now());
  const strains = [
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
  void add(DateTime t, int s, double g) => doses.add({
        'id': 'd${n++}',
        'strainId': 's$s',
        'amount': g,
        'timestamp': t.toIso8601String(),
      });
  add(today.add(const Duration(hours: 7, minutes: 32)), 2, 16.5);
  add(today.add(const Duration(hours: 10, minutes: 40)), 1, 16.3);
  for (var d = 1; d < 150; d++) {
    final day = addDays(today, -d);
    if (d % 11 == 0) continue;
    if (d == 9) {
      for (final (h, m, s, g) in [
        (6, 50, 0, 18.0),
        (9, 30, 1, 21.5),
        (12, 10, 4, 19.0),
        (15, 0, 0, 22.0),
        (18, 20, 2, 17.5),
        (21, 45, 1, 20.0),
      ]) {
        add(day.add(Duration(hours: h, minutes: m)), s, g);
      }
      continue;
    }
    if (d == 5) {
      add(day.add(const Duration(hours: 8)), 3, 15);
      add(day.add(const Duration(hours: 8, minutes: 20)), 1, 15);
      add(day.add(const Duration(hours: 17)), 0, 15);
      continue;
    }
    final k = 2 + (d % 3);
    for (var i = 0; i < k; i++) {
      add(
        day.add(Duration(hours: 7 + i * 4, minutes: (d * 7 + i * 13) % 50)),
        (d + i) % 5,
        14 + ((d + i * 3) % 6) * 0.9,
      );
    }
  }
  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode(strains),
    'dosages': jsonEncode(doses),
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required bool dark,
  required Size logical,
  required Widget Function(BuildContext) body,
  KratomProvider? provider,
}) async {
  await _loadFonts();
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final key = GlobalKey();
  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? ThemeProvider.darkTheme : ThemeProvider.lightTheme,
    home: RepaintBoundary(
      key: key,
      child: Builder(
        builder: (context) => Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: body(context),
        ),
      ),
    ),
  );
  if (provider != null) {
    app = ChangeNotifierProvider<KratomProvider>.value(
      value: provider,
      child: app,
    );
  }
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  Directory(_outDir).createSync(recursive: true);
  File('$_outDir/${dark ? 'dark' : 'light'}_$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('sprig sheet $theme', (tester) async {
      await _shoot(
        tester,
        name: 'sprig_sheet',
        dark: dark,
        logical: const Size(800, 330),
        body: (context) => Container(
          color: context.c.surfaceRaised,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheet(const Size(40, 90), 0),
              const SizedBox(height: 16),
              _sheet(const Size(20, 28), 0),
            ],
          ),
        ),
      );
    });

    testWidgets('herbarium $theme', (tester) async {
      final provider = await _provider();
      final bundle = StatsBundle.compute(provider, StatsRange.thirty);
      await _shoot(
        tester,
        name: 'herbarium',
        dark: dark,
        provider: provider,
        logical: const Size(393, 640),
        body: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: StatsHerbarium(bundle: bundle),
        ),
      );
    });

    testWidgets('week strip $theme', (tester) async {
      final provider = await _provider();
      await _shoot(
        tester,
        name: 'week_strip',
        dark: dark,
        provider: provider,
        logical: const Size(393, 170),
        body: (context) => Padding(
          padding: const EdgeInsets.all(12),
          child: HomeCalendarSection(
            focusedDay: startOfDay(DateTime.now()),
            onDaySelected: (_) {},
            totalForDate: provider.totalForDate,
          ),
        ),
      );
    });

    testWidgets('stats screen $theme', (tester) async {
      final provider = await _provider();
      await _shoot(
        tester,
        name: 'stats',
        dark: dark,
        provider: provider,
        logical: const Size(393, 1400),
        body: (context) => const StatsScreen(),
      );
    });
  }
}
