import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/report_screen.dart';
import 'package:kratom_tracker_plus/widgets/edit_dosage_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history groups and labels UTC imports by their local time',
      (tester) async {
    final timestamp = DateTime.parse('2024-06-05T23:30:00.000Z');
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
          'id': 'utc-dose',
          'strainId': 'strain-1',
          'amount': 2.0,
          'timestamp': timestamp.toIso8601String(),
        },
      ]),
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
    final local = timestamp.toLocal();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          home: const ReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('EEEE, MMM d').format(local)), findsOneWidget);
    expect(find.text(DateFormat('h:mm a').format(local)), findsOneWidget);
  });

  testWidgets('edit sheet rejects a future dose time without saving',
      (tester) async {
    final timestamp = DateTime.now().add(const Duration(hours: 3));
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
          'id': 'future-dose',
          'strainId': 'strain-1',
          'amount': 2.0,
          'timestamp': timestamp.toIso8601String(),
        },
      ]),
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          home: const ReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Strain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount (g)'), '9');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();

    expect(find.text('Dose time is in the future'), findsOneWidget);
    expect(find.text('Edit Dose'), findsOneWidget);
    expect(provider.dosages, hasLength(1));
    expect(provider.dosages.single.amount, 2.0);
    expect(provider.dosages.single.timestamp, timestamp);
  });

  testWidgets('edit sheet saves a comma decimal amount', (tester) async {
    final timestamp = DateTime.now().subtract(const Duration(hours: 3));
    final provider = await _seedReport(
      doseId: 'comma-dose',
      timestamp: timestamp,
    );
    await _pumpReport(tester, provider);
    await _openEdit(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (g)'),
      '1,5',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(provider.dosages, hasLength(1));
    expect(provider.dosages.single.amount, 1.5);
  });

  testWidgets('edit sheet ignores a second save tap', (tester) async {
    final timestamp = DateTime.now().subtract(const Duration(hours: 3));
    final provider = await _seedReport(
      doseId: 'double-dose',
      timestamp: timestamp,
    );
    await _pumpReport(tester, provider);
    await _openEdit(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (g)'),
      '4',
    );
    await tester.pump();
    final stamp = provider.lastMutationStamp;
    final onPressed =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(provider.lastMutationStamp, stamp + 1);
    expect(provider.dosages, hasLength(1));
    expect(provider.dosages.single.amount, 4.0);
  });

  testWidgets('orphan strain opens without asserting and can be reassigned',
      (tester) async {
    final provider = await _openOrphanEditor(tester);

    expect(find.text('Unknown strain'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OTHR — Other Strain').last);
    await tester.pumpAndSettle();
    expect(find.text('Select a strain'), findsNothing);
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(provider.dosages.single.strainId, 'strain-2');
  });

  testWidgets('orphan strain cannot be saved without reassignment',
      (tester) async {
    final provider = await _openOrphanEditor(tester);
    final stamp = provider.lastMutationStamp;

    expect(find.text('Unknown strain'), findsOneWidget);
    expect(find.text('Select a strain'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Dose'), findsOneWidget);
    expect(find.text('Select a strain'), findsOneWidget);
    expect(provider.lastMutationStamp, stamp);
    expect(provider.dosages.single.strainId, 'strain-1');
    expect(provider.dosages.single.amount, 2.0);
  });
}

Future<KratomProvider> _seedReport({
  required String doseId,
  required DateTime timestamp,
  double amount = 2.0,
  List<Map<String, Object?>> extraStrains = const [],
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
      ...extraStrains,
    ]),
    'dosages': jsonEncode([
      {
        'id': doseId,
        'strainId': 'strain-1',
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
      },
    ]),
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Future<void> _pumpReport(WidgetTester tester, KratomProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: const ReportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEdit(WidgetTester tester) async {
  await tester.tap(find.text('Test Strain'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

Future<KratomProvider> _openOrphanEditor(WidgetTester tester) async {
  final timestamp = DateTime.now().subtract(const Duration(hours: 3));
  final provider = await _seedReport(
    doseId: 'dose-1',
    timestamp: timestamp,
    extraStrains: const [
      {
        'id': 'strain-2',
        'name': 'Other Strain',
        'code': 'OTHR',
        'color': 0xFF7CB342,
        'icon': 'Leaf',
      },
    ],
  );

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditDosageForm(
                      dosage: Dosage(
                        id: 'dose-1',
                        strainId: 'gone',
                        amount: 2,
                        timestamp: timestamp,
                      ),
                    ),
                  );
                },
                child: const Text('Open edit'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open edit'));
  await tester.pumpAndSettle();
  return provider;
}
