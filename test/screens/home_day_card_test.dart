import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_calendar_section.dart';
import 'package:kratom_tracker_plus/screens/home/home_day_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('per-day presence dots mark days with doses',
      (tester) async {
    // Wednesday 12 Feb 2025; the visible week runs Mon 10 – Sun 16.
    final focused = DateTime(2025, 2, 12);
    final totals = <DateTime, double>{
      DateTime(2025, 2, 10): 5,
      DateTime(2025, 2, 11): 0,
      DateTime(2025, 2, 12): 10,
      DateTime(2025, 2, 13): 2.5,
      DateTime(2025, 2, 14): 0,
      DateTime(2025, 2, 15): 0,
      DateTime(2025, 2, 16): 0,
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: Scaffold(
          body: HomeCalendarSection(
            focusedDay: focused,
            onDaySelected: (_) {},
            totalForDate: (d) => totals[d] ?? 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String keyFor(DateTime d) => 'home-day-bar-${d.year}-${d.month}-${d.day}';
    // Every day keeps a 3×3 presence slot so the week row stays level.
    final mon =
        tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 10)))));
    final tue =
        tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 11)))));
    final wed =
        tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 12)))));
    expect(mon, const Size(3, 3));
    expect(tue, const Size(3, 3));
    expect(wed, const Size(3, 3));
  });

  testWidgets('Today pill is absent when today is selected', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final provider = await _provider();

    await _pumpCard(tester, provider, focusedDay: today);

    expect(find.byKey(const Key('home-today-pill')), findsNothing);
    // Date-label chrome under the week row is gone entirely.
    expect(find.textContaining('Today,'), findsNothing);
  });

  testWidgets('Today pill is present and functional for a past day',
      (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final past = today.subtract(const Duration(days: 3));
    final provider = await _provider();
    DateTime? selected;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          home: Scaffold(
            body: HomeDayCard(
              focusedDay: past,
              onDaySelected: (day) => selected = day,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pill = find.byKey(const Key('home-today-pill'));
    expect(pill, findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(pill);
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(DateUtils.isSameDay(selected!, today), isTrue);
  });
}

Future<KratomProvider> _provider() async {
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
    'dosages': '[]',
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Future<void> _pumpCard(
  WidgetTester tester,
  KratomProvider provider, {
  required DateTime focusedDay,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: Scaffold(
          body: HomeDayCard(
            focusedDay: focusedDay,
            onDaySelected: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
