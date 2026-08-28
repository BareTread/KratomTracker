import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/report_screen.dart';
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
}
