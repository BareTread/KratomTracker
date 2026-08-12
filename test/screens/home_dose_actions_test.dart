import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_dosage_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('long-press quick actions', () {
    testWidgets('long-press a dose row opens edit / delete / log again now',
        (tester) async {
      final now = DateTime.now();
      final provider = await _provider(
        dosages: [
          _dose('dose-1', now.subtract(const Duration(minutes: 90)), 2),
        ],
      );

      await _pumpList(tester, provider, doseIds: ['dose-1']);

      await tester.longPress(find.text('2g'));
      await tester.pumpAndSettle();

      expect(find.text('Log again now'), findsOneWidget);
      expect(find.text('Edit Dose'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('"log again now" re-adds the same strain and amount now',
        (tester) async {
      final now = DateTime.now();
      final provider = await _provider(
        dosages: [
          _dose('dose-1', now.subtract(const Duration(minutes: 90)), 2),
        ],
      );
      await _pumpList(tester, provider, doseIds: ['dose-1']);

      await tester.longPress(find.text('2g'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log again now'));
      await tester.pumpAndSettle();

      expect(provider.dosages, hasLength(2));
      final added = provider.dosages.last;
      expect(added.strainId, 'strain-1');
      expect(added.amount, 2);
      expect(added.notes, isNull);
      expect(
        DateUtils.dateOnly(added.timestamp),
        DateUtils.dateOnly(DateTime.now()),
      );
    });
  });
}

Future<KratomProvider> _provider({
  List<Map<String, Object?>>? dosages,
}) async {
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

Future<void> _pumpList(
  WidgetTester tester,
  KratomProvider provider, {
  required List<String> doseIds,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final strains = <String, Strain>{
    for (final s in provider.strains) s.id: s,
  };
  final dosages =
      provider.dosages.where((d) => doseIds.contains(d.id)).toList();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: Scaffold(
          body: HomeDosageList(
            dosages: List<Dosage>.unmodifiable(dosages),
            strainsById: strains,
            isToday: false,
            header: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
