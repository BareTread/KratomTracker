import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home_screen.dart';
import 'package:kratom_tracker_plus/widgets/add_dosage_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the FAB opens Add Dose directly', (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider);

    await tester.tap(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();

    expect(find.byType(AddDosageForm), findsOneWidget);
  });

  testWidgets('long-pressing the FAB opens the labelled action menu',
      (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider);

    await tester.longPress(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-fab-add-dose')), findsOneWidget);
    expect(find.byKey(const Key('home-fab-add-strain')), findsOneWidget);
    expect(find.text('Add Dose'), findsOneWidget);
    expect(find.text('Add Strain'), findsOneWidget);
  });

  testWidgets('tapping a menu pill fires its action and dismisses',
      (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider);

    await tester.longPress(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-fab-add-dose')));
    await tester.pumpAndSettle();

    expect(find.byType(AddDosageForm), findsOneWidget);
    // Menu is gone once the sheet is open.
    expect(find.byKey(const Key('home-fab-add-strain')), findsNothing);
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
    'effects': '[]',
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

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
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
