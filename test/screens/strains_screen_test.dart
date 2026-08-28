import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/strains_screen.dart';
import 'package:kratom_tracker_plus/widgets/add_strain_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('strains list renders and Add Strain still opens the form',
      (tester) async {
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
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          home: const StrainsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEST'), findsOneWidget);
    expect(find.text('Test Strain'), findsOneWidget);
    expect(find.text('Add Strain'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);

    await tester.tap(find.text('Add Strain'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStrainForm), findsOneWidget);
  });
}
