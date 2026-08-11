import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

    testWidgets('header is a single title with no search or captions',
        (tester) async {
      final provider = await _seededProvider();
      await _pumpForm(tester, provider);

      expect(find.text('Select Strain'), findsOneWidget);
      expect(find.textContaining('Least recently used'), findsNothing);
      expect(find.textContaining('Bar fills'), findsNothing);
      expect(find.text('Search strains'), findsNothing);
      // No free-text search field on the picker step.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('amount is prefilled from the strain usual dose',
        (tester) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'strains': jsonEncode([
          {
            'id': 's-alpha',
            'name': 'Alpha Strain',
            'code': 'ALPHA',
            'color': 0xFF00ACC1,
            'icon': 'Leaf',
          },
        ]),
        'dosages': jsonEncode([
          {
            'id': 'd1',
            'strainId': 's-alpha',
            'amount': 3.5,
            'timestamp':
                now.subtract(const Duration(days: 2)).toIso8601String(),
          },
          {
            'id': 'd2',
            'strainId': 's-alpha',
            'amount': 4.5,
            'timestamp':
                now.subtract(const Duration(days: 5)).toIso8601String(),
          },
        ]),
        'effects': '[]',
      });
      final provider =
          await KratomProvider.create(await SharedPreferences.getInstance());
      await _pumpForm(tester, provider);

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      final amountField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Amount'),
      );
      // avg of 3.5 and 4.5 = 4.0
      expect(amountField.controller?.text, '4');
    });

    testWidgets('saved time freezes at sheet open, not save time',
        (tester) async {
      final provider = await _seededProvider();
      final openMoment = DateTime.now();
      await _pumpForm(tester, provider);

      // Read the frozen time shown on the details step before saving.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      final frozenLabel = DateFormat('h:mm a').format(openMoment);
      expect(find.text(frozenLabel), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '2.0',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Dose'));
      await tester.pumpAndSettle();

      expect(provider.dosages, hasLength(1));
      final dose = provider.dosages.single;
      // Saved time should be near openMoment (captured at sheet open).
      final delta = dose.timestamp.difference(openMoment).inSeconds.abs();
      expect(
        delta,
        lessThan(5),
        reason:
            'expected frozen open time (~$openMoment) but got ${dose.timestamp}',
      );
    });

    testWidgets('Now pill snaps the time field to the current time',
        (tester) async {
      final provider = await _seededProvider();
      // Seed a past selected day so the frozen open-time-of-day is painted
      // onto a non-today date. After tapping Now the time-of-day should jump
      // to wall-clock now (date stays on the selected day).
      final past = DateTime(2024, 6, 15, 8, 0);
      provider.setSelectedDate(past);
      await _pumpForm(tester, provider);

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      // Confirm the time is still the frozen open time-of-day on the past day.
      expect(find.text('Jun 15, 2024'), findsOneWidget);

      final beforeNow = DateTime.now();
      await tester.tap(find.byKey(const Key('add-dose-now-pill')));
      await tester.pump();

      final expectedLabel = DateFormat('h:mm a').format(beforeNow);
      final altLabel = DateFormat('h:mm a')
          .format(beforeNow.add(const Duration(minutes: 1)));
      final labels = [expectedLabel, altLabel];
      expect(
        labels.any((l) => find.text(l).evaluate().isNotEmpty),
        isTrue,
        reason: 'expected one of $labels after tapping Now',
      );
      // Date stays on the selected day; only time-of-day snaps.
      expect(find.text('Jun 15, 2024'), findsOneWidget);
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
