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

  Future<KratomProvider> providerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return KratomProvider.create(prefs);
  }

  Future<void> pumpScreen(WidgetTester tester, KratomProvider provider) async {
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
  }

  Map<String, Object> strain({
    required String id,
    required String name,
    required String code,
    bool inStock = true,
  }) =>
      {
        'id': id,
        'name': name,
        'code': code,
        'color': 0xFF00ACC1,
        'icon': 'leaf',
        'inStock': inStock,
      };

  testWidgets('strains list renders and the header add action opens the form',
      (tester) async {
    final provider = await providerWith({
      'strains': jsonEncode([
        strain(id: 'strain-1', name: 'Test Strain', code: 'TEST'),
      ]),
      'dosages': '[]',
    });
    await pumpScreen(tester, provider);

    expect(find.text('TEST'), findsOneWidget);
    expect(find.text('Test Strain'), findsOneWidget);
    expect(find.textContaining('strains'), findsNothing);
    expect(find.text('Add strain'), findsOneWidget);
    // The old per-row "In stock" chip and the bottom "Add Strain" slab are
    // gone: stock is stated only on out-of-stock rows, and the add action
    // moved to the header as 'Add strain'.
    expect(find.text('In stock'), findsNothing);
    expect(find.text('Add Strain'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('strains-add'))).height, greaterThanOrEqualTo(48));

    await tester.tap(find.byKey(const Key('strains-add')));
    await tester.pumpAndSettle();

    expect(find.byType(AddStrainForm), findsOneWidget);
  });

  testWidgets('out-of-stock rows say so; in-stock rows say nothing',
      (tester) async {
    final provider = await providerWith({
      'strains': jsonEncode([
        strain(id: 's1', name: 'Red Malay', code: 'RMD'),
        strain(id: 's2', name: 'Green Balance', code: 'GBG', inStock: false),
      ]),
      'dosages': '[]',
    });
    await pumpScreen(tester, provider);

    // One "Out of stock" word on the right edge of the exception row; the
    // in-stock row carries no stock text at all.
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('1 out of stock'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('GBG.*out of stock', caseSensitive: false),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty state explains itself and its action opens the form',
      (tester) async {
    final provider = await providerWith({
      'strains': '[]',
      'dosages': '[]',
    });
    await pumpScreen(tester, provider);

    expect(find.text('No strains yet'), findsOneWidget);
    expect(
      find.text(
        'Add the strains you keep on hand. Each gets a code and a colour '
        'that marks its doses everywhere in the app.',
      ),
      findsOneWidget,
    );
    // The head hides both the count line and its add action when the index
    // is empty; the empty state owns the only 'strains-add' target.
    expect(find.text('Add a strain'), findsOneWidget);
    expect(find.text('Add strain'), findsNothing);
    expect(find.byKey(const Key('strains-add')), findsOneWidget);

    await tester.tap(find.text('Add a strain'));
    await tester.pumpAndSettle();

    expect(find.byType(AddStrainForm), findsOneWidget);
  });

  testWidgets('a strain with no doses reads "Not used yet"', (tester) async {
    final provider = await providerWith({
      'strains': jsonEncode([
        strain(id: 's1', name: 'Red Malay', code: 'RMD'),
        strain(id: 's2', name: 'Fresh Leaf', code: 'FRL'),
      ]),
      'dosages': jsonEncode([
        {
          'id': 'd1',
          'strainId': 's1',
          'amount': 14.0,
          'timestamp':
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        },
      ]),
    });
    await pumpScreen(tester, provider);

    // The used strain gets the dose sheet's recency phrasing; the untouched
    // one reads "Not used yet".
    expect(find.text('Not used yet'), findsOneWidget);
    expect(find.textContaining('3d ago'), findsOneWidget);
  });
}
