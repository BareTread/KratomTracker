import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deleting a strain cascades to its dosages and effects', () async {
    final provider = await _providerWithFixture();

    await provider.deleteStrain('strain-1');

    expect(provider.strains, isEmpty);
    expect(provider.dosages, isEmpty);
    expect(provider.effects, isEmpty);
  });

  test('getStrain immediately returns an updated strain', () async {
    final provider = await _providerWithFixture();
    expect(provider.getStrain('strain-1')!.name, 'Original');

    await provider.updateStrain('strain-1', name: 'Updated');

    expect(provider.getStrain('strain-1')!.name, 'Updated');
  });

  test('addDosage rejects non-positive and non-finite amounts', () async {
    final provider = await _providerWithFixture();

    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        provider.addDosage('strain-1', amount, DateTime(2025)),
        throwsArgumentError,
      );
    }
    expect(provider.dosages, hasLength(1));
  });

  test('replace import replaces existing records', () async {
    final provider = await _providerWithFixture();
    final payload = _parsePayload(_importJson(includeExistingId: false));

    await provider.commitImport(payload, mode: ImportMode.replace);

    expect(provider.strains.map((s) => s.id), ['strain-2']);
    expect(provider.dosages.map((d) => d.id), ['dose-2']);
    expect(provider.effects, isEmpty);
  });

  test('merge import unions by id and existing records win', () async {
    final provider = await _providerWithFixture();
    final payload = _parsePayload(_importJson(includeExistingId: true));

    await provider.commitImport(payload, mode: ImportMode.merge);

    expect(provider.strains.map((s) => s.id), ['strain-1', 'strain-2']);
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-1', 'dose-2']);
  });
}

Future<KratomProvider> _providerWithFixture() async {
  SharedPreferences.setMockInitialValues({
    'strains': jsonEncode([
      {
        'id': 'strain-1',
        'name': 'Original',
        'code': 'ONE',
        'color': 1,
        'icon': 'Leaf',
      },
    ]),
    'dosages': jsonEncode([
      {
        'id': 'dose-1',
        'strainId': 'strain-1',
        'amount': 1.0,
        'timestamp': '2025-01-01T08:00:00.000',
      },
    ]),
    'effects': jsonEncode([
      {
        'id': 'effect-1',
        'dosageId': 'dose-1',
        'timestamp': '2025-01-01T09:00:00.000',
        'mood': 3,
        'energy': 3,
        'painRelief': 3,
      },
    ]),
  });
  return KratomProvider.create(await SharedPreferences.getInstance());
}

BackupPayload _parsePayload(String source) =>
    (parseBackup(source) as BackupOk).payload;

String _importJson({required bool includeExistingId}) => jsonEncode({
      'version': 1,
      'strains': [
        if (includeExistingId)
          {
            'id': 'strain-1',
            'name': 'Incoming replacement',
            'code': 'NEW',
            'color': 2,
            'icon': 'Plant',
          },
        {
          'id': 'strain-2',
          'name': 'Second',
          'code': 'TWO',
          'color': 2,
          'icon': 'Plant',
        },
      ],
      'dosages': [
        {
          'id': 'dose-2',
          'strainId': 'strain-2',
          'amount': 2,
          'timestamp': '2025-01-02T08:00:00.000',
        },
      ],
      'effects': [],
    });
