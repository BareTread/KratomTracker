import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/strain.dart';

void main() {
  group('Strain.inStock default-true on read', () {
    test('absent field -> in stock', () {
      final s = Strain.fromJson({
        'id': 's1',
        'name': 'A',
        'code': 'A',
        'color': 1,
        'icon': 'Leaf',
      });
      expect(s.inStock, true);
    });

    test('explicit null -> in stock', () {
      final s = Strain.fromJson({
        'id': 's1',
        'name': 'A',
        'code': 'A',
        'color': 1,
        'icon': 'Leaf',
        'inStock': null,
      });
      expect(s.inStock, true);
    });

    test('explicit false -> out of stock', () {
      final s = Strain.fromJson({
        'id': 's1',
        'name': 'A',
        'code': 'A',
        'color': 1,
        'icon': 'Leaf',
        'inStock': false,
      });
      expect(s.inStock, false);
    });

    test('garbage value falls back to in stock (safe default)', () {
      final s = Strain.fromJson({
        'id': 's1',
        'name': 'A',
        'code': 'A',
        'color': 1,
        'icon': 'Leaf',
        'inStock': 'maybe',
      });
      expect(s.inStock, true);
    });

    test('constructor defaults to in stock', () {
      const s = Strain(id: 's1', name: 'A', code: 'A', color: 1, icon: 'Leaf');
      expect(s.inStock, true);
    });

    test('toJson includes inStock', () {
      const s = Strain(
        id: 's1',
        name: 'A',
        code: 'A',
        color: 1,
        icon: 'Leaf',
        inStock: false,
      );
      expect(s.toJson()['inStock'], false);
    });

    test('copyWith toggles inStock without touching other fields', () {
      const s = Strain(
        id: 's1',
        name: 'A',
        code: 'A',
        color: 1,
        icon: 'Leaf',
      );
      final toggled = s.copyWith(inStock: false);
      expect(toggled.inStock, false);
      expect(toggled.id, s.id);
      expect(toggled.name, s.name);
    });
  });
}
