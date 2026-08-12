import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deleting a strain cascades to its dosages', () async {
    final provider = await _providerWithFixture();

    await provider.deleteStrain('strain-1');

    expect(provider.strains, isEmpty);
    expect(provider.dosages, isEmpty);
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

  test('mutation stamp increments for mutations, import, clear, and refresh',
      () async {
    final provider = await _providerWithFixture();
    expect(provider.lastMutationStamp, 0);

    provider.setSelectedDate(DateTime(2025, 2, 1));
    expect(provider.lastMutationStamp, 1);

    await provider.addStrain('Second', 'TWO', 2, 'Plant');
    expect(provider.lastMutationStamp, 2);

    final payload = _parsePayload(_importJson(includeExistingId: false));
    await provider.commitImport(payload, mode: ImportMode.replace);
    expect(provider.lastMutationStamp, 3);

    await provider.clearAllData();
    expect(provider.lastMutationStamp, 4);

    await provider.refreshData();
    expect(provider.lastMutationStamp, 5);
  });

  test('replace import replaces existing records', () async {
    final provider = await _providerWithFixture();
    final payload = _parsePayload(_importJson(includeExistingId: false));

    await provider.commitImport(payload, mode: ImportMode.replace);

    expect(provider.strains.map((s) => s.id), ['strain-2']);
    expect(provider.dosages.map((d) => d.id), ['dose-2']);
  });

  test('merge import unions by id and existing records win', () async {
    final provider = await _providerWithFixture();
    final payload = _parsePayload(_importJson(includeExistingId: true));

    await provider.commitImport(payload, mode: ImportMode.merge);

    expect(provider.strains.map((s) => s.id), ['strain-1', 'strain-2']);
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-1', 'dose-2']);
  });

  test('setStrainInStock persists, invalidates the usage cache, and stamps',
      () async {
    final provider = await _providerWithFixture();
    final stampBefore = provider.lastMutationStamp;
    expect(provider.getStrain('strain-1')!.inStock, true);

    await provider.setStrainInStock('strain-1', inStock: false);

    expect(provider.getStrain('strain-1')!.inStock, false);
    expect(provider.lastMutationStamp, stampBefore + 1);
    // Cache was invalidated and rebuilt — the usage row reflects the new flag.
    expect(
      provider.strainUsage.singleWhere((u) => u.strain.id == 'strain-1').
          strain.inStock,
      false,
    );

    // Toggling back to the same value is a no-op (no stamp bump).
    final stampMid = provider.lastMutationStamp;
    await provider.setStrainInStock('strain-1', inStock: false);
    expect(provider.lastMutationStamp, stampMid);
  });

  test('setStrainInStock never alters dosage history', () async {
    final provider = await _providerWithFixture();
    final dosesBefore = provider.dosages.toList();

    await provider.setStrainInStock('strain-1', inStock: false);
    await provider.setStrainInStock('strain-1', inStock: true);

    expect(provider.dosages, equals(dosesBefore));
  });

  test('setStrainInStock rejects an unknown strain', () async {
    final provider = await _providerWithFixture();
    await expectLater(
      provider.setStrainInStock('nope', inStock: false),
      throwsArgumentError,
    );
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
    });
