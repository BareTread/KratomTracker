import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/domain/strain_usage.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';

void main() {
  test('pins frozen rotation ordering and last-used-day dose counts', () {
    final now = DateTime(2025, 1, 10, 12);
    const strains = [
      Strain(id: 'a', name: 'A', code: 'A', color: 0, icon: 'Leaf'),
      Strain(id: 'b', name: 'B', code: 'B', color: 0, icon: 'Leaf'),
      Strain(id: 'c', name: 'C', code: 'C', color: 0, icon: 'Leaf'),
    ];
    final dosages = [
      Dosage(
        id: 'a1',
        strainId: 'a',
        amount: 1,
        timestamp: DateTime(2025, 1, 8, 9),
      ),
      Dosage(
        id: 'b1',
        strainId: 'b',
        amount: 2,
        timestamp: DateTime(2025, 1, 7, 8),
      ),
      Dosage(
        id: 'b2',
        strainId: 'b',
        amount: 2,
        timestamp: DateTime(2025, 1, 7, 10),
      ),
    ];

    final usage = computeStrainUsage(strains, dosages, now: now);

    expect(usage.map((item) => item.strain.id), ['c', 'b', 'a']);
    expect(usage.map((item) => item.rank), [0, 1, 2]);
    expect(
        usage.singleWhere((item) => item.strain.id == 'a').dosesLastUsedDay, 1);
    expect(
        usage.singleWhere((item) => item.strain.id == 'b').dosesLastUsedDay, 2);
  });
}
