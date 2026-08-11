import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/add_dosage_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddDosageForm', () {
    testWidgets('notes entered in the form reach the stored dosage',
        (tester) async {
      final provider = await _seededProvider();
      await _pumpForm(tester, provider);

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '2.5');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        '  morning tea  ',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Dose'));
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

      await tester.tap(find.text('BETA'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '1.5');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Dose'));
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

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      final amountField = find.widgetWithText(TextFormField, 'Amount');

      await tester.enterText(amountField, '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Dose'));
      await tester.pumpAndSettle();
      expect(provider.dosages, isEmpty);
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      await tester.enterText(amountField, '-1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Dose'));
      await tester.pumpAndSettle();
      expect(provider.dosages, isEmpty);
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      await tester.enterText(amountField, 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Dose'));
      await tester.pumpAndSettle();
      expect(provider.dosages, isEmpty);
      expect(find.text('Please enter a valid number'), findsOneWidget);
    });

    testWidgets('strain list renders in provider.strainUsage order',
        (tester) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'strains': jsonEncode([
          {
            'id': 's-a',
            'name': 'Aloe',
            'code': 'ALOE',
            'color': 0xFF4CAF50,
            'icon': 'Leaf',
          },
          {
            'id': 's-b',
            'name': 'Basil',
            'code': 'BASL',
            'color': 0xFF2196F3,
            'icon': 'Plant',
          },
          {
            'id': 's-c',
            'name': 'Cedar',
            'code': 'CEDR',
            'color': 0xFFFF9800,
            'icon': 'Forest',
          },
        ]),
        'dosages': jsonEncode([
          // A used most recently → lowest rotation priority
          {
            'id': 'd1',
            'strainId': 's-a',
            'amount': 2.0,
            'timestamp': now.subtract(const Duration(days: 1)).toIso8601String(),
          },
          // B used a few days ago
          {
            'id': 'd2',
            'strainId': 's-b',
            'amount': 2.0,
            'timestamp': now.subtract(const Duration(days: 4)).toIso8601String(),
          },
          // C never used → highest rotation priority
        ]),
        'effects': '[]',
      });

      final prefs = await SharedPreferences.getInstance();
      final provider = await KratomProvider.create(prefs);
      final expectedOrder =
          provider.strainUsage.map((u) => u.strain.code).toList();

      await _pumpForm(tester, provider);

      // Collect code labels in paint order from the list tiles.
      final codeFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            expectedOrder.contains(widget.data) &&
            widget.style?.fontWeight == FontWeight.w600,
      );
      final texts = tester.widgetList<Text>(codeFinder).map((t) => t.data!).toList();
      expect(texts, expectedOrder);
    });
  });

  group('strain search', () {
    Finder codeFinder(List<String> codes) => find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              codes.contains(widget.data) &&
              widget.style?.fontWeight == FontWeight.w600,
        );

    List<String> visibleCodes(WidgetTester tester, List<String> all) {
      final finder = codeFinder(all);
      return tester
          .widgetList<Text>(finder)
          .map((t) => t.data!)
          .toList();
    }

    testWidgets('filters by code substring (case-insensitive)',
        (tester) async {
      final provider = await searchSeed();
      await _pumpForm(tester, provider);

      await tester.enterText(find.byType(TextField), 'cin');
      await tester.pumpAndSettle();

      expect(visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
          ['CINN'],);
    });

    testWidgets('filters by full name substring', (tester) async {
      final provider = await searchSeed();
      await _pumpForm(tester, provider);

      await tester.enterText(find.byType(TextField), 'basil');
      await tester.pumpAndSettle();

      expect(visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
          ['BASL'],);
    });

    testWidgets('preserves frozen relative order of surviving strains',
        (tester) async {
      final provider = await searchSeed();
      await _pumpForm(tester, provider);

      // 'ba' matches CINN ("Cinnamon Bark") and BASL ("BASL"/"Basil Fresh").
      // Frozen order is CINN before BASL.
      await tester.enterText(find.byType(TextField), 'ba');
      await tester.pumpAndSettle();

      expect(visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
          ['CINN', 'BASL'],);
    });

    testWidgets('empty query shows the full list in frozen order',
        (tester) async {
      final provider = await searchSeed();
      await _pumpForm(tester, provider);

      // Type then clear via the suffix button — full list must return
      // in frozen order.
      await tester.enterText(find.byType(TextField), 'cin');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
          ['CEDR', 'CINN', 'BASL', 'ALOE'],);
    });

    testWidgets('shows an empty state when nothing matches', (tester) async {
      final provider = await searchSeed();
      await _pumpForm(tester, provider);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.textContaining('No strains match'), findsOneWidget);
      expect(visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']), isEmpty);
    });
  });

  group('strain stock partition', () {
    // Same seed as `searchSeed`: frozen order is CEDR, CINN, BASL, ALOE.
    Future<KratomProvider> partitionSeed() async {
      final provider = await searchSeed();
      // Mark CINN and ALOE out of stock. In-stock group keeps frozen relative
      // order [CEDR, BASL]; out-of-stock group keeps [CINN, ALOE].
      await provider.setStrainInStock('s-d', inStock: false);
      await provider.setStrainInStock('s-a', inStock: false);
      return provider;
    }

    Finder codeFinder(List<String> codes) => find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              codes.contains(widget.data) &&
              widget.style?.fontWeight == FontWeight.w600,
        );

    List<String> visibleCodes(WidgetTester tester, List<String> all) =>
        tester.widgetList<Text>(codeFinder(all)).map((t) => t.data!).toList();

    testWidgets('in-stock group first, then divider, then out-of-stock group',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      // Divider is present.
      expect(find.text('Out of stock'), findsOneWidget);

      // Visible order: in-stock frozen order, then out-of-stock frozen order.
      expect(
        visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['CEDR', 'BASL', 'CINN', 'ALOE'],
      );
    });

    testWidgets('out-of-stock rows carry a one-tap back-in-stock affordance',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      expect(find.text('Back in stock'), findsNWidgets(2));

      // Tap the first one (belongs to CINN, the first out-of-stock row).
      await tester.tap(find.text('Back in stock').first);
      await tester.pumpAndSettle();

      expect(provider.getStrain('s-d')!.inStock, true);
      // CINN moved up into the in-stock group; divider still present (ALOE
      // remains out).
      expect(find.text('Out of stock'), findsOneWidget);
      expect(
        visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['CEDR', 'CINN', 'BASL', 'ALOE'],
      );
    });

    testWidgets('out-of-stock rows remain fully selectable', (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      // Tap ALOE — the last row, out of stock — should still open the dose
      // details form (identified by its back arrow, unique to that step).
      await tester.tap(find.text('ALOE'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add Dose'), findsOneWidget);
    });

    testWidgets('search keeps an out-of-stock match in the out-of-stock group',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      // 'cin' matches CINN only — and CINN is out of stock, so it stays below
      // the divider.
      await tester.enterText(find.byType(TextField), 'cin');
      await tester.pumpAndSettle();

      expect(find.text('Out of stock'), findsOneWidget);
      expect(visibleCodes(tester, ['CINN']), ['CINN']);
    });

    testWidgets('all in stock: no divider, no header, frozen order unchanged',
        (tester) async {
      final provider = await searchSeed();
      final frozenOrder =
          provider.strainUsage.map((u) => u.strain.code).toList();
      await _pumpForm(tester, provider);

      expect(find.text('Out of stock'), findsNothing);
      expect(find.text('Back in stock'), findsNothing);
      expect(visibleCodes(tester, frozenOrder), frozenOrder);
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
  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode([
      {
        'id': 's-a',
        'name': 'Aloe Vera',
        'code': 'ALOE',
        'color': 0xFF00ACC1,
        'icon': 'Leaf',
      },
      {
        'id': 's-b',
        'name': 'Basil Fresh',
        'code': 'BASL',
        'color': 0xFF4CAF50,
        'icon': 'Plant',
      },
      {
        'id': 's-c',
        'name': 'Cedar Wood',
        'code': 'CEDR',
        'color': 0xFFFF9800,
        'icon': 'Forest',
      },
      {
        'id': 's-d',
        'name': 'Cinnamon Bark',
        'code': 'CINN',
        'color': 0xFFE91E63,
        'icon': 'Leaf',
      },
    ]),
    'dosages': jsonEncode([
      {
        'id': 'd1',
        'strainId': 's-a',
        'amount': 2.0,
        'timestamp':
            now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 'd2',
        'strainId': 's-b',
        'amount': 2.0,
        'timestamp':
            now.subtract(const Duration(days: 4)).toIso8601String(),
      },
    ]),
    'effects': '[]',
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Future<KratomProvider> _seededProvider() async {
  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode([
      {
        'id': 's-alpha',
        'name': 'Alpha Strain',
        'code': 'ALPHA',
        'color': 0xFF00ACC1,
        'icon': 'Leaf',
      },
      {
        'id': 's-beta',
        'name': 'Beta Strain',
        'code': 'BETA',
        'color': 0xFF4CAF50,
        'icon': 'Plant',
      },
    ]),
    'dosages': '[]',
    'effects': '[]',
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Future<void> _pumpForm(WidgetTester tester, KratomProvider provider) async {
  final prefs = await SharedPreferences.getInstance();
  final theme = ThemeProvider(prefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: theme),
      ],
      child: MaterialApp(
        theme: theme.theme,
        home: const Scaffold(
          body: SizedBox(
            height: 800,
            child: AddDosageForm(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
