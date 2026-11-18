import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/theme/app_theme.dart';
import 'package:kratom_tracker_plus/domain/date_utils.dart';
import 'package:kratom_tracker_plus/widgets/day_sprig.dart';

SprigDose dose(double grams, [int hour = 12, int minute = 0]) => SprigDose(
      time: DateTime(2026, 11, 16, hour, minute),
      grams: grams,
      color: const Color(0xFF336633),
    );

DaySprigPainter painter(List<SprigDose> doses) => DaySprigPainter(
      doses: doses,
      scaleGrams: 8,
      rest: true,
      stemColor: Colors.grey,
      brightness: Brightness.light,
    );

Future<void> pump(
  WidgetTester tester,
  ThemeData theme,
  List<SprigDose> doses, {
  Size size = const Size(40, 90),
  String? label,
}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: DaySprig(
              doses: doses,
              scaleGrams: 8,
              semanticLabel: label,
              size: size,
            ),
          ),
        ),
      ),
    );

void main() {
  group('sprigLeafLength', () {
    test('zero, negative and NaN grams give 0', () {
      for (final g in [0.0, -2.0, double.nan]) {
        expect(sprigLeafLength(g, scaleGrams: 8, maxLength: 20), 0);
      }
    });

    test('scaleGrams maps to maxLength', () {
      expect(sprigLeafLength(8, scaleGrams: 8, maxLength: 20), 20);
    });

    test('half the scale gives half the length (linear)', () {
      expect(sprigLeafLength(4, scaleGrams: 8, maxLength: 20), 10);
    });

    test('doses above the scale clamp to maxLength', () {
      expect(sprigLeafLength(16, scaleGrams: 8, maxLength: 20), 20);
    });

    test('a tiny dose is floored at minLength', () {
      expect(
        sprigLeafLength(0.1, scaleGrams: 8, maxLength: 20, minLength: 5),
        5,
      );
    });

    test('minLength above maxLength never exceeds maxLength', () {
      expect(
        sprigLeafLength(0.1, scaleGrams: 8, maxLength: 20, minLength: 30),
        20,
      );
    });

    test('scaleGrams 0 treats the dose as its own scale', () {
      expect(sprigLeafLength(3, scaleGrams: 0, maxLength: 20), 20);
    });
  });

  group('sprigLeafPath', () {
    // getBounds() returns the control-point hull, wider than the ink; walk
    // the curve for the tight extent.
    Rect tight(Path path) {
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final metric in path.computeMetrics()) {
        for (var i = 0; i <= 200; i++) {
          final p = metric.getTangentForOffset(metric.length * i / 200)!.position;
          minX = math.min(minX, p.dx);
          minY = math.min(minY, p.dy);
          maxX = math.max(maxX, p.dx);
          maxY = math.max(maxY, p.dy);
        }
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    test('angle 0 spans ~length in x and ~length*aspect in y', () {
      final bounds = tight(sprigLeafPath(Offset.zero, 20, 0));
      expect(bounds.width, closeTo(20, 20 * 0.15));
      expect(
        bounds.height,
        closeTo(20 * sprigLeafAspect, 20 * sprigLeafAspect * 0.15),
      );
    });

    test('angle -pi/2 points the tip above the base', () {
      final bounds = tight(sprigLeafPath(Offset.zero, 20, -math.pi / 2));
      expect(bounds.top, closeTo(-20, 0.5));
      expect(bounds.bottom, closeTo(0, 0.5));
    });
  });

  group('sprigLeafColors', () {
    test('fill is the raw strain colour, edge is the legible clamp', () {
      const strain = Color(0xFFEEDD44);
      for (final b in Brightness.values) {
        final colors = sprigLeafColors(strain, b);
        expect(colors.fill, strain);
        expect(colors.edge, legibleStrainColor(strain, b));
      }
    });
  });

  group('sprigScaleFor', () {
    test('returns the largest single dose across days', () {
      expect(
        sprigScaleFor([
          [dose(3), dose(7.5)],
          [dose(2)],
          [dose(9.4), dose(1)],
        ]),
        9.4,
      );
    });

    test('empty input and empty days give 0', () {
      expect(sprigScaleFor(const []), 0);
      expect(sprigScaleFor(const [[], []]), 0);
    });
  });

  group('daySprigLabel', () {
    final day = DateTime(2026, 11, 16);

    test('three doses name the count and total grams', () {
      expect(
        daySprigLabel(day, [dose(20), dose(20), dose(9.4)]),
        'Mon 16 Nov, 3 doses, 49.4 g',
      );
    });

    test('one dose uses the singular and trims ".0"', () {
      expect(daySprigLabel(day, [dose(6)]), 'Mon 16 Nov, 1 dose, 6 g');
    });

    test('an empty day is a rest day', () {
      expect(daySprigLabel(day, const []), 'Mon 16 Nov, rest day');
    });
  });

  group('SprigDose', () {
    test('UTC and local timestamps share local day and minute', () {
      final utc = DateTime.utc(2026, 3, 2, 23, 45);
      final local = utc.toLocal();
      final a = SprigDose(time: utc, grams: 1, color: Colors.green);
      final b = SprigDose(time: local, grams: 1, color: Colors.green);
      expect(startOfDay(a.time), startOfDay(b.time));
      expect(a.minuteOfDay, b.minuteOfDay);
    });

    test('equal fields are equal with equal hashCodes', () {
      final a = dose(4, 9, 30);
      final b = dose(4, 9, 30);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == dose(5, 9, 30), isFalse);
      expect(a == dose(4, 10, 30), isFalse);
    });
  });

  group('DaySprigPainter.shouldRepaint', () {
    test('false when the same doses arrive in a different order', () {
      final a = dose(4, 9);
      final b = dose(3, 18);
      expect(painter([a, b]).shouldRepaint(painter([b, a])), isFalse);
    });

    test('true when grams change', () {
      final d = dose(4, 9);
      expect(painter([d]).shouldRepaint(painter([dose(5, 9)])), isTrue);
    });
  });

  group('DaySprig widget', () {
    testWidgets('exposes its semanticLabel', (tester) async {
      await pump(
        tester,
        ThemeProvider.lightTheme,
        [dose(4)],
        label: 'Mon 16 Nov, 1 dose, 4 g',
      );
      expect(find.bySemanticsLabel('Mon 16 Nov, 1 dose, 4 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final theme in ['light', 'dark']) {
      for (final size in [const Size(40, 90), const Size(20, 28)]) {
        testWidgets('paints $theme at ${size.width}x${size.height}',
            (tester) async {
          final t = theme == 'light'
              ? ThemeProvider.lightTheme
              : ThemeProvider.darkTheme;
          final seven = [
            for (var i = 0; i < 7; i++) dose(2 + i.toDouble(), 8 + i, i * 7),
          ];
          for (final doses in <List<SprigDose>>[
            const [],
            [dose(8)],
            seven,
            [dose(5, 14, 0), dose(5, 14, 20)],
          ]) {
            await pump(tester, t, doses, size: size);
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  });
}
