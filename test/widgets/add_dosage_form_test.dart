import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/add_dosage_form.dart';
import 'package:kratom_tracker_plus/widgets/undo_snack_bar.dart';
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
      expect(find.text('Search strains'), findsNothing);
      expect(find.text('LAST'), findsOneWidget);
      expect(find.text('30 DAYS'), findsOneWidget);
      expect(find.byKey(DoseAmountControl.fieldKey), findsOneWidget);
    });

    testWidgets('amount is prefilled from the strain last dose, not the average',
        (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-alpha', code: 'ALPHA', name: 'Alpha Strain'),
        ],
        dosages: [
          _dose(id: 'd-new', strainId: 's-alpha', amount: 3.5, timestamp: _daysAgo(2)),
          _dose(id: 'd-old', strainId: 's-alpha', amount: 4.5, timestamp: _daysAgo(5)),
        ],
      );
      await _pumpForm(tester, provider);
      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pump();

      expect(_amountText(tester), '3.5');
      expect(find.text('Log ALPHA 3.5g'), findsOneWidget);
    });

    testWidgets('no recent-amount chips: the strain prefill is the one guess',
        (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-sr', code: 'SR', name: 'Super Red'),
        ],
        dosages: [
          _dose(id: 'd4', strainId: 's-sr', amount: 16.6, timestamp: _daysAgo(1)),
          _dose(id: 'd3', strainId: 's-sr', amount: 16.3, timestamp: _daysAgo(2)),
          _dose(id: 'd2', strainId: 's-sr', amount: 15, timestamp: _daysAgo(3)),
        ],
      );
      await _pumpForm(tester, provider);
      await tester.tap(find.byKey(const Key('dose-strain-s-sr')));
      await tester.pump();

      expect(find.text('Log SR 16.6g'), findsOneWidget);
      expect(find.text('16.3g'), findsNothing);
      expect(find.text('15g'), findsNothing);
    });

    testWidgets('stepper changes the amount by 0.1 and clamps', (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);
      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pump();

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

    testWidgets('changing strain re-prefills and drops a typed amount',
        (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);
      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pump();

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

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();

      final created = provider.dosages.singleWhere(
        (dose) => !beforeIds.contains(dose.id),
      );
      expect(created.amount, 2.5);
      expect(find.text('Logged ALPHA · 2.5g'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.elevation, 0);
      expect(bar.duration, undoSnackBarDuration);
      expect(bar.persist, isFalse, reason: 'must time out, not wait for a tap');
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(bar.margin, const EdgeInsets.fromLTRB(16, 0, 88, 24));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(provider.dosages.map((dose) => dose.id).toSet(), beforeIds);
    });
  });

  group('strain choice', () {
    testWidgets('the FAB launch picks nothing: blank amount, Log disabled',
        (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);

      expect(find.text('Pick a strain'), findsOneWidget);
      expect(_amountText(tester), '');
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pump();
      expect(find.text('Log ALPHA 2.5g'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a launch naming a strain selects and prefills it',
        (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider, preselectedStrainId: 's-beta');

      expect(_amountText(tester), '1');
      expect(find.text('Log BETA 1g'), findsOneWidget);
    });

    testWidgets('ledger: rotation in rest order, then 30-day sleepers newest first',
        (tester) async {
      final provider = await _provider(
        strains: [
          _strain(id: 's-a', code: 'AAA', name: 'Ash'),
          _strain(id: 's-b', code: 'BBB', name: 'Birch'),
          _strain(id: 's-c', code: 'CCC', name: 'Cedar'),
          _strain(id: 's-d', code: 'DDD', name: 'Dogwood'),
          _strain(id: 's-e', code: 'EEE', name: 'Elm'),
        ],
        dosages: [
          _dose(id: 'd1', strainId: 's-a', amount: 2, timestamp: _daysAgo(40)),
          _dose(id: 'd2', strainId: 's-b', amount: 2, timestamp: _daysAgo(100)),
          _dose(id: 'd3', strainId: 's-d', amount: 2.5, timestamp: _daysAgo(2)),
          _dose(id: 'd4', strainId: 's-e', amount: 3, timestamp: _daysAgo(10)),
        ],
      );
      final semantics = tester.ensureSemantics();
      await _pumpForm(tester, provider);

      // Rotation keeps the provider's rest order (EEE rested longer than
      // DDD); the sleepers run most recent first, never-used last.
      expect(
        _visibleCodes(tester, ['AAA', 'BBB', 'CCC', 'DDD', 'EEE']),
        ['EEE', 'DDD', 'AAA', 'BBB', 'CCC'],
      );
      expect(
        find.byKey(const Key('add-dose-resting-divider')),
        findsOneWidget,
      );
      for (final label in ['2d ago', '2.5g', '10d ago', '3g', '1mo ago', '3mo ago', 'never']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.bySemanticsLabel('DDD, Dogwood, last taken 2d ago, 2.5g in 30 days'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('when', () {
    testWidgets('saved time freezes at sheet open, not save time',
        (tester) async {
      final provider = await _leadProvider();
      final openMoment = DateTime.now();
      await _pumpForm(tester, provider);

      expect(_dateChipText(tester), 'Today');
      final beforeIds = provider.dosages.map((dose) => dose.id).toSet();
      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.pump();
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

    testWidgets('a past Home day keeps its date and asks for the time',
        (tester) async {
      final provider = await _seededProvider();
      final past = DateTime(2024, 6, 15);
      provider.setSelectedDate(past);
      await _pumpForm(tester, provider);

      expect(_dateChipText(tester), 'Jun 15, 2024');
      expect(_chipText(tester), 'Set time');

      await tester.tap(find.byKey(const Key('dose-strain-s-beta')));
      await tester.pump();
      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '1.5');
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Set time'), findsOneWidget);

      // Log asks for the time instead of inventing one.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await _enterTime(tester, 8, 30);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log BETA 1.5g'));
      await tester.pumpAndSettle();

      final dose = provider.dosages.single;
      expect(dose.timestamp, DateTime(2024, 6, 15, 8, 30));
      expect(find.text('Logged BETA · 1.5g · Jun 15, 2024, 08:30'), findsOneWidget);
    });

    testWidgets('Now resets a past day to today, live', (tester) async {
      final provider = await _seededProvider();
      provider.setSelectedDate(DateTime(2024, 6, 15));
      await _pumpForm(tester, provider);

      await tester.tap(find.byKey(const Key('add-dose-now')));
      await tester.pump();

      expect(_dateChipText(tester), 'Today');
      expect(_chipText(tester), isNot('Set time'));
    });

    testWidgets('-1h logs an hour before the tap and names the time',
        (tester) async {
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);
      final beforeIds = provider.dosages.map((dose) => dose.id).toSet();

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.tap(find.byKey(const Key('add-dose-ago-60')));
      await tester.pump();
      final target = DateTime.now().subtract(const Duration(hours: 1));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();

      final created = provider.dosages.singleWhere(
        (dose) => !beforeIds.contains(dose.id),
      );
      expect(
        created.timestamp.difference(target).inMinutes.abs(),
        lessThan(2),
      );
      expect(
        find.textContaining(RegExp(r'^Logged ALPHA · 2\.5g · ')),
        findsOneWidget,
      );
    });

    testWidgets('offsets replace each other, and a repeat tap is Now again',
        (tester) async {
      final provider = await _leadProvider();
      final openMoment = DateTime.now();
      await _pumpForm(tester, provider);
      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));

      await tester.tap(find.byKey(const Key('add-dose-ago-30')));
      await tester.tap(find.byKey(const Key('add-dose-ago-60')));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();
      final first = provider.dosages.firstWhere((d) => d.amount == 2.5 && d.id != 'd-a');
      expect(
        first.timestamp
            .difference(openMoment.subtract(const Duration(hours: 1)))
            .inSeconds
            .abs(),
        lessThan(5),
        reason: '-30m then -1h is one hour back, not ninety minutes',
      );

      await tester.tap(find.text('open-sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dose-strain-s-beta')));
      await tester.tap(find.byKey(const Key('add-dose-ago-60')));
      await tester.tap(find.byKey(const Key('add-dose-ago-60')));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log BETA 1g'));
      await tester.pumpAndSettle();
      final second = provider.dosages.firstWhere((d) => d.amount == 1 && d.id != 'd-b');
      expect(second.timestamp.difference(openMoment).inSeconds.abs(), lessThan(5));
      expect(find.text('Logged BETA · 1g'), findsOneWidget);
    });

    testWidgets('picking the opening day with no time is Now again',
        (tester) async {
      final provider = await _seededProvider();
      provider.setSelectedDate(DateTime(2024, 6, 15));
      await _pumpForm(tester, provider);
      expect(_chipText(tester), 'Set time');

      await tester.tap(find.byKey(const Key('add-dose-date-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        const DefaultMaterialLocalizations().formatCompactDate(DateTime.now()),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing, reason: 'no time picker chained');
      expect(_dateChipText(tester), 'Today');
      expect(_chipText(tester), isNot('Set time'));
    });

    testWidgets('an explicit day beats the Home page day', (tester) async {
      final provider = await _seededProvider();
      provider.setSelectedDate(DateTime(2024, 6, 15));
      await _pumpForm(tester, provider, day: DateTime.now());

      expect(_dateChipText(tester), 'Today');
      expect(_chipText(tester), isNot('Set time'));
    });

    testWidgets('a time still ahead today lands on yesterday, out loud',
        (tester) async {
      final now = DateTime.now();
      final int hour;
      final int minute;
      if (now.hour <= 21) {
        (hour, minute) = (now.hour + 2, 0);
      } else if (now.hour == 22 || now.minute < 50) {
        (hour, minute) = (23, 59);
      } else {
        return; // Within ten minutes of midnight nothing later fits today.
      }
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);
      final beforeIds = provider.dosages.map((dose) => dose.id).toSet();

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.tap(find.byKey(const Key('add-dose-time-chip')));
      await tester.pumpAndSettle();
      await _enterTime(tester, hour, minute);

      expect(_dateChipText(tester), 'Yesterday');
      expect(find.byKey(const Key('add-dose-rolled-back')), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log ALPHA 2.5g'));
      await tester.pumpAndSettle();

      final created = provider.dosages.singleWhere(
        (dose) => !beforeIds.contains(dose.id),
      );
      expect(
        created.timestamp,
        DateTime(now.year, now.month, now.day - 1, hour, minute),
      );
      final time = const DefaultMaterialLocalizations().formatTimeOfDay(
        TimeOfDay(hour: hour, minute: minute),
        alwaysUse24HourFormat: true,
      );
      expect(find.text('Logged ALPHA · 2.5g · yesterday $time'), findsOneWidget);
    });

    testWidgets('naming today for a time still ahead blocks Log',
        (tester) async {
      final now = DateTime.now();
      if (now.hour > 21) return; // Needs room for a later time today.
      final provider = await _leadProvider();
      await _pumpForm(tester, provider);

      await tester.tap(find.byKey(const Key('dose-strain-s-alpha')));
      await tester.tap(find.byKey(const Key('add-dose-time-chip')));
      await tester.pumpAndSettle();
      await _enterTime(tester, now.hour + 2, 0);
      expect(_dateChipText(tester), 'Yesterday');

      await tester.tap(find.byKey(const Key('add-dose-date-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        const DefaultMaterialLocalizations().formatCompactDate(now),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(_dateChipText(tester), 'Today');
      expect(find.byKey(const Key('add-dose-future')), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });
  });

  group('dayForPickedTime', () {
    test('a time already past today stays today', () {
      final r = dayForPickedTime(
        const TimeOfDay(hour: 9, minute: 10),
        now: DateTime(2026, 11, 25, 14),
      );
      expect(r.day, DateTime(2026, 11, 25));
      expect(r.rolledBack, isFalse);
    });

    test('the current minute is now, not ahead', () {
      final r = dayForPickedTime(
        const TimeOfDay(hour: 14, minute: 0),
        now: DateTime(2026, 11, 25, 14, 0, 40),
      );
      expect(r.day, DateTime(2026, 11, 25));
      expect(r.rolledBack, isFalse);
    });

    test('a time still ahead moves to yesterday, across a month edge', () {
      final r = dayForPickedTime(
        const TimeOfDay(hour: 22, minute: 0),
        now: DateTime(2026, 3, 1, 1, 15),
      );
      expect(r.day, DateTime(2026, 2, 28));
      expect(r.rolledBack, isTrue);
    });
  });

  group('stock shelves', () {
    Future<KratomProvider> partitionSeed() async {
      final provider = await searchSeed();
      await provider.setStrainInStock('s-d', inStock: false);
      await provider.setStrainInStock('s-a', inStock: false);
      return provider;
    }

    testWidgets('out-of-stock strains wait behind the Out tab',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);

      const all = ['ALOE', 'BASL', 'CEDR', 'CINN'];
      expect(_visibleCodes(tester, all), ['BASL', 'CEDR']);
      expect(find.text('Out · 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-dose-out-of-stock')));
      await tester.pumpAndSettle();
      // Most recently used first, never used last.
      expect(_visibleCodes(tester, all), ['ALOE', 'CINN']);
    });

    testWidgets('an out-of-stock pick offers Back in stock, then follows it',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider);
      expect(find.text('Back in stock'), findsNothing);

      await tester.tap(find.byKey(const Key('add-dose-out-of-stock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dose-strain-s-d')));
      await tester.pumpAndSettle();

      expect(find.text('CINN is out of stock'), findsOneWidget);
      expect(find.text('Back in stock'), findsOneWidget);
      await tester.enterText(find.byKey(DoseAmountControl.fieldKey), '2');
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Back in stock'));
      await tester.pumpAndSettle();

      expect(provider.getStrain('s-d')!.inStock, isTrue);
      expect(find.text('Back in stock'), findsNothing);
      expect(find.text('Out · 1'), findsOneWidget);
      expect(
        _visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['BASL', 'CEDR', 'CINN'],
      );
      expect(find.text('Log CINN 2g'), findsOneWidget);
    });

    testWidgets('same-day sleepers sort by the clock, not by code',
        (tester) async {
      final now = DateTime.now();
      final provider = await _provider(
        strains: [
          _strain(id: 's-a', code: 'AAA', name: 'Ash'),
          _strain(id: 's-b', code: 'BBB', name: 'Birch'),
        ],
        dosages: [
          _dose(
            id: 'd1',
            strainId: 's-a',
            amount: 2,
            timestamp: DateTime(now.year, now.month, now.day - 40, 8),
          ),
          _dose(
            id: 'd2',
            strainId: 's-b',
            amount: 2,
            timestamp: DateTime(now.year, now.month, now.day - 40, 20),
          ),
        ],
      );
      await _pumpForm(tester, provider);

      expect(_visibleCodes(tester, ['AAA', 'BBB']), ['BBB', 'AAA']);
    });

    testWidgets('a launch naming an out-of-stock strain opens the Out tab',
        (tester) async {
      final provider = await partitionSeed();
      await _pumpForm(tester, provider, preselectedStrainId: 's-d');

      expect(
        _visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['ALOE', 'CINN'],
      );
      expect(find.text('Back in stock'), findsOneWidget);
    });

    testWidgets('all in stock: no Out tab', (tester) async {
      final provider = await searchSeed();
      await _pumpForm(tester, provider);

      expect(find.byKey(const Key('add-dose-out-of-stock')), findsNothing);
      expect(
        _visibleCodes(tester, ['ALOE', 'BASL', 'CEDR', 'CINN']),
        ['BASL', 'ALOE', 'CEDR', 'CINN'],
      );
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

String _dateChipText(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('add-dose-date-chip')),
          matching: find.byType(Text),
        ),
      )
      .data!;
}

/// Types [hour]:[minute] into an open time picker via its keyboard mode.
Future<void> _enterTime(WidgetTester tester, int hour, int minute) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
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
  DateTime? day,
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
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            alwaysUse24HourFormat: true,
          ),
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
                      day: day,
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
