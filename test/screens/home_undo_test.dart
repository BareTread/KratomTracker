import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_dosage_list.dart';
import 'package:kratom_tracker_plus/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"Log again now" Undo restores the original dose list',
      (tester) async {
    final provider = await _provider(
      dosages: [
        _dose(
          'dose-1',
          DateTime.now().subtract(const Duration(minutes: 90)),
          2,
        ),
      ],
    );

    await _pumpList(tester, provider, doseIds: ['dose-1']);

    await tester.longPress(find.text('2g'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log again now'));
    await tester.pumpAndSettle();

    expect(provider.dosages, hasLength(2));
    expect(find.text('Logged TEST · 2g'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(provider.dosages, hasLength(1));
    expect(provider.dosages.single.id, 'dose-1');
  });

  testWidgets('delete Undo brings back the same dose', (tester) async {
    final timestamp = DateTime.now().subtract(const Duration(hours: 3));
    final provider = await _provider(
      dosages: [
        _dose('dose-1', timestamp, 2.5, notes: 'morning'),
      ],
    );

    await _pumpList(tester, provider, doseIds: ['dose-1']);

    await tester.longPress(find.text('2.5g'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(provider.dosages, isEmpty);
    expect(find.text('Dose deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(provider.dosages, hasLength(1));
    final restored = provider.dosages.single;
    expect(restored.strainId, 'strain-1');
    expect(restored.amount, 2.5);
    expect(restored.timestamp, timestamp);
    expect(restored.notes, 'morning');
  });

  testWidgets('FAB repeat pill logs the latest dose again and can be undone',
      (tester) async {
    // The latest dose is yesterday's — the pill tracks history overall, not
    // just today.
    final provider = await _provider(
      dosages: [
        _dose(
          'dose-old',
          DateTime.now().subtract(const Duration(days: 1)),
          16.6,
        ),
        _dose(
          'dose-older',
          DateTime.now().subtract(const Duration(days: 3)),
          2,
        ),
      ],
    );

    await _pumpHome(tester, provider);

    await tester.longPress(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();
    expect(
      find.text('TEST · 16.6g again', findRichText: true),
      findsOneWidget,
    );

    final before = DateTime.now();
    await tester.tap(find.byKey(const Key('home-fab-repeat-last')));
    await tester.pumpAndSettle();

    expect(provider.dosages, hasLength(3));
    final added = provider.dosages.last;
    expect(added.strainId, 'strain-1');
    expect(added.amount, 16.6);
    expect(
      added.timestamp.difference(before).abs(),
      lessThan(const Duration(seconds: 5)),
    );
    expect(find.text('Logged TEST · 16.6g'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(provider.dosages, hasLength(2));
    expect(
      provider.dosages.map((d) => d.id),
      containsAll(['dose-old', 'dose-older']),
    );
  });

  testWidgets('repeat pill is hidden when the log is empty', (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider);

    await tester.longPress(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-fab-add-dose')), findsOneWidget);
    expect(find.byKey(const Key('home-fab-add-strain')), findsOneWidget);
    expect(find.byKey(const Key('home-fab-repeat-last')), findsNothing);
  });

  testWidgets('system back closes the open menu without leaving home',
      (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider);

    await tester.longPress(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-fab-add-dose')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-fab-add-dose')), findsNothing);
    expect(find.byKey(const Key('home-fab-add-strain')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
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

Map<String, Object?> _dose(
  String id,
  DateTime timestamp,
  double amount, {
  String? notes,
}) =>
    {
      'id': id,
      'strainId': 'strain-1',
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };

Future<void> _pumpHome(WidgetTester tester, KratomProvider provider) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
