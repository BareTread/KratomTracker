import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_calendar_section.dart';
import 'package:kratom_tracker_plus/screens/home_screen.dart';
import 'package:kratom_tracker_plus/theme/app_theme.dart';
import 'package:kratom_tracker_plus/widgets/add_dosage_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty today renders a young vine with NOW, not the past empty state',
      (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider);

    // Today with no doses: young shoot + NOW tip, not the past-day empty CTA.
    expect(find.text('No doses recorded'), findsNothing);
    expect(find.text('NO DOSES YET'), findsOneWidget);
    expect(find.text('tap + to log the first'), findsOneWidget);
    expect(find.byKey(const Key('home-empty-add-dose')), findsNothing);
  });

  testWidgets('Add Dose FAB opens the add-dose sheet', (tester) async {
    final provider = await _provider();
    await _pumpHome(tester, provider);

    await tester.tap(find.byKey(const Key('home-fab')));
    await tester.pumpAndSettle();

    expect(find.byType(AddDosageForm), findsOneWidget);
    expect(find.text('Select Strain'), findsOneWidget);
  });

  testWidgets('seeded doses render in chronological order', (tester) async {
    final now = DateTime.now();
    final provider = await _provider(
      dosages: [
        _dose('late', DateTime(now.year, now.month, now.day, 20), 3),
        _dose('early', DateTime(now.year, now.month, now.day, 7), 1),
        _dose('middle', DateTime(now.year, now.month, now.day, 13), 2),
      ],
    );

    await _pumpHome(tester, provider, tall: true);

    // Gutter times are "h:mm" (ampm sits on the line below).
    String at(int hour) =>
        DateFormat('h:mm').format(DateTime(now.year, now.month, now.day, hour));
    final earlyY = tester.getCenter(find.text(at(7))).dy;
    final middleY = tester.getCenter(find.text(at(13))).dy;
    final lateY = tester.getCenter(find.text(at(20))).dy;
    expect(earlyY, lessThan(middleY));
    expect(middleY, lessThan(lateY));
  });

  testWidgets('light theme resolves the calendar surface colour',
      (tester) async {
    final provider = await _provider();

    await _pumpHome(tester, provider, theme: ThemeProvider.lightTheme);

    final container = tester.widget<Container>(
      find.byKey(const Key('home-day-card-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.light.surfaceRaised);
    expect(decoration.color, isNot(AppColors.dark.surfaceRaised));
  });

  testWidgets('month grid aligns day 1 with its weekday column',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeProvider.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: HomeCalendarSection(
            focusedDay: DateTime(2025, 2, 15),
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('February 2025'));
    await tester.pumpAndSettle();

    final dayOne = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Saturday, February 1, 2025',
    );
    expect(dayOne, findsOneWidget);
    final saturdayHeader = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == 'Sat' &&
          widget.style?.fontSize == 11,
    );
    expect(saturdayHeader, findsOneWidget);
    expect(
      tester.getCenter(dayOne).dx,
      closeTo(tester.getCenter(saturdayHeader).dx, 0.5),
    );
  });
}

Future<KratomProvider> _provider({List<Map<String, Object?>>? dosages}) async {
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
    'dosages': jsonEncode(dosages ?? const []),
    'effects': '[]',
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Map<String, Object?> _dose(
  String note,
  DateTime timestamp,
  double amount,
) =>
    {
      'id': 'dose-$note',
      'strainId': 'strain-1',
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'notes': note,
    };

Future<void> _pumpHome(
  WidgetTester tester,
  KratomProvider provider, {
  ThemeData? theme,
  bool tall = false,
}) async {
  if (tall) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: theme ?? ThemeProvider.darkTheme,
        // Live vine tail is a looping ticker; keep it static in widget tests
        // so pumpAndSettle can finish.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
