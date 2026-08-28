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

  test('previewImport rejects amounts above 1000g that commit would reject',
      () async {
    final provider = await _providerWithFixture();
    final json = _importJson(includeExistingId: false, amount: 1001);

    await expectLater(provider.previewImport(json), throwsArgumentError);
    await expectLater(
      provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
      throwsArgumentError,
    );
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
  });

  test('previewImport rejects duplicate dosage IDs that commit would reject',
      () async {
    final provider = await _providerWithFixture();
    final json = jsonEncode({
      'version': 1,
      'strains': [
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
          'id': 'dose-dup',
          'strainId': 'strain-2',
          'amount': 2,
          'timestamp': '2025-01-02T08:00:00.000',
        },
        {
          'id': 'dose-dup',
          'strainId': 'strain-2',
          'amount': 3,
          'timestamp': '2025-01-03T08:00:00.000',
        },
      ],
    });

    await expectLater(provider.previewImport(json), throwsArgumentError);
    await expectLater(
      provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
      throwsArgumentError,
    );
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
  });

  test('merge import rejects an orphaned dose above 1000g', () async {
    final provider = await _providerWithFixture();
    final json = jsonEncode({
      'version': 1,
      'strains': [
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
          'id': 'dose-orphan',
          'strainId': 'strain-1',
          'amount': 1001,
          'timestamp': '2025-01-02T08:00:00.000',
        },
      ],
    });
    final payload = _parsePayload(json);
    expect(payload.dosages, isEmpty);
    expect(payload.orphanedDosages, isNotEmpty);

    await expectLater(
      provider.commitImport(payload, mode: ImportMode.merge),
      throwsArgumentError,
    );
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
  });

  test('merge import reattaches a valid orphaned dose for a local strain',
      () async {
    final provider = await _providerWithFixture();
    final json = jsonEncode({
      'version': 1,
      'strains': [
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
          'id': 'dose-orphan',
          'strainId': 'strain-1',
          'amount': 2,
          'timestamp': '2025-01-02T08:00:00.000',
        },
      ],
    });

    await provider.commitImport(_parsePayload(json), mode: ImportMode.merge);

    expect(provider.dosages.map((d) => d.id), ['dose-1', 'dose-orphan']);
  });

  test('zero-gram stored doses are quarantined and dropped', () async {
    final dosagesEncoded = jsonEncode([
      {
        'id': 'dose-1',
        'strainId': 'strain-1',
        'amount': 1.0,
        'timestamp': '2025-01-01T08:00:00.000',
      },
      {
        'id': 'dose-zero',
        'strainId': 'strain-1',
        'amount': 0,
        'timestamp': '2025-01-02T08:00:00.000',
      },
    ]);
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
      'dosages': dosagesEncoded,
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    expect(provider.dosages.map((d) => d.id), ['dose-1']);
    expect(
      prefs.getString('_kratom_tracker_quarantine_dosages'),
      dosagesEncoded,
    );
  });

  test('legacy bare-dose replace keeps local strains that attach every dose',
      () async {
    final provider = await _providerWithFixture();
    final json = jsonEncode([
      {
        'id': 'dose-legacy',
        'strainId': 'strain-1',
        'amount': 3,
        'timestamp': '2025-01-02T08:00:00.000',
      },
    ]);

    final summary = await provider.previewImport(json);
    expect(summary.dosageCount, 1);

    await provider.commitImport(_parsePayload(json), mode: ImportMode.replace);

    expect(provider.strains.map((s) => s.id), ['strain-1']);
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-legacy']);
  });

  test('legacy bare-dose unknown strain fails preview and replace equally',
      () async {
    final provider = await _providerWithFixture();
    final json = jsonEncode([
      {
        'id': 'dose-legacy',
        'strainId': 'missing',
        'amount': 3,
        'timestamp': '2025-01-02T08:00:00.000',
      },
    ]);

    await expectLater(provider.previewImport(json), throwsArgumentError);
    await expectLater(
      provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
      throwsArgumentError,
    );
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
  });

  test('replace import rejects mixed backups that would drop orphan doses',
      () async {
    final provider = await _providerWithFixture();
    final json = jsonEncode({
      'version': 1,
      'strains': [
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
        {
          'id': 'dose-orphan',
          'strainId': 'missing',
          'amount': 2,
          'timestamp': '2025-01-03T08:00:00.000',
        },
      ],
    });

    await expectLater(provider.previewImport(json), throwsArgumentError);
    await expectLater(
      provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
      throwsArgumentError,
    );
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
  });

  test('over-cap stored doses are quarantined and dropped', () async {
    final dosagesEncoded = jsonEncode([
      {
        'id': 'dose-1',
        'strainId': 'strain-1',
        'amount': 1.0,
        'timestamp': '2025-01-01T08:00:00.000',
      },
      {
        'id': 'dose-huge',
        'strainId': 'strain-1',
        'amount': 1001,
        'timestamp': '2025-01-02T08:00:00.000',
      },
    ]);
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
      'dosages': dosagesEncoded,
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    expect(provider.dosages.map((d) => d.id), ['dose-1']);
    expect(
      prefs.getString('_kratom_tracker_quarantine_dosages'),
      dosagesEncoded,
    );
  });

  test('empty and duplicate strain IDs are quarantined; valid strains remain',
      () async {
    final strainsEncoded = jsonEncode([
      {
        'id': '',
        'name': 'Empty',
        'code': 'EMP',
        'color': 1,
        'icon': 'Leaf',
      },
      {
        'id': 'strain-1',
        'name': 'Original',
        'code': 'ONE',
        'color': 1,
        'icon': 'Leaf',
      },
      {
        'id': 'strain-1',
        'name': 'Duplicate',
        'code': 'DUP',
        'color': 2,
        'icon': 'Plant',
      },
    ]);
    SharedPreferences.setMockInitialValues({
      'strains': strainsEncoded,
      'dosages': jsonEncode([
        {
          'id': 'dose-1',
          'strainId': 'strain-1',
          'amount': 1.0,
          'timestamp': '2025-01-01T08:00:00.000',
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    expect(provider.strains.map((s) => s.id), ['strain-1']);
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
    expect(
      prefs.getString('_kratom_tracker_quarantine_strains'),
      strainsEncoded,
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

String _importJson({required bool includeExistingId, double amount = 2}) =>
    jsonEncode({
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
          'amount': amount,
          'timestamp': '2025-01-02T08:00:00.000',
        },
      ],
    });
