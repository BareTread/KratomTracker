import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_day_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quiet line shows time-since-last-dose for today', (tester) async {
    final now = DateTime.now();
    final provider = await _provider(
      dosages: [
        _dose('today', DateTime(now.year, now.month, now.day, 8), 2),
      ],
    );

    await _pumpCard(tester, provider, focusedDay: DateUtils.dateOnly(now));

    // Headline: the elapsed figure under a Since last dose label, with the
    // day's running total and count beside it.
    expect(find.text('Since last dose'), findsOneWidget);
    expect(find.text('2g'), findsOneWidget);
    expect(find.text('1 dose'), findsOneWidget);
  });

  testWidgets('quiet line advances when the now clock ticks', (tester) async {
    final now = DateTime.now();
    final provider = await _provider(
      dosages: [
        _dose('today', DateTime(now.year, now.month, now.day, 8), 2),
      ],
    );
    final clock = ValueNotifier<DateTime>(
      DateTime(now.year, now.month, now.day, 9, 2),
    );
    addTearDown(clock.dispose);

    await _pumpCard(
      tester,
      provider,
      focusedDay: DateUtils.dateOnly(now),
      now: clock,
    );
    expect(find.text('1h 2m'), findsOneWidget);

    // Hours pass (resume from background); the label must catch up without
    // any dose or strain change forcing a rebuild.
    clock.value = DateTime(now.year, now.month, now.day, 11, 30);
    await tester.pump();
    expect(find.text('3h 30m'), findsOneWidget);
  });

  testWidgets('quiet line shows the day total for a past date', (tester) async {
    final now = DateTime.now();
    final past = DateUtils.dateOnly(now).subtract(const Duration(days: 2));
    final provider = await _provider(
      dosages: [
        _dose('past-am', DateTime(past.year, past.month, past.day, 7, 4), 2),
        _dose('past-pm', DateTime(past.year, past.month, past.day, 20, 32), 3),
      ],
    );

    await _pumpCard(tester, provider, focusedDay: past);
    await tester.pumpAndSettle();

    // Past-day headline is the day's total and dose count.
    expect(find.text('5g'), findsOneWidget);
    expect(find.text('2 doses'), findsOneWidget);
    // Elapsed "since last dose" must not appear for a past day.
    expect(find.text('Since last dose'), findsNothing);
  });
}

Future<KratomProvider> _provider({List<Map<String, Object?>>? dosages}) async {
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
    'dosages': jsonEncode(dosages ?? const []),
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Map<String, Object?> _dose(String id, DateTime timestamp, double amount) => {
      'id': 'dose-$id',
      'strainId': 'strain-1',
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };

Future<void> _pumpCard(
  WidgetTester tester,
  KratomProvider provider, {
  required DateTime focusedDay,
  ValueListenable<DateTime>? now,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeDayCard(
              focusedDay: focusedDay,
              onDaySelected: (_) {},
              now: now,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
