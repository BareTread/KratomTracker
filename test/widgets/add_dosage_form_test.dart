import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/add_dosage_form.dart';
import 'package:kratom_tracker_plus/widgets/dose_amount_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddDosageForm', () {
    testWidgets('notes entered in the form reach the stored dosage',
        (tester) async {
      final provider = await _seededProvider();
      await _pumpForm(tester, provider);

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '2.5');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        '  morning tea  ',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();

      expect(provider.dosages, hasLength(1));
      final dose = provider.dosages.single;
      expect(dose.amount, 2.5);
      expect(dose.notes, 'morning tea');
      expect(dose.strainId, 's-alpha');
    });

    testWidgets('with a past selectedDate the saved dosage lands on that date',
        (tester) async {
      final provider = await _seededProvider();
      final past = DateTime(2024, 6, 15);
      provider.setSelectedDate(past);
      await _pumpForm(tester, provider);

      await tester.tap(find.byKey(const Key('dose-strain-s-beta')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '1.5');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log BETA 1.5g'));
      await tester.pumpAndSettle();

      expect(provider.dosages, hasLength(1));
      final dose = provider.dosages.single;
      expect(dose.timestamp.year, past.year);
      expect(dose.timestamp.month, past.month);
      expect(dose.timestamp.day, past.day);
    });

    testWidgets('amount 0, -1, and abc are rejected without submitting',
        (tester) async {
      final provider = await _seededProvider();
      await _pumpForm(tester, provider);

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pumpAndSettle();

      final amountField = find.byKey(DoseAmountControl.fieldKey);

      await tester.enterText(amountField, '0');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(provider.dosages, isEmpty);
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      await tester.enterText(amountField, '-1');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(provider.dosages, isEmpty);
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      await tester.enterText(amountField, 'abc');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(provider.dosages, isEmpty);
      expect(find.text('Please enter a valid number'), findsOneWidget);
    });

    testWidgets('strain tiles render in provider.strainUsage order',
        (tester) async {
      final now = DateTime.now();
      final provider = await _provider(
        strains: [
          _strain(id: 's-a', code: 'ALOE', name: 'Aloe'),
          _strain(id: 's-b', code: 'BASL', name: 'Basil', color: 0xFF2196F3),
          _strain(id: 's-c', code: 'CEDR', name: 'Cedar', color: 0xFFFF9800),
        ],
        dosages: [
          _dose(
            id: 'd1',
            strainId: 's-a',
            amount: 2,
            timestamp: now.subtract(const Duration(days: 1)),
          ),
          _dose(
            id: 'd2',
            strainId: 's-b',
            amount: 2,
            timestamp: now.subtract(const Duration(days: 4)),
          ),
        ],
      );
      final expectedOrder =
          provider.strainUsage.map((u) => u.strain.code).toList();

      await _pumpForm(tester, provider);

      expect(_visibleCodes(tester, expectedOrder), expectedOrder);
    });

    testWidgets('header is a single title with no search or captions',
        (tester) async {
      final provider = await _seededProvider();
      await _pumpForm(tester, provider);

      expect(find.text('Select Strain'), findsNothing);
      expect(find.text('Add Dose'), findsNothing);
      expect(
        tester.widgetList<Text>(find.text('Log dose')).where(
              (text) => text.style?.fontSize == 30,
            ),
        hasLength(1),
      );
      expect(find.textContaining('Least recently used'), findsNothing);
      expect(find.textContaining('Bar fills'), findsNothing);
      expect(find.text('Search strains'), findsNothing);
      expect(find.byKey(DoseAmountControl.fieldKey), findsOneWidget);
    });

    testWidgets('amount is prefilled from the strain last dose, not the average',
        (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-alpha', code: 'ALPHA', name: 'Alpha Strain'),
        ],
        dosages: [
          _dose(
            id: 'd-new',
            strainId: 's-alpha',
            amount: 3.5,
            timestamp: _daysAgo(2),
          ),
          _dose(
            id: 'd-old',
            strainId: 's-alpha',
            amount: 4.5,
            timestamp: _daysAgo(5),
          ),
        ],
      );
      await _pumpForm(tester, provider);

      expect(_amountText(tester), '3.5');
      expect(find.text('Log ALPHA 3.5g'), findsOneWidget);
    });

    testWidgets('saved time freezes at sheet open, not save time',
        (tester) async {
      final provider = await _leadProvider();
      final openMoment = DateTime.now();
      await _pumpForm(tester, provider);

      expect(_chipText(tester), 'Now');
      expect(find.byKey(const Key('add-dose-now-pill')), findsNothing);

      final beforeIds = provider.dosages.map((dose) => dose.id).toSet();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();

      final created = provider.dosages.singleWhere(
        (dose) => !beforeIds.contains(dose.id),
      );
      final delta = created.timestamp.difference(openMoment).inSeconds.abs();
      expect(
        delta,
        lessThan(5),
        reason: 'expected frozen open time (~$openMoment) but got ${created.timestamp}',
      );
    });

    testWidgets('Now pill snaps the time field to the current time',
        (tester) async {
      final provider = await _seededProvider();
      provider.setSelectedDate(DateTime(2024, 6, 15, 8));
      await _pumpForm(tester, provider);

      expect(_chipText(tester), contains('Jun 15, 2024'));
      expect(_chipText(tester), isNot('Now'));

      final beforeNow = DateTime.now();
      await tester.tap(find.byKey(const Key('add-dose-now-pill')));
      await tester.pump();

      final chip = _chipText(tester);
      final expected = DateFormat('h:mm a').format(beforeNow);
      final alt = DateFormat('h:mm a')
          .format(beforeNow.add(const Duration(minutes: 1)));
      expect(
        chip.contains(expected) || chip.contains(alt),
        isTrue,
        reason: 'expected one of $expected / $alt in "$chip"',
      );
      expect(chip, contains('Jun 15, 2024'));
    });

    testWidgets('clear rest lead preselects the first in-stock strain',
        (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);

      expect(find.text('Pick a strain'), findsNothing);
      expect(find.textContaining('Alpha Strain'), findsOneWidget);
      expect(_amountText(tester), '2.5');
      expect(find.text('Log ALPHA 2.5g'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a rest tie still preselects the top suggestion', (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-a', code: 'ALPHA', name: 'Alpha'),
          _strain(id: 's-b', code: 'BETA', name: 'Beta', color: 0xFF4CAF50),
        ],
        dosages: [
          _dose(id: 'd-a', strainId: 's-a', amount: 2, timestamp: _daysAgo(2)),
          _dose(id: 'd-b', strainId: 's-b', amount: 2, timestamp: _daysAgo(2)),
        ],
      );
      await _pumpForm(tester, provider);

      expect(find.text('Pick a strain'), findsNothing);
      expect(_amountText(tester), '2');
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a single used in-stock strain is preselected', (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-only', code: 'ONLY', name: 'Only Strain'),
        ],
        dosages: [
          _dose(id: 'd1', strainId: 's-only', amount: 3, timestamp: _daysAgo(1)),
        ],
      );
      await _pumpForm(tester, provider);

      expect(find.textContaining('Only Strain'), findsOneWidget);
      expect(_amountText(tester), '3');
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('out-of-stock strain is never preselected', (tester) async {
      final provider = await _provider(
        strains: [
          _strain(
            id: 's-oos',
            code: 'OOS',
            name: 'Rested Out',
            inStock: false,
          ),
          _strain(id: 's-a', code: 'ALPHA', name: 'Alpha'),
          _strain(id: 's-b', code: 'BETA', name: 'Beta', color: 0xFF4CAF50),
        ],
        dosages: [
          _dose(id: 'd-oos', strainId: 's-oos', amount: 4, timestamp: _daysAgo(10)),
          _dose(id: 'd-a', strainId: 's-a', amount: 2, timestamp: _daysAgo(2)),
          _dose(id: 'd-b', strainId: 's-b', amount: 2, timestamp: _daysAgo(2)),
        ],
      );
      await _pumpForm(tester, provider);

      // The rested out-of-stock strain is skipped; an in-stock one is chosen.
      expect(find.text('Pick a strain'), findsNothing);
      expect(find.textContaining('Rested Out'), findsNothing);
      expect(find.textContaining('Log OOS'), findsNothing);
      expect(_amountText(tester), '2');
    });

    testWidgets('preselectedStrainId wins over the rest lead', (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider, preselectedStrainId: 's-beta');

      expect(find.textContaining('Beta Strain'), findsOneWidget);
      expect(find.textContaining('Alpha Strain'), findsNothing);
      expect(_amountText(tester), '1');
      expect(find.text('Log BETA 1g'), findsOneWidget);
    });

    testWidgets('stepper changes the amount by 0.1 and clamps', (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);

      expect(_amountText(tester), '2.5');
      await tester.tap(find.byKey(DoseAmountControl.plusKey));
      await tester.pump();
      expect(_amountText(tester), '2.6');
      await tester.tap(find.byKey(DoseAmountControl.minusKey));
      await tester.pump();
      expect(_amountText(tester), '2.5');

      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '0.1');
      await tester.tap(find.byKey(DoseAmountControl.minusKey));
      await tester.pump();
      expect(_amountText(tester), '0.1');

      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '100');
      await tester.tap(find.byKey(DoseAmountControl.plusKey));
      await tester.pump();
      expect(_amountText(tester), '100');
    });

    testWidgets('a recent-amount chip sets the amount', (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-sr', code: 'SR', name: 'Super Red'),
        ],
        dosages: [
          _dose(id: 'd4', strainId: 's-sr', amount: 16.6, timestamp: _daysAgo(1)),
          _dose(id: 'd3', strainId: 's-sr', amount: 16.3, timestamp: _daysAgo(2)),
          _dose(id: 'd2', strainId: 's-sr', amount: 15, timestamp: _daysAgo(3)),
          _dose(id: 'd1', strainId: 's-sr', amount: 16.6, timestamp: _daysAgo(4)),
        ],
      );
      await _pumpForm(tester, provider);

      expect(find.text('16.6g'), findsOneWidget);
      expect(find.text('16.3g'), findsOneWidget);
      expect(find.text('15g'), findsOneWidget);
      expect(find.text('Log SR 16.6g'), findsOneWidget);

      await tester.tap(find.text('16.3g'));
      await tester.pump();

      expect(_amountText(tester), '16.3');
      expect(find.text('Log SR 16.3g'), findsOneWidget);
    });

    testWidgets('changing strain re-prefills and drops a typed amount',
        (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);

      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '9');
      await tester.pump();
      expect(find.text('Log ALPHA 9g'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dose-strain-s-beta')));
      await tester.pump();

      expect(_amountText(tester), '1');
      expect(find.text('Log BETA 1g'), findsOneWidget);
    });

    testWidgets('save then Undo removes the created dose', (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);
      final beforeIds = provider.dosages.map((dose) => dose.id).toSet();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();

      final created = provider.dosages.singleWhere(
        (dose) => !beforeIds.contains(dose.id),
      );
      expect(created.amount, 2.5);
      expect(find.text('Logged ALPHA · 2.5g'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.elevation, 0);
      expect(bar.duration, const Duration(seconds: 5));
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(bar.margin, const EdgeInsets.fromLTRB(16, 0, 88, 24));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(provider.dosages.map((dose) => dose.id).toSet(), beforeIds);
    });
  });

  group('strain stock partition', () {
    Future<KratomProvider> partitionSeed() async {
      final provider = await searchSeed();
      await provider.setStrainInStock('s-d', inStock: false);
      await provider.setStrainInStock('s-a', inStock: false);
      return provider;
    }

    testWidgets('in-stock group first, then divider, then out-of-stock group',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      expect(find.text('Out of stock'), findsOneWidget);
      expect(
        _visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['CEDR', 'BASL', 'CINN', 'ALOE'],
      );
    });

    testWidgets('out-of-stock tiles stay selectable and Back in stock works',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      expect(find.text('Back in stock'), findsNothing);

      await tester.tap(find.byKey(const Key('dose-strain-s-d')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cinnamon Bark'), findsOneWidget);
      expect(find.text('Back in stock'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Back in stock'));
      await tester.pumpAndSettle();

      expect(provider.getStrain('s-d')!.inStock, isTrue);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('Back in stock'), findsNothing);
      expect(
        _visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['CEDR', 'CINN', 'BASL', 'ALOE'],
      );
    });

    testWidgets('all in stock: no divider, frozen order unchanged',
        (tester) async {
      final provider = await searchSeed();
      final frozenOrder =
          provider.strainUsage.map((u) => u.strain.code).toList();
      await _pumpForm(tester, provider);

      expect(find.text('Out of stock'), findsNothing);
      expect(find.text('Back in stock'), findsNothing);
      expect(_visibleCodes(tester, frozenOrder), frozenOrder);
    });
  });

  group('validateDoseAmount / parseDoseAmount', () {
    test('accepts comma decimal separator', () {
      expect(parseDoseAmount('1,5'), 1.5);
      expect(validateDoseAmount('1,5'), isNull);
    });

    test('rejects absurd and non-finite values', () {
      expect(validateDoseAmount('101'), contains('too high'));
      expect(validateDoseAmount(''), contains('enter an amount'));
    });
  });
}

/// Seeds four strains with a deterministic frozen order:
///   CEDR, CINN (both never used, tie broken by code ascending),
///   then BASL (used 4d ago), then ALOE (used 1d ago).
Future<KratomProvider> searchSeed() async {
  final now = DateTime.now();
  return _provider(
    strains: [
      _strain(id: 's-a', code: 'ALOE', name: 'Aloe Vera'),
      _strain(id: 's-b', code: 'BASL', name: 'Basil Fresh', color: 0xFF4CAF50),
      _strain(id: 's-c', code: 'CEDR', name: 'Cedar Wood', color: 0xFFFF9800),
      _strain(id: 's-d', code: 'CINN', name: 'Cinnamon Bark', color: 0xFFE91E63),
    ],
    dosages: [
      _dose(
        id: 'd1',
        strainId: 's-a',
        amount: 2,
        timestamp: now.subtract(const Duration(days: 1)),
      ),
      _dose(
        id: 'd2',
        strainId: 's-b',
        amount: 2,
        timestamp: now.subtract(const Duration(days: 4)),
      ),
    ],
  );
}

/// ALPHA rested 5 calendar days (2.5g), BETA rested 1 day (1g).
Future<KratomProvider> _leadProvider() {
  return _provider(
    strains: [
      _strain(id: 's-alpha', code: 'ALPHA', name: 'Alpha Strain'),
      _strain(id: 's-beta', code: 'BETA', name: 'Beta Strain', color: 0xFF4CAF50),
    ],
    dosages: [
      _dose(id: 'd-a', strainId: 's-alpha', amount: 2.5, timestamp: _daysAgo(5)),
      _dose(id: 'd-b', strainId: 's-beta', amount: 1, timestamp: _daysAgo(1)),
    ],
  );
}

Future<KratomProvider> _seededProvider() {
  return _provider(
    strains: [
      _strain(id: 's-alpha', code: 'ALPHA', name: 'Alpha Strain'),
      _strain(id: 's-beta', code: 'BETA', name: 'Beta Strain', color: 0xFF4CAF50),
    ],
    dosages: const [],
  );
}

Future<KratomProvider> _provider({
  required List<Map<String, dynamic>> strains,
  required List<Map<String, dynamic>> dosages,
}) async {
  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode(strains),
    'dosages': jsonEncode(dosages),
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Map<String, dynamic> _strain({
  required String id,
  required String code,
  required String name,
  int color = 0xFF00ACC1,
  String icon = 'Leaf',
  bool inStock = true,
}) =>
    {
      'id': id,
      'name': name,
      'code': code,
      'color': color,
      'icon': icon,
      'inStock': inStock,
    };

Map<String, dynamic> _dose({
  required String id,
  required String strainId,
  required double amount,
  required DateTime timestamp,
}) =>
    {
      'id': id,
      'strainId': strainId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };

DateTime _daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, 12);
}

String _chipText(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('add-dose-time-chip')),
          matching: find.byType(Text),
        ),
      )
      .data!;
}

String _amountText(WidgetTester tester) {
  return tester
      .widget<TextFormField>(find.byKey(DoseAmountControl.fieldKey))
      .controller!
      .text;
}

List<String> _visibleCodes(WidgetTester tester, List<String> codes) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        codes.contains(widget.data) &&
        widget.style?.fontWeight == FontWeight.w600,
  );
  return tester.widgetList<Text>(finder).map((text) => text.data!).toList();
}

Future<void> _pumpForm(
  WidgetTester tester,
  KratomProvider provider, {
  String? preselectedStrainId,
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddDosageForm(
                      preselectedStrainId: preselectedStrainId,
                    ),
                  );
                },
                child: const Text('open-sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-sheet'));
  await tester.pumpAndSettle();
}
