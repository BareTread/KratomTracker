import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/edit_strain_form.dart';
import 'package:kratom_tracker_plus/widgets/sheet_header.dart';
import 'package:kratom_tracker_plus/widgets/strain_details_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<KratomProvider> seedProvider() async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'strains': jsonEncode([
        {
          'id': 'strain-1',
          'name': 'Red Malay',
          'code': 'RMD',
          'color': 0xFFC62828,
          'icon': 'plant',
        },
      ]),
      'dosages': jsonEncode([
        for (var i = 0; i < 3; i++)
          {
            'id': 'd$i',
            'strainId': 'strain-1',
            'amount': 16.0 + i,
            'timestamp': now
                .subtract(Duration(days: 10 - i, hours: i))
                .toIso8601String(),
          },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    return KratomProvider.create(prefs);
  }

  Future<void> openDetailsSheet(
    WidgetTester tester,
    KratomProvider provider,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet(
                  context,
                  builder: (_) => StrainDetailsView(
                    strain: provider.strains.first,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('details sheet renders strain, figures and actions',
      (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);

    expect(find.text('RMD'), findsOneWidget);
    expect(find.text('Red Malay'), findsOneWidget);
    expect(find.text('Doses'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
    expect(find.text('Log a dose'), findsOneWidget);
    expect(find.text('Delete strain'), findsOneWidget);
    expect(
      find.byKey(const Key('strain-details-edit')),
      findsOneWidget,
    );
  });

  testWidgets('In stock switch toggles provider stock state', (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);
    expect(provider.strains.first.inStock, isTrue);

    await tester.tap(find.text('In stock'));
    await tester.pumpAndSettle();
    expect(provider.strains.first.inStock, isFalse);

    await tester.tap(find.text('In stock'));
    await tester.pumpAndSettle();
    expect(provider.strains.first.inStock, isTrue);
  });

  testWidgets('editing after stock toggle keeps the current stock', (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);
    await tester.tap(find.text('In stock'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('strain-details-edit')));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    await tester.enterText(find.byType(TextFormField).first, 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.strains.first.name, 'Renamed');
    expect(provider.strains.first.inStock, isFalse);
  });

  testWidgets('saving an untouched stock field preserves a later stock change', (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);
    await tester.tap(find.byKey(const Key('strain-details-edit')));
    await tester.pumpAndSettle();
    await provider.setStrainInStock('strain-1', inStock: false);
    await tester.enterText(find.byType(TextFormField).first, 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.strains.first.name, 'Renamed');
    expect(provider.strains.first.inStock, isFalse);
  });

  testWidgets('Delete strain opens a dialog naming the dose count',
      (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);

    await tester.tap(find.text('Delete strain'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Red Malay?'), findsOneWidget);
    expect(find.textContaining('3 logged doses'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('delete does not pop a route pushed over the details sheet', (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);
    await tester.tap(find.text('Delete strain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    final navigator = Navigator.of(tester.element(find.text('open')));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(provider.strains, isEmpty);
    expect(find.text('Another route'), findsOneWidget);
  });

  testWidgets('Edit action opens EditStrainForm on a sheet', (tester) async {
    final provider = await seedProvider();
    await openDetailsSheet(tester, provider);

    await tester.tap(find.byKey(const Key('strain-details-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(EditStrainForm), findsOneWidget);
    expect(find.byType(StrainDetailsView), findsNothing);
  });
}
