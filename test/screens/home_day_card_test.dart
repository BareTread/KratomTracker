import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_calendar_section.dart';

void main() {
  testWidgets('per-day bars scale against the visible week maximum',
      (tester) async {
    // Wednesday 12 Feb 2025; the visible week runs Mon 10 – Sun 16.
    final focused = DateTime(2025, 2, 12);
    final totals = <DateTime, double>{
      DateTime(2025, 2, 10): 5,
      DateTime(2025, 2, 11): 0,
      DateTime(2025, 2, 12): 10, // week max
      DateTime(2025, 2, 13): 2.5,
      DateTime(2025, 2, 14): 0,
      DateTime(2025, 2, 15): 0,
      DateTime(2025, 2, 16): 0,
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: Scaffold(
          body: HomeCalendarSection(
            focusedDay: focused,
            onDaySelected: (_) {},
            totalForDate: (d) => totals[d] ?? 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String keyFor(DateTime d) => 'home-day-bar-${d.year}-${d.month}-${d.day}';
    final wedSize = tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 12)))));
    final monSize = tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 10)))));
    final thuSize = tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 13)))));
    final tueSize = tester.getSize(find.byKey(ValueKey(keyFor(DateTime(2025, 2, 11)))));

    // The max day is tallest, and partial days scale below it.
    expect(wedSize.height, greaterThan(monSize.height));
    expect(monSize.height, greaterThan(thuSize.height));
    // A zero-grams day renders as a small dot, shorter than any real bar.
    expect(tueSize.height, lessThan(thuSize.height));
  });
}
