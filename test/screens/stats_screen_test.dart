import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/date_utils.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/stats/stats_headline.dart';
import 'package:kratom_tracker_plus/screens/stats_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(KratomProvider provider) {
  return ChangeNotifierProvider<KratomProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: ThemeProvider.darkTheme,
      home: const Scaffold(body: StatsScreen()),
    ),
  );
}

/// Seeded through mock preferences rather than [KratomProvider.addDosage] —
/// a month of realistic history is 120 doses, and the page only says anything
/// interesting once it has that much.
Future<KratomProvider> _provider(List<Map<String, dynamic>> dosages) async {
  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode([
      {
        'id': 'strain-1',
        'name': 'Maeng Da',
        'code': 'MD',
        'color': 0xFF00ACC1,
        'icon': 'Leaf',
      },
      {
        'id': 'strain-2',
        'name': 'Bali',
        'code': 'BALI',
        'color': 0xFFB388FF,
        'icon': 'Leaf',
      },
    ]),
    'dosages': jsonEncode(dosages),
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

/// [perDay] doses of [size] on each of the days [from]..[to] days ago. Today
/// is never seeded: an unfinished today is excluded from closed-day metrics,
/// so leaving it empty keeps every expectation below independent of the hour
/// the suite happens to run at.
List<Map<String, dynamic>> _days({
  required int from,
  required int to,
  required int Function(int daysAgo) perDay,
  double size = 2.5,
  String strainId = 'strain-1',
}) {
  final today = startOfDay(DateTime.now());
  final result = <Map<String, dynamic>>[];
  for (var daysAgo = from; daysAgo <= to; daysAgo++) {
    final day = addDays(today, -daysAgo);
    for (var n = 0; n < perDay(daysAgo); n++) {
      result.add({
        'id': '$strainId-$daysAgo-$n',
        'strainId': strainId,
        'amount': size,
        'timestamp':
            DateTime(day.year, day.month, day.day, 8 + n * 3).toIso8601String(),
      });
    }
  }
  return result;
}

void main() {
  testWidgets('a fresh install says so and nothing else', (tester) async {
    await tester.pumpWidget(_harness(await _provider(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.text('Dosage history'), findsOneWidget);
    // No section survives an empty install — there is nothing to say.
    expect(find.text('When'), findsNothing);
    expect(find.text('Rotation'), findsNothing);
    expect(find.text('Rest'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('a handful of doses refuses to call a trend', (tester) async {
    final provider = await _provider(
      _days(from: 2, to: 4, perDay: (_) => 1),
    );
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(find.text('Not enough history yet'), findsOneWidget);
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('a flat month reads as steady and decomposes into F and A',
      (tester) async {
    final provider = await _provider(
      _days(from: 1, to: 40, perDay: (_) => 4),
    );
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(find.text('Holding steady around 10g/day'), findsOneWidget);
    // G = F × A, laid out as the equation it is. Scoped to the equation:
    // the Totals section further down restates several of these figures, so
    // a bare find.text would match twice and say nothing about the headline.
    Finder inEquation(String text) => find.descendant(
          of: find.byType(IntakeEquation),
          matching: find.text(text),
        );
    expect(inEquation('10'), findsOneWidget);
    expect(inEquation('4'), findsOneWidget);
    expect(inEquation('2.5'), findsOneWidget);
    expect(find.text('grams a day'), findsOneWidget);
    expect(find.text('doses a day'), findsOneWidget);
    expect(find.text('grams a dose'), findsOneWidget);

    expect(find.text('When'), findsOneWidget);
    expect(find.text('Rotation'), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);
  });

  testWidgets('a rise says which factor carried it', (tester) async {
    // Same 2.5g dose throughout; only the count climbs.
    final provider = await _provider(
      _days(from: 1, to: 29, perDay: (daysAgo) => 3 + (29 - daysAgo) ~/ 10),
    );
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(find.text('More doses, not bigger ones.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').startsWith('Up ') &&
            widget.data!.contains('over the last 30 days'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the range picker changes what the headline is about',
      (tester) async {
    // Three months walking up from 5g a day to 10g. The last month is flat,
    // so 30d has nothing to report and All has a climb.
    final provider = await _provider(
      _days(
        from: 1,
        to: 89,
        perDay: (daysAgo) => daysAgo <= 29 ? 4 : (daysAgo <= 59 ? 3 : 2),
      ),
    );
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(find.text('Holding steady around 10g/day'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Holding steady around 10g/day'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').startsWith('Up ') &&
            widget.data!.contains('across your whole history'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('rest days and streaks are kept, in one line', (tester) async {
    // 29 closed days: two of them rested, the last three consecutive.
    final provider = await _provider(
      _days(
        from: 1,
        to: 29,
        perDay: (daysAgo) => (daysAgo == 4 || daysAgo == 5) ? 0 : 4,
      ),
    );
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(
      find.text('2 rest days in 29 · on a 3-day run · longest rest 2 days'),
      findsOneWidget,
    );
  });

  testWidgets('one strain carrying the month is called out', (tester) async {
    final provider = await _provider([
      ..._days(from: 1, to: 29, perDay: (_) => 4),
      ..._days(from: 1, to: 29, perDay: (_) => 1, strainId: 'strain-2'),
    ]);
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(find.text('MD'), findsOneWidget);
    expect(find.text('BALI'), findsOneWidget);
    expect(
      find.text('MD is 80% of everything here — that is leaning, '
          'not rotating.'),
      findsOneWidget,
    );
  });
}
