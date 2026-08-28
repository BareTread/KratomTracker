import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/strain_usage.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';

const _strains = [
  Strain(id: 'a', name: 'A', code: 'A', color: 0, icon: 'Leaf'),
  Strain(id: 'b', name: 'B', code: 'B', color: 0, icon: 'Leaf'),
  Strain(id: 'c', name: 'C', code: 'C', color: 0, icon: 'Leaf'),
];

Dosage _dose(String id, String strainId, double amount, DateTime timestamp) =>
    Dosage(id: id, strainId: strainId, amount: amount, timestamp: timestamp);

void main() {
  test('a 5-day-old high-volume strain ranks ahead of a 2-day-old lighter one',
      () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      // A: last taken 5 days ago, 80g in 30d — the screenshot workhorse.
      _dose('a1', 'a', 40, DateTime(2025, 1, 5, 9)),
      _dose('a2', 'a', 40, DateTime(2025, 1, 4, 9)),
      // B: last taken 2 days ago, much lighter volume.
      _dose('b1', 'b', 2, DateTime(2025, 1, 8, 9)),
      // C: never used.
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);

    // Recency is primary: 5d rest beats 2d rest regardless of grams.
    // Never-used is more rotation-friendly than either.
    expect(usage.map((item) => item.strain.id), ['c', 'a', 'b']);
    expect(usage.map((item) => item.rank), [0, 1, 2]);
  });

  test('concentration measures share of the month against an even split', () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      _dose('a1', 'a', 1, DateTime(2025, 1, 8, 9)),
      _dose('b1', 'b', 2, DateTime(2025, 1, 7, 8)),
      _dose('b2', 'b', 2, DateTime(2025, 1, 7, 10)),
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);
    StrainUsage byId(String id) =>
        usage.singleWhere((item) => item.strain.id == id);

    // 5g over three strains: an even split is 1.667g each.
    expect(byId('a').concentration, closeTo(0.6, 1e-9));
    expect(byId('b').concentration, closeTo(2.4, 1e-9));
    expect(byId('c').concentration, 0);

    // The load bar is scaled against the busiest strain, not the total.
    expect(byId('b').relativeLoad, 1);
    expect(byId('a').relativeLoad, closeTo(0.25, 1e-9));
    expect(byId('c').relativeLoad, 0);
  });

  test('recency counts calendar days, not elapsed hours', () {
    // 23:00 last night is "yesterday" at 08:00, even though only 9 hours
    // have passed.
    final usage = computeStrainUsage(
      _strains,
      [_dose('a1', 'a', 1, DateTime(2025, 1, 9, 23))],
      now: DateTime(2025, 1, 10, 8),
    );

    expect(
      usage.singleWhere((item) => item.strain.id == 'a').daysSinceLastUse,
      1,
    );
  });

  test('among equally rested strains the lighter one comes first', () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      _dose('a1', 'a', 1, DateTime(2025, 1, 8, 9)),
      _dose('b1', 'b', 5, DateTime(2025, 1, 8, 9)),
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);

    expect(usage.map((item) => item.strain.id), ['c', 'a', 'b']);
  });

  test('an empty history ranks every strain equally, by code', () {
    final usage =
        computeStrainUsage(_strains, const [], now: DateTime(2025, 1, 10));

    expect(usage.map((item) => item.strain.id), ['a', 'b', 'c']);
    expect(usage.every((item) => item.concentration == 0), isTrue);
    expect(usage.every((item) => item.relativeLoad == 0), isTrue);
    expect(usage.every((item) => item.rotationScore.isFinite), isTrue);
  });

  test('never-used ranks ahead of a strain last taken a year ago', () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      _dose('a1', 'a', 100, DateTime(2024, 1, 1, 9)),
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);

    expect(usage.map((item) => item.strain.id), ['b', 'c', 'a']);
  });

  test('same calendar day is one recency bucket; lighter volume wins', () {
    final now = DateTime(2025, 1, 10, 18);
    final dosages = [
      _dose('a1', 'a', 8, DateTime(2025, 1, 8, 23)),
      _dose('b1', 'b', 1, DateTime(2025, 1, 8, 1)),
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);

    expect(
      usage.singleWhere((item) => item.strain.id == 'a').daysSinceLastUse,
      2,
    );
    expect(
      usage.singleWhere((item) => item.strain.id == 'b').daysSinceLastUse,
      2,
    );
    expect(usage.map((item) => item.strain.id), ['c', 'b', 'a']);
  });

  test('a future timestamp is treated as used today', () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      _dose('a1', 'a', 1, DateTime(2025, 1, 8, 9)),
      _dose('b1', 'b', 1, DateTime(2025, 1, 12, 9)),
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);
    final future = usage.singleWhere((item) => item.strain.id == 'b');

    expect(future.daysSinceLastUse, 0);
    expect(future.rotationScore.isFinite, isTrue);
    expect(usage.map((item) => item.strain.id), ['c', 'a', 'b']);
  });

  test('equal rest and equal volume break ties by code', () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      _dose('c1', 'c', 2, DateTime(2025, 1, 8, 9)),
      _dose('b1', 'b', 2, DateTime(2025, 1, 8, 9)),
      _dose('a1', 'a', 2, DateTime(2025, 1, 8, 9)),
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);

    expect(usage.map((item) => item.strain.id), ['a', 'b', 'c']);
  });

  test('equal rest, volume, and code break ties by strain id', () {
    const strains = [
      Strain(id: 'z', name: 'Zed', code: 'DUP', color: 0, icon: 'Leaf'),
      Strain(id: 'a', name: 'Aye', code: 'DUP', color: 0, icon: 'Leaf'),
    ];
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      _dose('z1', 'z', 2, DateTime(2025, 1, 8, 9)),
      _dose('a1', 'a', 2, DateTime(2025, 1, 8, 9)),
    ];

    final usage = computeStrainUsage(strains, dosages, now: now);

    expect(usage.map((item) => item.strain.id), ['a', 'z']);
  });
}
