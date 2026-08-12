import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips the current backup shape', () {
    final source = _backup();
    final result = parseBackup(jsonEncode(source));

    expect(result, isA<BackupOk>());
    final ok = result as BackupOk;
    expect(ok.summary.strainCount, 1);
    expect(ok.summary.dosageCount, 1);
    expect(ok.summary.totalGrams, 1.5);
  });

  test('an old backup with effects and trackedEffects imports cleanly', () {
    // Backups written by earlier versions carry a populated `effects` array
    // and a `trackedEffects` settings field. Both keys are now unknown to the
    // codec and must be silently ignored — no throw, no warning.
    final source = _backup();
    source['settings'] = <String, dynamic>{
      'performanceMode': true,
      'trackedEffects': ['mood', 'energy', 'painRelief', 'focus'],
    };

    final result = parseBackup(jsonEncode(source));

    expect(result, isA<BackupOk>());
    final ok = result as BackupOk;
    expect(ok.summary.warnings, isEmpty,
        reason: 'legacy effects and trackedEffects keys must not warn',);
    expect(ok.payload.settings, isNotNull);
    expect(ok.summary.dosageCount, 1);
  });

  test('strain inStock round-trips through the codec', () {
    final source = _backup();
    source['strains']!.first['inStock'] = false;

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.strains.single.inStock, false);
    expect(ok.payload.strains.single.toJson()['inStock'], false);
  });

  test('a strain payload with no inStock field defaults to in stock', () {
    final source = _backup();
    // Field absent entirely — the day-one / legacy shape.
    (source['strains']!.first as Map).remove('inStock');

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(
      ok.payload.strains.single.inStock,
      true,
      reason: 'existing strains and old backups must come back in stock',
    );
  });

  test('an explicit null inStock field defaults to in stock', () {
    final source = _backup();
    final strain = Map<String, dynamic>.from(source['strains']!.first as Map);
    strain['inStock'] = null;
    source['strains'] = [strain];

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.strains.single.inStock, true);
  });

  test('accepts legacy pain_relief and numeric string amount', () {
    final source = _backup();
    source['dosages']!.first['amount'] = '1.5';

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.dosages.single.amount, 1.5);
  });

  test('accepts integer amounts and a missing effects key', () {
    final source = _backup();
    source['dosages']!.first['amount'] = 2;
    source.remove('effects');

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.dosages.single.amount, 2.0);
  });

  test('accepts a bare top-level dosage array', () {
    final dosages = _backup()['dosages'];

    final ok = parseBackup(jsonEncode(dosages)) as BackupOk;

    expect(ok.payload.strains, isEmpty);
    expect(ok.payload.dosages.single.id, 'dose-1');
  });

  test('drops an orphaned effect silently (legacy backups keep effects)', () {
    // Backups written by older versions carry an `effects` array. The codec
    // no longer models effects, so the whole key must be ignored without
    // throwing or emitting a warning — an unknown key is not a problem.
    final source = _backup();
    final effects = source['effects']! as List;
    final original = Map<String, dynamic>.from(effects.first as Map);
    effects.add(<String, dynamic>{
      ...original,
      'id': 'orphan',
      'dosageId': 'missing',
    });

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.summary.warnings, isEmpty,
        reason: 'an unknown effects key should not produce a warning',);
    expect(ok.summary.dosageCount, 1);
  });

  test('rejects malformed JSON', () {
    final result = parseBackup('{not json');

    expect(result, isA<BackupError>());
  });

  test('failed parse leaves SharedPreferences untouched', () async {
    SharedPreferences.setMockInitialValues({
      'strains': jsonEncode(_backup()['strains']),
      'dosages': jsonEncode(_backup()['dosages']),
      'settings': jsonEncode(_backup()['settings']),
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);
    final before = {
      for (final key in ['strains', 'dosages', 'settings'])
        key: prefs.getString(key),
    };

    await expectLater(provider.previewImport('{bad'), throwsFormatException);

    for (final entry in before.entries) {
      expect(prefs.getString(entry.key), entry.value);
    }
  });
}

Map<String, dynamic> _backup() => {
      'version': 1,
      'timestamp': '2025-01-01T00:00:00.000',
      'strains': [
        {
          'id': 'strain-1',
          'name': 'Green',
          'code': 'GRN',
          'color': 123,
          'icon': 'Leaf',
        },
      ],
      'dosages': [
        {
          'id': 'dose-1',
          'strainId': 'strain-1',
          'amount': 1.5,
          'timestamp': '2025-01-02T08:00:00.000',
          'notes': null,
        },
      ],
      'effects': [
        {
          'id': 'effect-1',
          'dosageId': 'dose-1',
          'timestamp': '2025-01-02T09:00:00.000',
          'mood': 3,
          'energy': 5,
          'painRelief': 4,
          'anxiety': null,
          'focus': 2,
          'notes': null,
          'duration': 90,
        },
      ],
      'settings': {'performanceMode': true},
    };
