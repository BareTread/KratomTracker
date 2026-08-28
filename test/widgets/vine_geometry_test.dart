import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/widgets/vine_painter.dart';

void main() {
  group('VineGeometry.offsetFor — stem left of marks', () {
    test('every node offset clears the 40px leaf body (incl. half aura)', () {
      for (var i = 0; i < 24; i++) {
        final off = VineGeometry.offsetFor(i);
        expect(
          VineGeometry.stemClearsLeaf(off),
          isTrue,
          reason: 'node $i offset=$off must clear leaf+aura',
        );
        // Stem stays inside the vine band with aura margin.
        final maxOff =
            VineGeometry.vineBand / 2 - VineGeometry.auraWidth / 2 - 2;
        expect(off.abs(), lessThanOrEqualTo(maxOff));
      }
    });

    test('stem always sits on the LEFT of the centred leaf (no side flips)',
        () {
      for (var i = 0; i < 16; i++) {
        final off = VineGeometry.offsetFor(i);
        expect(
          off,
          lessThan(0),
          reason: 'node $i must keep stem left of the mark (got $off)',
        );
      }
    });

    test('meander stays subtle (≈2–3 px around clearance, no zigzag)', () {
      // Magnitudes cluster tightly around stemClearance — no ±27 square wave.
      final mags = List.generate(
        12,
        (i) => VineGeometry.offsetFor(i).abs(),
      );
      final minMag = mags.reduce((a, b) => a < b ? a : b);
      final maxMag = mags.reduce((a, b) => a > b ? a : b);
      expect(maxMag - minMag, lessThanOrEqualTo(6.0));
      // Floor is leafRadius + half aura; ceiling is band edge − aura margin.
      expect(minMag, greaterThanOrEqualTo(VineGeometry.leafSize / 2));
      expect(maxMag, lessThanOrEqualTo(VineGeometry.vineBand / 2));
    });

    test('offset is stable for a given index', () {
      expect(VineGeometry.offsetFor(3), VineGeometry.offsetFor(3));
      // Neighbouring nodes differ by the slow meander, not a side flip.
      expect(
        (VineGeometry.offsetFor(7) - VineGeometry.offsetFor(8)).abs(),
        lessThan(6.0),
      );
    });
  });

  group('VineRhythm.compute — adaptive vertical spacing', () {
    // Realistic Expanded list height on a 393×852 Android body after the
    // day card (~192), top safe area (~48) and bottom nav (~56):
    // 852 − 48 − 192 − 56 ≈ 556. Tests also cover a tighter ~520 body.
    const viewportPhone = 540.0;
    // Optimistic direct-list height (kept for mild-expansion cases).
    const viewportWide = 612.0;

    test('3 doses today expand to fill most of a realistic phone body', () {
      final r = VineRhythm.compute(
        viewportHeight: viewportPhone,
        doseCount: 3,
        showNow: true,
      );
      // TODAY composition uses todayClearance (not the 88 FAB pad).
      final content = r.contentHeight(doseCount: 3, showNow: true);
      final target =
          viewportPhone - VineRhythm.listTopPad - VineRhythm.todayClearance;
      expect(r.gapStrip, greaterThan(VineRhythm.baseGap));
      expect(r.gapStrip, lessThanOrEqualTo(VineRhythm.maxGap));
      expect(r.rowPitch, greaterThanOrEqualTo(VineRhythm.baseRow));
      // Content should nearly fill the composition target.
      expect(content, greaterThan(target * 0.85));
      expect(content, lessThanOrEqualTo(target + 1));
      // Expanded content is meaningfully taller than the fixed base rhythm.
      final baseContent =
          VineRhythm.base.contentHeight(doseCount: 3, showNow: true);
      expect(content, greaterThan(baseContent + 40));
      // Content should occupy most of the actual list viewport (not just
      // the padded remainder after subtracting 88).
      expect(content, greaterThan(viewportPhone * 0.7));
    });

    test('1 dose today fills via the dashed strip, not the row or NOW', () {
      final r = VineRhythm.compute(
        viewportHeight: viewportPhone,
        doseCount: 1,
        showNow: true,
      );
      // The leaf must land where it lands on every other day, and the NOW
      // band must stay base — _NowRow centres a baseNow band in its pitch,
      // so a taller pitch leaves unpainted space that breaks the vine.
      expect(r.rowPitch, VineRhythm.baseRow);
      expect(r.nowPitch, VineRhythm.baseNow);
      // All the slack lands on the one continuous dashed run.
      expect(r.gapStrip, greaterThan(VineRhythm.baseGap));
      final content = r.contentHeight(doseCount: 1, showNow: true);
      final target =
          viewportPhone - VineRhythm.listTopPad - VineRhythm.todayClearance;
      expect(content, greaterThan(target * 0.7));
    });

    test('4–5 doses stay near comfortable base (mild expansion only)', () {
      final r4 = VineRhythm.compute(
        viewportHeight: viewportWide,
        doseCount: 4,
        showNow: true,
      );
      final r5 = VineRhythm.compute(
        viewportHeight: viewportWide,
        doseCount: 5,
        showNow: true,
      );
      // Mild caps: row ≤ base*1.18, gap ≤ base*1.45
      expect(r4.rowPitch, lessThanOrEqualTo(VineRhythm.baseRow * 1.18 + 0.01));
      expect(r5.rowPitch, lessThanOrEqualTo(VineRhythm.baseRow * 1.18 + 0.01));
      expect(r4.gapStrip, lessThanOrEqualTo(VineRhythm.baseGap * 1.45 + 0.01));
    });

    test('6+ doses keep base rhythm (scroll, no compression)', () {
      final r = VineRhythm.compute(
        viewportHeight: viewportPhone,
        doseCount: 6,
        showNow: true,
      );
      expect(r, VineRhythm.base);
      final content = r.contentHeight(doseCount: 6, showNow: true);
      // Naturally taller than the composition target → list scrolls.
      expect(
        content + VineRhythm.listTopPad + VineRhythm.todayClearance,
        greaterThan(viewportPhone),
      );
    });

    test('past day without NOW still expands on low dose counts', () {
      final r = VineRhythm.compute(
        viewportHeight: viewportPhone,
        doseCount: 2,
        showNow: false,
      );
      expect(r.rowPitch, greaterThan(VineRhythm.baseRow));
      expect(r.gapStrip, greaterThan(VineRhythm.baseGap));
      // PAST uses the conservative FAB clearance.
      final content = r.contentHeight(doseCount: 2, showNow: false);
      final target =
          viewportPhone - VineRhythm.listTopPad - VineRhythm.pastClearance;
      expect(content, lessThanOrEqualTo(target + 1));
    });

    test('today spreads farther than past for the same dose count', () {
      final today = VineRhythm.compute(
        viewportHeight: viewportPhone,
        doseCount: 3,
        showNow: true,
      );
      final past = VineRhythm.compute(
        viewportHeight: viewportPhone,
        doseCount: 3,
        showNow: false,
      );
      final todayH = today.contentHeight(doseCount: 3, showNow: true);
      final pastH = past.contentHeight(doseCount: 3, showNow: false);
      // TODAY composition target is larger (todayClearance ≪ pastClearance),
      // so the story occupies more of the body.
      expect(todayH, greaterThan(pastH));
    });

    test('unbounded / zero viewport falls back to base', () {
      expect(
        VineRhythm.compute(
          viewportHeight: double.infinity,
          doseCount: 3,
          showNow: true,
        ),
        VineRhythm.base,
      );
      expect(
        VineRhythm.compute(viewportHeight: 0, doseCount: 3, showNow: true),
        VineRhythm.base,
      );
    });

    test('gaps grow before rows (botanical breathing first)', () {
      // Base content (3 doses + NOW) = 3*92 + 3*28 + 72 = 432.
      // TODAY available at 440 = 440 − 4 − 20 = 416 < 432 → keep base.
      expect(
        VineRhythm.compute(
          viewportHeight: 440,
          doseCount: 3,
          showNow: true,
        ),
        VineRhythm.base,
      );
      // Mild expansion: available = 460 − 4 − 20 = 436; leftover = 4 → gaps.
      final mild = VineRhythm.compute(
        viewportHeight: 460,
        doseCount: 3,
        showNow: true,
      );
      expect(mild.gapStrip, greaterThan(VineRhythm.baseGap));
      expect(mild.rowPitch, VineRhythm.baseRow);
      expect(mild.nowPitch, VineRhythm.baseNow);
    });
  });

  group('quantizeLiveDashOffset — 9px dash cycle', () {
    // Pattern [2, 7] repeats every 9px; result is a whole-pixel phase in 0..8.
    final cycle = VineGeometry.liveDash.fold<double>(0, (a, b) => a + b);

    test('exact cycle boundaries wrap to phase 0', () {
      expect(cycle, 9.0);
      expect(quantizeLiveDashOffset(0), 0.0);
      expect(quantizeLiveDashOffset(cycle), 0.0);
      expect(quantizeLiveDashOffset(-cycle), 0.0);
      expect(quantizeLiveDashOffset(2 * cycle), 0.0);
    });

    test('whole-pixel phases 0–8 stay put; 9 wraps to 0', () {
      for (var p = 0; p <= 8; p++) {
        expect(quantizeLiveDashOffset(p.toDouble()), p.toDouble());
      }
      expect(quantizeLiveDashOffset(9), 0.0);
    });

    test('rounding 8.5 up wraps 9 → 0 (round-to-wrap)', () {
      // 8.4 stays on 8; halfway-and-up leaves the last pixel and wraps.
      expect(quantizeLiveDashOffset(8.4), 8.0);
      expect(quantizeLiveDashOffset(8.5), 0.0);
      expect(quantizeLiveDashOffset(8.6), 0.0);
      expect(quantizeLiveDashOffset(8.5 + cycle), 0.0);
    });

    test('mid-pixel values round to the nearest whole phase', () {
      expect(quantizeLiveDashOffset(0.4), 0.0);
      expect(quantizeLiveDashOffset(0.5), 1.0);
      expect(quantizeLiveDashOffset(7.5), 8.0);
    });

    test('negative offsets wrap into the same 0–8 cycle', () {
      expect(quantizeLiveDashOffset(-1), 8.0);
      expect(quantizeLiveDashOffset(-0.6), 8.0);
      expect(quantizeLiveDashOffset(-0.5), 0.0);
      expect(quantizeLiveDashOffset(-0.4), 0.0);
      expect(quantizeLiveDashOffset(-8), 1.0);
      expect(quantizeLiveDashOffset(-8.5), 1.0);
      expect(quantizeLiveDashOffset(-8.6), 0.0);
      expect(quantizeLiveDashOffset(-9), 0.0);
      expect(quantizeLiveDashOffset(-10), 8.0);
    });

    test('large multiples and live-travel span collapse to 9 phases', () {
      expect(quantizeLiveDashOffset(VineGeometry.liveDashTravel), 0.0);
      expect(quantizeLiveDashOffset(-VineGeometry.liveDashTravel), 0.0);
      expect(quantizeLiveDashOffset(36 + 3), 3.0);
      expect(quantizeLiveDashOffset(-36 - 3), 6.0);
      expect(quantizeLiveDashOffset(90.4), 0.0);
      expect(quantizeLiveDashOffset(-90.4), 0.0);

      final phases = <double>{};
      for (var i = 0; i <= 36; i++) {
        phases.add(quantizeLiveDashOffset(-i.toDouble()));
      }
      expect(phases, {0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0});
    });

    test('quantize is idempotent and stays in 0–8', () {
      const samples = [
        0.0,
        0.5,
        8.4,
        8.5,
        9.0,
        -0.4,
        -0.5,
        -1.0,
        -36.0,
        36.7,
        99.2,
        -99.2,
      ];
      for (final offset in samples) {
        final once = quantizeLiveDashOffset(offset);
        expect(once, quantizeLiveDashOffset(once));
        expect(once, greaterThanOrEqualTo(0.0));
        expect(once, lessThan(cycle));
        expect(once, once.roundToDouble());
      }
    });
  });
}
