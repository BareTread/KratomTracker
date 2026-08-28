import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/date_utils.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home follows the wall clock across midnight', (tester) async {
    // Wednesday 15 Jan 2025 23:59 → Thursday 16 Jan 2025 00:01, same week
    // strip, so the newly selected day stays on screen.
    var now = DateTime(2025, 1, 15, 23, 59, 0);
    final provider = await _provider(
      dosages: [
        _dose('eve', DateTime(2025, 1, 15, 20), 2),
      ],
    );

    await _pumpHome(tester, provider, clock: () => now);

    expect(startOfDay(provider.selectedDate), DateTime(2025, 1, 15));
    expect(find.text('NO DOSES YET'), findsNothing);
    expect(_dayLabel('Wednesday, January 15, 2025, selected'), findsOneWidget);

    now = DateTime(2025, 1, 16, 0, 1, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(startOfDay(provider.selectedDate), DateTime(2025, 1, 16));
    expect(find.text('NO DOSES YET'), findsOneWidget);
    expect(_dayLabel('Thursday, January 16, 2025, selected'), findsOneWidget);

    final pager = find.byKey(const Key('home-day-pager'));
    final pageView = tester.widget<PageView>(pager);
    final controller = pageView.controller!;
    final childCount = (pageView.childrenDelegate as SliverChildBuilderDelegate)
        .estimatedChildCount!;
    expect(controller.page!.round(), 10000);
    expect(controller.page!.round(), lessThan(childCount));

    // Move off today; the new today must still be a valid page so tapping
    // it in the week strip can land on it (the old mapping put today at
    // _todayPage+1, which did not exist).
    controller.jumpToPage(9999);
    await tester.pumpAndSettle();
    expect(_dayLabel('Wednesday, January 15, 2025, selected'), findsOneWidget);

    await tester.tap(_dayLabel('Thursday, January 16, 2025').hitTestable().first);
    await tester.pumpAndSettle();

    expect(startOfDay(provider.selectedDate), DateTime(2025, 1, 16));
    expect(
      tester.widget<PageView>(pager).controller!.page!.round(),
      10000,
    );
    expect(_dayLabel('Thursday, January 16, 2025, selected'), findsOneWidget);
  });
}

Finder _dayLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

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
  required DateTime Function() clock,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: HomeScreen(clock: clock),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
