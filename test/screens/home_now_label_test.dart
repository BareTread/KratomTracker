import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_day_card.dart';
import 'package:kratom_tracker_plus/screens/home/home_dosage_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'under a minute the tail prints nothing; the header shows 0m',
    (tester) async {
      final day = DateUtils.dateOnly(DateTime.now());
      final clock =
          ValueNotifier<DateTime>(day.add(const Duration(hours: 12)));
      addTearDown(clock.dispose);
      final provider = await _provider(
        dosages: [
          _dose('a', clock.value.subtract(const Duration(seconds: 20)), 2),
        ],
      );

      await _pumpHome(tester, provider, focusedDay: day, now: clock);

      // One statement of the present: 'NOW' once, no 'now' in the gutter,
      // and the header falls back to '0m' instead of 'now'.
      expect(find.text('now'), findsNothing);
      expect(find.text('0m'), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
    },
  );

  testWidgets(
    'live gap label appears once a full minute has passed',
    (tester) async {
      final day = DateUtils.dateOnly(DateTime.now());
      final clock =
          ValueNotifier<DateTime>(day.add(const Duration(hours: 12)));
      addTearDown(clock.dispose);
      final provider = await _provider(
        dosages: [
          _dose('a', clock.value.subtract(const Duration(seconds: 20)), 2),
        ],
      );

      await _pumpHome(tester, provider, focusedDay: day, now: clock);
      expect(find.text('2m'), findsNothing);

      clock.value = clock.value.add(const Duration(minutes: 2));
      await tester.pump();

      // The live gap and the header's elapsed figure both read 2m.
      expect(find.text('2m'), findsNWidgets(2));
    },
  );

  testWidgets(
    'same-minute doses on a past day print no gap label',
    (tester) async {
      final past =
          DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      final provider = await _provider(
        dosages: [
          _dose('a', DateTime(past.year, past.month, past.day, 9, 30, 5), 2),
          _dose('b', DateTime(past.year, past.month, past.day, 9, 30, 44), 3),
        ],
      );

      await _pumpHome(tester, provider, focusedDay: past, isToday: false);

      expect(find.text('now'), findsNothing);
      expect(find.text('NOW'), findsNothing);
    },
  );
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
      'id': id,
      'strainId': 'strain-1',
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };

/// Pumps the real home surface: day card on top, the vine list below.
Future<void> _pumpHome(
  WidgetTester tester,
  KratomProvider provider, {
  required DateTime focusedDay,
  bool isToday = true,
  ValueListenable<DateTime>? now,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final strains = <String, Strain>{for (final s in provider.strains) s.id: s};

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
          body: Column(
            children: [
              HomeDayCard(
                focusedDay: focusedDay,
                onDaySelected: (_) {},
                now: now,
              ),
              Expanded(
                child: HomeDosageList(
                  dosages: List<Dosage>.unmodifiable(provider.dosages),
                  strainsById: strains,
                  isToday: isToday,
                  now: now,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
