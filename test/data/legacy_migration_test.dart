import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/widgets/strain_mark.dart';

/// End-to-end guard for the ONE migration that actually matters: moving 18
/// months of real history out of the original `org.kratomtracker.app` build
/// and into `org.kratomtracker.plus`.
///
/// The payload below is shaped exactly like the original app's
/// `KratomProvider.exportData()` output, including its quirks: `amount` is
/// whatever `jsonDecode` produced (so an int when the user typed "2"), effects
/// carry the legacy `pain_relief` spelling, and `settings` holds keys this
/// build no longer uses.
void main() {
  String legacyExport() => jsonEncode({
        'version': 1,
        'timestamp': '2025-03-14T09:12:44.000',
        'strains': [
          {
            'id': 's-green',
            'name': 'Green Maeng Da',
            'code': 'GMD',
            'color': 4283215696,
            'icon': 'leaf',
          },
          {
            'id': 's-red',
            'name': 'Red Bali',
            'code': 'RB',
            'color': 4294198070,
            'icon': 'flower',
          },
        ],
        'dosages': [
          // int amount — the original app stored whatever the user typed
          {
            'id': 'd1',
            'strainId': 's-green',
            'amount': 2,
            'timestamp': '2024-09-01T08:30:00.000',
            'notes': null,
          },
          // double amount
          {
            'id': 'd2',
            'strainId': 's-red',
            'amount': 1.5,
            'timestamp': '2024-09-01T14:05:00.000',
            'notes': 'with food, comma, and "quotes"',
          },
          // string amount — seen in hand-edited exports
          {
            'id': 'd3',
            'strainId': 's-green',
            'amount': '3.25',
            'timestamp': '2025-03-13T21:40:00.000',
            'notes': null,
          },
          // dosage pointing at a strain that no longer exists
          {
            'id': 'd4',
            'strainId': 's-deleted',
            'amount': 1,
            'timestamp': '2025-01-02T10:00:00.000',
          },
        ],
        'effects': [
          {
            'id': 'e1',
            'dosageId': 'd1',
            'timestamp': '2024-09-01T09:30:00.000',
            'mood': 4,
            'energy': 5,
            'pain_relief': 3, // legacy spelling
            'duration': 180,
          },
          {
            'id': 'e2',
            'dosageId': 'does-not-exist',
            'timestamp': '2024-09-02T09:30:00.000',
            'mood': 3,
            'energy': 3,
            'painRelief': 3,
          },
        ],
        'settings': {
          'darkMode': true,
          'measurementUnit': 'g',
          'dailyLimit': 0.0,
          'someKeyThisBuildNeverHeardOf': 42,
        },
      });

  test('imports the original app export without losing doses', () {
    final result = parseBackup(legacyExport());
    expect(result, isA<BackupOk>());
    final ok = result as BackupOk;

    expect(ok.payload.strains.length, 2);

    // d4 references a deleted strain and is dropped with a warning; the three
    // real doses survive regardless of how `amount` was encoded.
    final ids = ok.payload.dosages.map((d) => d.id).toList();
    expect(ids, containsAll(<String>['d1', 'd2', 'd3']));
    expect(ids, isNot(contains('d4')));

    final byId = {for (final d in ok.payload.dosages) d.id: d};
    expect(byId['d1']!.amount, 2.0); // int coerced
    expect(byId['d2']!.amount, 1.5); // double preserved
    expect(byId['d3']!.amount, 3.25); // string coerced
    expect(byId['d2']!.notes, 'with food, comma, and "quotes"');

    expect(ok.summary.warnings, isNotEmpty);
  });

  test('legacy pain_relief spelling survives the migration', () {
    final ok = parseBackup(legacyExport()) as BackupOk;
    final e1 = ok.payload.effects.singleWhere((e) => e.id == 'e1');
    expect(e1.painRelief, 3,
        reason: 'the original app wrote pain_relief; dropping it would '
            'silently lose every pain rating ever recorded');
    expect(e1.duration, const Duration(minutes: 180));
  });

  test('orphaned effect is dropped rather than crashing the import', () {
    final ok = parseBackup(legacyExport()) as BackupOk;
    expect(ok.payload.effects.map((e) => e.id), isNot(contains('e2')));
  });

  test('summary reports a truthful preview before anything is committed', () {
    final ok = parseBackup(legacyExport()) as BackupOk;
    expect(ok.summary.dosageCount, 3);
    expect(ok.summary.totalGrams, closeTo(2 + 1.5 + 3.25, 0.0001));
    expect(ok.summary.earliestDose, DateTime.parse('2024-09-01T08:30:00.000'));
    expect(ok.summary.latestDose, DateTime.parse('2025-03-13T21:40:00.000'));
  });

  test('unknown settings keys do not abort the import', () {
    final ok = parseBackup(legacyExport()) as BackupOk;
    expect(ok.payload.settings, isNotNull);
  });

  test('a truncated file is rejected outright', () {
    final truncated = legacyExport();
    final result = parseBackup(truncated.substring(0, truncated.length ~/ 2));
    expect(result, isA<BackupError>());
  });

  group('icon migration to LeafShape', () {
    test('legacy icon names map to their documented shape', () {
      final ok = parseBackup(legacyExport()) as BackupOk;
      final byId = {for (final s in ok.payload.strains) s.id: s};
      // 'leaf' -> lance, 'flower' -> spathe (case-insensitive legacy map).
      expect(byId['s-green']!.icon, 'lance');
      expect(byId['s-red']!.icon, 'spathe');
    });

    test('a new canonical name round-trips unchanged', () {
      final source = jsonDecode(legacyExport()) as Map<String, dynamic>;
      final strains =
          (source['strains'] as List).cast<Map<String, dynamic>>();
      strains[0]['icon'] = 'palmate';
      strains[1]['icon'] = 'capsule';

      final ok = parseBackup(jsonEncode(source)) as BackupOk;
      final byId = {for (final s in ok.payload.strains) s.id: s};
      expect(byId['s-green']!.icon, 'palmate');
      expect(byId['s-red']!.icon, 'capsule');
    });

    test('an unknown icon value falls back deterministically from the code', () {
      final source = jsonDecode(legacyExport()) as Map<String, dynamic>;
      final strains =
          (source['strains'] as List).cast<Map<String, dynamic>>();
      strains[0]['icon'] = 'something-the-original-app-wrote';

      final first = (parseBackup(jsonEncode(source)) as BackupOk)
          .payload
          .strains
          .singleWhere((s) => s.id == 's-green');
      final second = (parseBackup(jsonEncode(source)) as BackupOk)
          .payload
          .strains
          .singleWhere((s) => s.id == 's-green');
      expect(first.icon, second.icon, reason: 'same code -> same shape');
      expect(
        LeafShape.values.map((s) => s.name).contains(first.icon),
        isTrue,
      );
    });

    test('a missing icon field falls back deterministically from the code', () {
      final source = jsonDecode(legacyExport()) as Map<String, dynamic>;
      final strains =
          (source['strains'] as List).cast<Map<String, dynamic>>();
      strains[0].remove('icon');

      final first = (parseBackup(jsonEncode(source)) as BackupOk)
          .payload
          .strains
          .singleWhere((s) => s.id == 's-green');
      final second = (parseBackup(jsonEncode(source)) as BackupOk)
          .payload
          .strains
          .singleWhere((s) => s.id == 's-green');
      expect(first.icon, second.icon);
      expect(first.icon, isNotEmpty);
    });
  });
}
