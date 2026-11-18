// Calm save: a dose that appears while its day is on screen (just logged)
// settles its mark in once; rows present at the day's first build do not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_dosage_list.dart';
import 'package:kratom_tracker_plus/widgets/strain_mark.dart';

const _strain =
    Strain(id: 's1', name: 'Amber', code: 'AMB', color: 0xFF43A047, icon: 'leaf');

Dosage _dose(String id, DateTime t) =>
    Dosage(id: id, strainId: 's1', amount: 15, timestamp: t);

Widget _list(List<Dosage> dosages) => MaterialApp(
      theme: ThemeProvider.darkTheme,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: HomeDosageList(
            dosages: dosages,
            strainsById: const {'s1': _strain},
            isToday: false,
          ),
        ),
      ),
    );

/// Opacity of the settle fade directly above each strain mark, row order.
List<double> _markOpacities(WidgetTester tester) => tester
    .widgetList<StrainMark>(find.byType(StrainMark))
    .map((mark) {
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byWidget(mark),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      return fade.opacity.value;
    })
    .toList();

void main() {
  testWidgets('only a just-logged dose settles its mark, once',
      (tester) async {
    // A day no other test builds, so its first build records quietly.
    final day = DateTime(2019, 3, 4);
    final first = [_dose('m1', day.add(const Duration(hours: 8)))];

    await tester.pumpWidget(_list(first));
    await tester.pump();
    expect(_markOpacities(tester), [1.0]);

    await tester.pumpWidget(
      _list([...first, _dose('m2', day.add(const Duration(hours: 12)))]),
    );
    final mid = _markOpacities(tester);
    expect(mid[0], 1.0);
    expect(mid[1], lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 250));
    expect(_markOpacities(tester), [1.0, 1.0]);

    // A rebuild does not replay it.
    await tester.pumpWidget(
      _list([...first, _dose('m2', day.add(const Duration(hours: 12)))]),
    );
    expect(_markOpacities(tester), [1.0, 1.0]);
  });
}
