import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_day_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hero slot shows time-since-last-dose for today', (tester) async {
    final now = DateTime.now();
    final provider = await _provider(
      dosages: [
        _dose('today', DateTime(now.year, now.month, now.day, 8), 2),
      ],
    );

    await _pumpCard(tester, provider, focusedDay: DateUtils.dateOnly(now));
    await tester.pumpAndSettle();

    // Sub-line names the strain code and amount for the last dose.
    expect(find.textContaining('since TEST'), findsOneWidget);
  });

  testWidgets('hero slot switches to the day span for a past date',
      (tester) async {
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

    // Past-day hero describes the first-to-last span of that day's doses.
    expect(find.textContaining('span'), findsOneWidget);
    // The now-fact "since <code>" must not appear for a past day.
    expect(find.textContaining('since TEST'), findsNothing);
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
    'effects': '[]',
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
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
