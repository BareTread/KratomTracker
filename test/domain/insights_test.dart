import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/insights_service.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';

final _now = DateTime(2026, 8, 12, 21);
final _today = DateTime(2026, 8, 12);

Dosage _dose(String id, String strain, double amount, DateTime at) =>
    Dosage(id: id, strainId: strain, amount: amount, timestamp: at);

/// [hours] are the local hours a dose is logged, on the day [daysAgo] back.
List<Dosage> _day(int daysAgo, List<int> hours, {String strain = 's0'}) {
  final day = _today.subtract(Duration(days: daysAgo));
  return [
    for (final hour in hours)
      _dose(
        'd$daysAgo-$hour-$strain',
        strain,
        16,
        day.add(Duration(hours: hour)),
      ),
  ];
}

void main() {
  group('computeGapCompression', () {
    test('sees a schedule tightening that G = F x A cannot', () {
      // Same four doses a day throughout — only the spacing changes.
      final doses = <Dosage>[
        for (var d = 31; d <= 60; d++) ..._day(d, [8, 13, 18, 23]),
        for (var d = 1; d <= 30; d++) ..._day(d, [8, 11, 14, 17]),
      ];

      final gap = computeGapCompression(doses, now: _now)!;

      expect(gap.previous, const Duration(hours: 5));
      expect(gap.recent, const Duration(hours: 3));
      expect(gap.delta, const Duration(hours: -2));
      expect(gap.isCompressing, isTrue);
      expect(gap.isMaterial, isTrue);
    });

    test('a small wobble is not material', () {
      final doses = <Dosage>[
        for (var d = 31; d <= 60; d++) ..._day(d, [8, 13, 18]),
        // Ten minutes earlier: real, but not a schedule change.
        for (var d = 1; d <= 30; d++)
          ..._day(d, [8, 13, 18]).map(
            (dose) => _dose(
              '${dose.id}b',
              dose.strainId,
              dose.amount,
              dose.timestamp.subtract(const Duration(minutes: 5)),
            ),
          ),
      ];

      final gap = computeGapCompression(doses, now: _now)!;

      expect(gap.isMaterial, isFalse);
    });

    test('returns null below fifteen usable days in a window', () {
      final doses = <Dosage>[
        for (var d = 31; d <= 60; d++) ..._day(d, [8, 13]),
        for (var d = 1; d <= 10; d++) ..._day(d, [8, 13]),
      ];

      expect(computeGapCompression(doses, now: _now), isNull);
    });

    test('single-dose days contribute nothing and today is excluded', () {
      final doses = <Dosage>[
        for (var d = 31; d <= 60; d++) ..._day(d, [8, 13]),
        for (var d = 1; d <= 30; d++) ..._day(d, [8, 13]),
        // Today, mid-afternoon, tightly packed — must not move anything.
        ..._day(0, [8, 9, 10]),
      ];

      final gap = computeGapCompression(doses, now: _now)!;

      expect(gap.recent, const Duration(hours: 5));
      expect(gap.recentDays, 30);
    });
  });

  group('computeReturnCycle', () {
    test('measures the rest between one strain leaving and coming back', () {
      // A strict six-strain rotation, one strain per day, four doses a day.
      // Each strain therefore returns every six days.
      final doses = <Dosage>[
        for (var d = 1; d <= 120; d++)
          ..._day(d, [8, 12, 16, 20], strain: 's${d % 6}'),
      ];

      final cycle = computeReturnCycle(doses, now: _now)!;

      // Last dose 20:00, next first dose 08:00 six days later = 5d 12h.
      expect(cycle.median, const Duration(days: 5, hours: 12));
      expect(cycle.strains, 6);
      expect(cycle.events, greaterThanOrEqualTo(20));
    });

    test('a run of the same strain is one episode, not several returns', () {
      // Three consecutive days of s1 then three of s2, repeating. A return
      // interval must span the whole opposing block, not each day boundary.
      final doses = <Dosage>[
        for (var d = 1; d <= 180; d++)
          ..._day(d, [8, 20], strain: 's${(d ~/ 3) % 6}'),
      ];

      final cycle = computeReturnCycle(doses, now: _now)!;

      // Six strains x three days each = an 18-day rotation.
      expect(cycle.median.inDays, greaterThan(14));
      expect(cycle.strains, 6);
    });

    test('returns null when too few strains are in play', () {
      final doses = <Dosage>[
        for (var d = 1; d <= 120; d++) ..._day(d, [8, 20], strain: 's${d % 2}'),
      ];

      expect(computeReturnCycle(doses, now: _now), isNull);
    });
  });

  group('computeRotationBreadth', () {
    test('an even spread has an effective size equal to the observed one', () {
      final doses = <Dosage>[
        for (var d = 1; d <= 20; d++)
          for (var s = 0; s < 5; s++)
            _dose(
              'd$d-s$s',
              's$s',
              16,
              _today
                  .subtract(Duration(days: d))
                  .add(Duration(hours: 8 + s * 2)),
            ),
      ];

      final breadth = computeRotationBreadth(doses, now: _now)!;

      expect(breadth.observed, 5);
      expect(breadth.effective, closeTo(5, 1e-9));
      expect(breadth.isNarrow, isFalse);
    });

    test('a wide shelf carried by two strains reads as a narrow rotation', () {
      final doses = <Dosage>[
        for (var d = 1; d <= 20; d++) ...[
          // Two workhorses take almost everything.
          _dose('a$d', 's0', 40, _today.subtract(Duration(days: d, hours: -8))),
          _dose(
            'b$d',
            's1',
            40,
            _today.subtract(Duration(days: d, hours: -12)),
          ),
          // Six others take a token dose each.
          for (var s = 2; s < 8; s++)
            _dose(
              'c$d-$s',
              's$s',
              2,
              _today.subtract(Duration(days: d)).add(Duration(hours: 14 + s)),
            ),
        ],
      ];

      final breadth = computeRotationBreadth(doses, now: _now)!;

      expect(breadth.observed, 8);
      expect(breadth.effective, lessThan(3.5));
      expect(breadth.isNarrow, isTrue);
    });

    test('returns null below thirty doses', () {
      final doses = <Dosage>[
        for (var d = 1; d <= 10; d++) ..._day(d, [8], strain: 's${d % 3}'),
      ];

      expect(computeRotationBreadth(doses, now: _now), isNull);
    });
  });

  group('computeFirstDoseDrift', () {
    test('reports the day starting earlier', () {
      final doses = <Dosage>[
        for (var d = 31; d <= 60; d++) ..._day(d, [9, 14]),
        for (var d = 1; d <= 30; d++) ..._day(d, [7, 14]),
      ];

      final drift = computeFirstDoseDrift(doses, now: _now)!;

      expect(drift.previousMinute, 9 * 60);
      expect(drift.recentMinute, 7 * 60);
      expect(drift.deltaMinutes, -120);
      expect(drift.isEarlier, isTrue);
      expect(drift.isMaterial, isTrue);
    });

    test('a start straddling midnight does not median to lunchtime', () {
      // Alternating 23:40 and 00:20 starts: the circular median is midnight,
      // not the 12:00 a naive median of 1420 and 20 would give.
      final doses = <Dosage>[
        for (var d = 1; d <= 60; d++) ..._day(d, [], strain: 's0'),
        for (var d = 1; d <= 60; d++)
          _dose(
            'm$d',
            's0',
            16,
            _today.subtract(Duration(days: d)).add(
                  d.isEven
                      ? const Duration(hours: 23, minutes: 40)
                      : const Duration(minutes: 20),
                ),
          ),
      ];

      final drift = computeFirstDoseDrift(doses, now: _now)!;

      final distanceFromMidnight = math.min(
        drift.recentMinute,
        1440 - drift.recentMinute,
      );
      expect(distanceFromMidnight, lessThan(60));
      expect(drift.deltaMinutes.abs(), lessThan(60));
    });

    test('returns null below fifteen days in a window', () {
      final doses = <Dosage>[
        for (var d = 31; d <= 60; d++) ..._day(d, [9]),
        for (var d = 1; d <= 5; d++) ..._day(d, [7]),
      ];

      expect(computeFirstDoseDrift(doses, now: _now), isNull);
    });
  });
}
