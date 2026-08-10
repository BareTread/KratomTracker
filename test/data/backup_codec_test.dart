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
    expect(ok.summary.effectCount, 1);
    expect(ok.summary.totalGrams, 1.5);
    expect(jsonDecode(jsonEncode(ok.payload.effects.single.toJson())),
        source['effects']!.first);
  });

  test('accepts legacy pain_relief and numeric string amount', () {
    final source = _backup();
    source['dosages']!.first['amount'] = '1.5';
    final effect = source['effects']!.first;
    effect['pain_relief'] = effect.remove('painRelief');

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.dosages.single.amount, 1.5);
    expect(ok.payload.effects.single.painRelief, 4);
  });

  test('accepts integer amounts and a missing effects key', () {
    final source = _backup();
    source['dosages']!.first['amount'] = 2;
    source.remove('effects');

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.dosages.single.amount, 2.0);
    expect(ok.payload.effects, isEmpty);
  });

  test('accepts a bare top-level dosage array', () {
    final dosages = _backup()['dosages'];

    final ok = parseBackup(jsonEncode(dosages)) as BackupOk;

    expect(ok.payload.strains, isEmpty);
    expect(ok.payload.dosages.single.id, 'dose-1');
  });

  test('drops an orphaned effect and reports a warning', () {
    final source = _backup();
    final effects = source['effects']! as List;
    final original = Map<String, dynamic>.from(effects.first as Map);
    effects.add(<String, dynamic>{
      ...original,
      'id': 'orphan',
      'dosageId': 'missing',
    });

    final ok = parseBackup(jsonEncode(source)) as BackupOk;

    expect(ok.payload.effects, hasLength(1));
    expect(ok.summary.warnings.join(' '), contains('missing dosage'));
  });

  test('rejects malformed JSON', () {
    final result = parseBackup('{not json');

    expect(result, isA<BackupError>());
  });

  test('failed parse leaves SharedPreferences untouched', () async {
    SharedPreferences.setMockInitialValues({
      'strains': jsonEncode(_backup()['strains']),
      'dosages': jsonEncode(_backup()['dosages']),
      'effects': jsonEncode(_backup()['effects']),
      'settings': jsonEncode(_backup()['settings']),
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);
    final before = {
      for (final key in ['strains', 'dosages', 'effects', 'settings'])
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
