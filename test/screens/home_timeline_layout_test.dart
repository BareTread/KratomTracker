import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/home/home_dosage_list.dart';
import 'package:kratom_tracker_plus/widgets/strain_mark.dart';
import 'package:kratom_tracker_plus/widgets/vine_painter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('home timeline composition', () {
    testWidgets(
      '3 doses today spread through a realistic 393×852 list body',
      (tester) async {
        // Real phone body after day card + top safe + bottom nav:
        // 852 − ~48 − ~192 − ~56 ≈ 556. Use a tight 540 so the test
        // fails if composition still subtracts the 88 FAB pad.
        const listHeight = 540.0;
        const listWidth = 369.0; // 393 − horizontal padding 12×2

        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        final provider = await _provider(
          dosages: [
            _dose('a', day.add(const Duration(hours: 8)), 1),
            _dose('b', day.add(const Duration(hours: 12)), 2),
            _dose('c', day.add(const Duration(hours: 16)), 3),
          ],
        );

        await _pumpList(
          tester,
          provider,
          doseIds: ['a', 'b', 'c'],
          isToday: true,
          size: const Size(listWidth, listHeight),
        );

        String at(int hour) =>
            DateFormat('h:mm').format(day.add(Duration(hours: hour)));

        final early = tester.getCenter(find.text(at(8)));
        final mid = tester.getCenter(find.text(at(12)));
        final late = tester.getCenter(find.text(at(16)));
        final nowLabel = tester.getCenter(find.text('NOW'));

        expect(early.dy, lessThan(mid.dy));
        expect(mid.dy, lessThan(late.dy));
        expect(late.dy, lessThan(nowLabel.dy));

        // Span of the story (first dose → NOW) should occupy most of the
        // list body — not huddle in the upper third after an 88-pad cut.
        final span = nowLabel.dy - early.dy;
        expect(span, greaterThan(listHeight * 0.55));

        // NOW sits near the body bottom; only a small visual clearance
        // remains before the FAB zone (scroll pad may still exist).
        expect(nowLabel.dy, greaterThan(listHeight * 0.55));
        expect(nowLabel.dy, lessThan(listHeight - 8));

        // Amounts stay right-aligned as a stable column.
        final a1 = tester.getTopRight(find.text('1g'));
        final a2 = tester.getTopRight(find.text('2g'));
        final a3 = tester.getTopRight(find.text('3g'));
        expect(a1.dx, closeTo(a2.dx, 0.5));
        expect(a2.dx, closeTo(a3.dx, 0.5));
      },
    );

    testWidgets(
      'full-home 393×852 shell: 3 doses today fill the Expanded list',
      (tester) async {
        // Full phone surface. Day card + status line take the top; the
        // Expanded list body is what VineRhythm measures. We constrain
        // the list region directly to the realistic remaining height so
        // this is not an optimistic 612 direct-list test.
        const phoneW = 393.0;
        const phoneH = 852.0;
        // Approximate: top safe 48 + day card ~192 + bottom nav 56 ≈ 296
        // → list ≈ 556. Use 520 as a conservative real-device floor.
        const listHeight = 520.0;
        const listWidth = phoneW - 24; // horizontal page padding 12×2

        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        final provider = await _provider(
          dosages: [
            _dose('a', day.add(const Duration(hours: 8)), 1),
            _dose('b', day.add(const Duration(hours: 12)), 2),
            _dose('c', day.add(const Duration(hours: 16)), 3),
          ],
        );

        // Drive physical size at the phone surface so MediaQuery is honest,
        // then constrain the list itself to the realistic body height.
        tester.view.physicalSize = const Size(phoneW, phoneH);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpList(
          tester,
          provider,
          doseIds: ['a', 'b', 'c'],
          isToday: true,
          size: const Size(listWidth, listHeight),
          setViewSize: false,
        );

        String at(int hour) =>
            DateFormat('h:mm').format(day.add(Duration(hours: hour)));

        final early = tester.getCenter(find.text(at(8)));
        final late = tester.getCenter(find.text(at(16)));
        final nowLabel = tester.getCenter(find.text('NOW'));

        final span = nowLabel.dy - early.dy;
        // Final dose/NOW story occupies most of the available body.
        expect(span, greaterThan(listHeight * 0.55));
        expect(nowLabel.dy, greaterThan(listHeight * 0.55));
        expect(late.dy, lessThan(nowLabel.dy));

        // Rhythm math itself must have expanded past base for this height.
        final r = VineRhythm.compute(
          viewportHeight: listHeight,
          doseCount: 3,
          showNow: true,
        );
        final content = r.contentHeight(doseCount: 3, showNow: true);
        final baseContent =
            VineRhythm.base.contentHeight(doseCount: 3, showNow: true);
        expect(content, greaterThan(baseContent + 40));
        expect(
          content,
          greaterThan(
            listHeight - VineRhythm.listTopPad - VineRhythm.todayClearance - 1,
          ),
        );
      },
    );

    testWidgets('6 doses remain scrollable without overflow', (tester) async {
      const listHeight = 540.0;
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final dosages = List.generate(
        6,
        (i) => _dose('d$i', day.add(Duration(hours: 7 + i)), i + 1),
      );
      final provider = await _provider(dosages: dosages);

      await _pumpList(
        tester,
        provider,
        doseIds: dosages.map((d) => d['id']! as String).toList(),
        isToday: true,
        size: const Size(369, listHeight),
      );

      expect(tester.takeException(), isNull);
      // First dose is visible; last amount requires scroll (content > viewport).
      expect(find.text('1g'), findsOneWidget);
      // Base rhythm for 6 doses + NOW exceeds the composition target.
      final base = VineRhythm.base.contentHeight(doseCount: 6, showNow: true);
      expect(
        base + VineRhythm.listTopPad + VineRhythm.todayClearance,
        greaterThan(listHeight),
      );
    });

    testWidgets('strain marks sit on the band centre (stem offset separate)', (
      tester,
    ) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final provider = await _provider(
        dosages: [
          _dose('a', day.add(const Duration(hours: 9)), 1),
          _dose('b', day.add(const Duration(hours: 14)), 2),
        ],
      );

      await _pumpList(
        tester,
        provider,
        doseIds: ['a', 'b'],
        isToday: false,
        size: const Size(369, 540),
      );

      final marks = find.byType(StrainMark);
      expect(marks, findsNWidgets(2));

      // Both marks share the same x (band centre); stem wander does not
      // drag the data-column mark sideways.
      final m0 = tester.getCenter(marks.at(0));
      final m1 = tester.getCenter(marks.at(1));
      expect(m0.dx, closeTo(m1.dx, 0.5));

      // Band starts after the 64px time gutter; centre ≈ gutter + band/2.
      const expectedX = VineGeometry.timeGutter + VineGeometry.vineBand / 2;
      expect(m0.dx, closeTo(expectedX, 1.0));
    });
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

Map<String, Object?> _dose(String id, DateTime timestamp, double amount) => {
      'id': id,
      'strainId': 'strain-1',
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };

Future<void> _pumpList(
  WidgetTester tester,
  KratomProvider provider, {
  required List<String> doseIds,
  required bool isToday,
  required Size size,
  bool setViewSize = true,
}) async {
  if (setViewSize) {
    tester.view.physicalSize = Size(size.width, size.height + 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final strains = <String, Strain>{for (final s in provider.strains) s.id: s};
  final dosages =
      provider.dosages.where((d) => doseIds.contains(d.id)).toList();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: HomeDosageList(
              dosages: List<Dosage>.unmodifiable(dosages),
              strainsById: strains,
              isToday: isToday,
              header: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
