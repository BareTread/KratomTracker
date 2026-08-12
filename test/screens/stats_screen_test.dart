import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/stats_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(KratomProvider provider) {
  return ChangeNotifierProvider<KratomProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: ThemeProvider.darkTheme,
      home: const Scaffold(body: StatsScreen()),
    ),
  );
}

Future<KratomProvider> _provider() async {
  SharedPreferences.setMockInitialValues({});
  return KratomProvider.create(await SharedPreferences.getInstance());
}

void main() {
  testWidgets('rest-day counts pluralise for 0, 1 and many', (tester) async {
    final provider = await _provider();
    await provider.addStrain('Maeng Da', 'MD', 0xFF00ACC1, 'Leaf');
    final strainId = provider.strains.first.id;

    // Empty 30d range: current streak 0, longest rest streak 29 — today has
    // not finished, so it is not yet a completed rest day.
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();
    expect(find.text('0 days'), findsOneWidget);
    expect(find.text('29 days'), findsOneWidget);

    // A single dose today: currentStreak = 1, longestRest = 29.
    final now = DateTime.now();
    await provider.addDosage(
      strainId,
      2.5,
      DateTime(now.year, now.month, now.day, 8),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('29 days'), findsOneWidget);
  });

  testWidgets('builds with zero data and shows empty states, no NaN',
      (tester) async {
    final provider = await _provider();
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    // Three chart sections each show their empty state.
    expect(find.text('No doses in this range yet.'), findsNWidgets(2));
    expect(find.text('No strain usage in this range yet.'), findsOneWidget);
    // Headline values render as 0.0g / 0 without throwing.
    expect(find.text('0.0g'), findsWidgets);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('builds with seeded data across a range boundary', (tester) async {
    final provider = await _provider();
    await provider.addStrain('Maeng Da', 'MD', 0xFF00ACC1, 'Leaf');
    final strainId = provider.strains.first.id;

    final now = DateTime.now();
    // One dose inside the default 30d window, one well outside it.
    await provider.addDosage(
      strainId,
      2.5,
      DateTime(now.year, now.month, now.day, 8),
    );
    await provider.addDosage(
      strainId,
      3.0,
      now.subtract(const Duration(days: 35)),
    );

    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    // Default range is 30d: only the 2.5g dose is inside.
    expect(find.text('2.5g'), findsWidgets);

    // Switch to All: both doses are included.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('5.5g'), findsWidgets);
  });
}
