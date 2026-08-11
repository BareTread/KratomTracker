import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/widgets/strain_mark.dart';

void main() {
  group('resolveLeafShape legacy names', () {
    const cases = <(String, LeafShape)>[
      // documented legacy → new mapping
      ('Leaf', LeafShape.single),
      ('Herb', LeafShape.single),
      ('Natural', LeafShape.sprout),
      ('Yard', LeafShape.sprout),
      ('Organic', LeafShape.trefoil),
      ('Plant', LeafShape.broad),
      ('Flower', LeafShape.broad),
      ('Nature', LeafShape.broad),
      ('Park', LeafShape.furl),
      ('Forest', LeafShape.vine),
    ];

    for (final (legacy, expected) in cases) {
      test('legacy "$legacy" maps to ${expected.name}', () {
        expect(resolveLeafShape(legacy, 'CODE').name, expected.name);
      });
    }

    test('legacy names match case-insensitively (original app wrote lowercase)', () {
      // The original app wrote lowercase icon names in its exports.
      expect(resolveLeafShape('leaf', 'CODE'), LeafShape.single);
      expect(resolveLeafShape('FLOWER', 'CODE'), LeafShape.broad);
      expect(resolveLeafShape('Forest', 'CODE'), LeafShape.vine);
    });

    test('new canonical names resolve directly', () {
      for (final shape in LeafShape.values) {
        expect(resolveLeafShape(shape.name, 'CODE'), shape);
        expect(resolveLeafShape(shape.name.toUpperCase(), 'CODE'), shape);
      }
    });
  });

  group('resolveLeafShape unknown fallback', () {
    test('an unknown value falls back deterministically from the code', () {
      final a = resolveLeafShape('whatever-the-original-app-wrote', 'GMD');
      final b = resolveLeafShape('whatever-the-original-app-wrote', 'GMD');
      expect(a, b, reason: 'same code must always yield the same shape');
    });

    test('different codes can map to different shapes', () {
      final shapes = <LeafShape>{};
      for (final code in ['GMD', 'RB', 'TH', 'MD', 'BI', 'GM']) {
        shapes.add(resolveLeafShape('unknown', code));
      }
      // A 30-strain library should spread across more than one shape; this
      // is the exact problem a fixed default would cause.
      expect(shapes.length, greaterThan(1));
    });

    test('a missing (empty) icon value still resolves deterministically', () {
      final a = resolveLeafShape('', 'RB');
      final b = resolveLeafShape('', 'RB');
      expect(a, b);
    });

    test('the fallback is a valid LeafShape', () {
      expect(
        LeafShape.values.contains(resolveLeafShape('nonsense', 'XYZ')),
        isTrue,
      );
    });
  });

  group('markCollision', () {
    StrainMarkRef ref(String id, String name, int color, LeafShape shape) =>
        (id: id, name: name, color: color, icon: shape.name, code: id);

    test('detects a duplicate colour+shape pair and names the owning strain', () {
      final strains = [
        ref('s1', 'Green Maeng Da', 0xFF4CAF50, LeafShape.single),
        ref('s2', 'Red Bali', 0xFFE53935, LeafShape.trefoil),
      ];

      final result = markCollision(strains, 0xFF4CAF50, LeafShape.single);

      expect(result.ownerId, 's1');
      expect(result.ownerName, 'Green Maeng Da');
      expect(result.takenForColor, contains(LeafShape.single));
    });

    test('reports no owner when the pair is free', () {
      final strains = [
        ref('s1', 'Green Maeng Da', 0xFF4CAF50, LeafShape.single),
      ];

      final result = markCollision(strains, 0xFF4CAF50, LeafShape.trefoil);

      expect(result.ownerId, isNull);
      expect(result.ownerName, isNull);
      expect(result.takenForColor, contains(LeafShape.single));
      expect(result.takenForColor, isNot(contains(LeafShape.trefoil)));
    });

    test('excludeId skips the strain being edited', () {
      final strains = [
        ref('s1', 'Green Maeng Da', 0xFF4CAF50, LeafShape.single),
      ];

      final result = markCollision(
        strains,
        0xFF4CAF50,
        LeafShape.single,
        excludeId: 's1',
      );

      // The edited strain's own pair is not a conflict with itself.
      expect(result.ownerId, isNull);
      expect(result.takenForColor, isEmpty);
    });

    test('only counts strains sharing the selected colour', () {
      final strains = [
        ref('s1', 'Green Maeng Da', 0xFF4CAF50, LeafShape.single),
        ref('s2', 'Red Bali', 0xFFE53935, LeafShape.single),
      ];

      final result = markCollision(strains, 0xFF4CAF50, LeafShape.single);

      expect(result.ownerId, 's1');
      // Red's single is not taken-for-green.
      expect(result.takenForColor, contains(LeafShape.single));
      expect(result.takenForColor.length, 1);
    });
  });
}
