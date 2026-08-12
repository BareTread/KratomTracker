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
  test('a heavily used strain ranks below a lighter one that rested less', () {
    final now = DateTime(2025, 1, 10, 12);
    final dosages = [
      // A: one light dose, two days ago.
      _dose('a1', 'a', 1, DateTime(2025, 1, 8, 9)),
      // B: rested a day longer, but carried four times the grams.
      _dose('b1', 'b', 2, DateTime(2025, 1, 7, 8)),
      _dose('b2', 'b', 2, DateTime(2025, 1, 7, 10)),
      // C: never touched.
    ];

    final usage = computeStrainUsage(_strains, dosages, now: now);

    // The old formula put B ahead of A purely because it rested one day more.
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
}
