import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/main.dart' as app;
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home_screen.dart';
import 'package:kratom_tracker_plus/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real app boots to home with empty preferences', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _bootAndExercise(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Herbal Tracker+',
    );
  });

  testWidgets('real app boots with a realistic 18-month dataset',
      (tester) async {
    SharedPreferences.setMockInitialValues(_realisticDataset());

    await _bootAndExercise(tester);
  });

  testWidgets('real app recovers from corrupt persisted values',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'strains': 'not json',
      'dosages': '[{broken',
      'settings': '{}',
    });

    await _bootAndExercise(tester);
    // Empty today: young vine shoot, not the past-day empty-state CTA.
    expect(find.text('NO DOSES YET'), findsOneWidget);
    expect(find.text('No doses recorded'), findsNothing);
  });

  testWidgets('prefs load failure shows the existing error surface',
      (tester) async {
    await tester.pumpWidget(
      app.AppBootstrap(
        loadPrefs: () async => throw Exception('prefs unavailable'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Failed to start'), findsOneWidget);
    expect(find.textContaining('prefs unavailable'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final themeCase in [
    (name: 'light', darkMode: false, brightness: Brightness.light),
    (name: 'dark', darkMode: true, brightness: Brightness.dark),
  ]) {
    testWidgets(
        'real app boots in ${themeCase.name} theme with AppColors registered',
        (tester) async {
      SharedPreferences.setMockInitialValues({'darkMode': themeCase.darkMode});

      await _bootAndExercise(tester);

      final context = tester.element(find.byType(HomeScreen));
      final theme = Theme.of(context);
      expect(theme.brightness, themeCase.brightness);
      expect(theme.extension<AppColors>(), isNotNull);
    });
  }
}

Future<void> _bootAndExercise(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  // MaterialApp rebuilds MediaQuery from the view, so an outer wrap is not
  // enough. Drive disableAnimations via the platform dispatcher so the live
  // vine tail stays static and pumpAndSettle can finish.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(app.AppBootstrap(prefs: prefs));

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(
    Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
    ThemeProvider.darkTheme.scaffoldBackgroundColor,
  );
  expect(tester.takeException(), isNull);

  await tester.pump(const Duration(seconds: 3));
  expect(find.byType(HomeScreen), findsOneWidget);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );

  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.text('Home'), findsOneWidget);
  expect(find.byType(ErrorWidget), findsNothing);
  expect(tester.takeException(), isNull);

  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );

  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.byType(ErrorWidget), findsNothing);
  expect(tester.takeException(), isNull);
}

Map<String, Object> _realisticDataset() {
  final now = DateTime.now();
  final strains = List.generate(
    4,
    (index) => {
      'id': 'strain-$index',
      'name': 'Seeded Strain $index',
      'code': 'S$index',
      'color': [
        0xFF00ACC1,
        0xFF4CAF50,
        0xFFFF9800,
        0xFF9C27B0,
      ][index],
      'icon': 'Leaf',
    },
  );
  final dosages = List.generate(200, (index) {
    final daysAgo = (index * 547 / 199).round();
    return {
      'id': 'dose-$index',
      'strainId': 'strain-${index % strains.length}',
      'amount': 1.0 + (index % 8) * 0.5,
      'timestamp': now
          .subtract(Duration(days: daysAgo, hours: index % 12))
          .toIso8601String(),
      if (index % 11 == 0) 'notes': 'Seeded note $index',
    };
  });

  return {
    'strains': jsonEncode(strains),
    'dosages': jsonEncode(dosages),
    'settings': jsonEncode({
      'enableNotifications': false,
      'dailyLimit': 12.0,
      'enableToleranceTracking': true,
      'toleranceBreakInterval': 14,
      'measurementUnit': 'g',
      'performanceMode': false,
    }),
    'user_name': 'Seed User',
  };
}
