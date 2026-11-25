import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/dose_amount_control.dart';
import 'package:kratom_tracker_plus/widgets/edit_dosage_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<KratomProvider> pumpForm(WidgetTester tester) async {
    final timestamp = DateTime.now().subtract(const Duration(hours: 2));
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
      'dosages': jsonEncode([
        {
          'id': 'dose-1',
          'strainId': 'strain-1',
          'amount': 2.347,
          'timestamp': timestamp.toIso8601String(),
        },
      ]),
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
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
            body: EditDosageForm(dosage: provider.dosages.single),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('a notes-only edit keeps an amount the field rounds',
      (tester) async {
    // The field shows two decimals; saving without touching it must not
    // write the rounded 2.35 over the stored 2.347.
    final provider = await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      'evening',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(provider.dosages.single.notes, 'evening');
    expect(provider.dosages.single.amount, 2.347);
  });

  testWidgets('retyping the shown amount saves what was typed', (tester) async {
    final provider = await pumpForm(tester);
    expect(find.widgetWithText(TextFormField, '2.35'), findsOneWidget);
    final amountField = find.descendant(
      of: find.byType(DoseAmountControl),
      matching: find.byType(TextField),
    );

    await tester.enterText(amountField, '');
    await tester.enterText(amountField, '2.35');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(provider.dosages.single.amount, 2.35);
  });
}
