import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

    // Sub-line names the strain code and amount for the last dose.
    expect(
      find.textContaining('since TEST', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('hero slot shows the day total for a past date', (tester) async {
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

    // Past-day hero is the day's total; the first-to-last window stays quiet.
    expect(find.text('5g'), findsOneWidget);
    // Build the expected window with DateFormat so intl's exact spacing
    // (narrow no-break space before AM/PM) is not hardcoded.
    String at(int hour, int minute) => DateFormat.jm()
        .format(DateTime(past.year, past.month, past.day, hour, minute));
    expect(
      find.textContaining(
        '2 doses · ${at(7, 4)} – ${at(20, 32)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // The span hero is gone, and "since <code>" must not appear for a past day.
    expect(find.textContaining('span', findRichText: true), findsNothing);
    expect(
      find.textContaining('since TEST', findRichText: true),
      findsNothing,
    );
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
