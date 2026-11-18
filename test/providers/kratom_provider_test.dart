import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/models/settings.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an empty configured provider exports a backup that restores cleanly',
      () async {
    // Exporting a provider with settings and a name but no records must
    // still produce a backup the app itself can preview and restore.
    final source = await KratomProvider.create(
      await SharedPreferences.getInstance(),
    );
    await source.updateSettings(const UserSettings(dailyLimit: 12.5));
    await source.updateUserName('Alin');
    final firstExport = await source.exportJson();

    SharedPreferences.setMockInitialValues({});
    final restored = await KratomProvider.create(
      await SharedPreferences.getInstance(),
    );
    final summary = await restored.previewImport(firstExport);
    expect(summary.strainCount, 0);
    expect(summary.dosageCount, 0);

    await restored.commitImport(
      _parsePayload(firstExport),
      mode: ImportMode.replace,
    );
    final secondExport = await restored.exportJson();

    final first = jsonDecode(firstExport) as Map<String, dynamic>
      ..remove('timestamp');
    final second = jsonDecode(secondExport) as Map<String, dynamic>
      ..remove('timestamp');
    expect(second, equals(first));
  });

  test('preview warns when bare doses restore under placeholders', () async {
    // A bare legacy dose list has no strain collection, so parseBackup
    // cannot know 'missing' is unknown — the preview boundary must warn.
    // The dose for local 'strain-1' reattaches and must not be counted.
    final provider = await _providerWithFixture();
    final json = jsonEncode([
      {
        'id': 'dose-legacy',
        'strainId': 'missing',
        'amount': 3,
        'timestamp': '2025-01-02T08:00:00.000',
      },
      {
        'id': 'dose-local',
        'strainId': 'strain-1',
        'amount': 2,
        'timestamp': '2025-01-02T09:00:00.000',
      },
    ]);

    final summary = await provider.previewImport(json, mode: ImportMode.merge);

    expect(summary.warnings.join('\n'), contains('placeholder'));
    expect(summary.warnings.join('\n'), contains('1 dose'));
  });

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

  test('bare-dose lists cannot replace but may merge onto local strains',
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

    // A bare legacy dose list has no explicit strains collection, so
    // replace cannot tell "keep local strains" from "no strains" and must
    // refuse — preview and direct commit agree, nothing changes.
    await expectLater(provider.previewImport(json), throwsArgumentError);
    await expectLater(
      provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
      throwsArgumentError,
    );
    expect(provider.dosages.map((d) => d.id), ['dose-1']);

    final summary =
        await provider.previewImport(json, mode: ImportMode.merge);
    expect(summary.dosageCount, 1);

    await provider.commitImport(_parsePayload(json), mode: ImportMode.merge);

    expect(provider.strains.map((s) => s.id), ['strain-1']);
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-1', 'dose-legacy']);
  });

  test('legacy bare-dose unknown strain merges under a placeholder',
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

    // Preview and commit agree: the dose is kept under a placeholder strain
    // that carries the original missing strain ID.
    final summary =
        await provider.previewImport(json, mode: ImportMode.merge);
    expect(summary.dosageCount, 1);

    await provider.commitImport(_parsePayload(json), mode: ImportMode.merge);

    expect(provider.dosages.map((d) => d.id), ['dose-1', 'dose-legacy']);
    final placeholder = provider.getStrain('missing');
    expect(placeholder, isNotNull);
    expect(placeholder!.inStock, false);
    expect(placeholder.name, 'Missing strain');
    expect(provider.getStrain('strain-1')!.name, 'Original');
  });

  test('replace import keeps orphan doses under placeholder strains',
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

    final summary = await provider.previewImport(json);
    expect(summary.dosageCount, 2);
    expect(
      summary.warnings.join('\n'),
      isNot(contains('dropped')),
      reason: 'the dose is recovered, not dropped',
    );

    await provider.commitImport(_parsePayload(json), mode: ImportMode.replace);

    expect(provider.dosages.map((d) => d.id), ['dose-2', 'dose-orphan']);
    expect(provider.getStrain('missing'), isNotNull);
    expect(provider.getStrain('missing')!.inStock, false);
  });

  test('merge import prefers a local strain over creating a placeholder',
      () async {
    SharedPreferences.setMockInitialValues({
      'strains': jsonEncode([
        {
          'id': 'missing',
          'name': 'Local Match',
          'code': 'LOC',
          'color': 7,
          'icon': 'palmate',
        },
      ]),
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
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
          'strainId': 'missing',
          'amount': 2,
          'timestamp': '2025-01-03T08:00:00.000',
        },
      ],
    });

    await provider.commitImport(_parsePayload(json), mode: ImportMode.merge);

    expect(provider.dosages.map((d) => d.id), ['dose-orphan']);
    expect(provider.strains.map((s) => s.id), ['missing', 'strain-2']);
    expect(provider.getStrain('missing')!.name, 'Local Match');
    expect(provider.getStrain('missing')!.inStock, true);
  });

  test('merge import creates a placeholder for a truly missing strain',
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
          'strainId': 'gone',
          'amount': 2,
          'timestamp': '2025-01-03T08:00:00.000',
        },
      ],
    });

    await provider.commitImport(_parsePayload(json), mode: ImportMode.merge);

    expect(provider.dosages.map((d) => d.id), ['dose-1', 'dose-orphan']);
    final placeholder = provider.getStrain('gone');
    expect(placeholder, isNotNull);
    expect(placeholder!.inStock, false);
    // The placeholder is deterministic: same missing ID, same placeholder.
    expect(placeholder.name, 'Missing strain');
    expect(placeholder.code, 'LOST');
  });

  test('merge restores a real strain over a local placeholder', () async {
    // Load kept doses under a placeholder because 'missing' was unreadable.
    // A backup carrying the real strain with the same ID must repair it —
    // and the repair must survive a reload, not just live in memory.
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
          'id': 'dose-orphan',
          'strainId': 'missing',
          'amount': 1.5,
          'timestamp': '2025-01-01T08:00:00.000',
        },
      ]),
    });
    var provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
    expect(provider.getStrain('missing')!.name, 'Missing strain');

    final json = jsonEncode({
      'version': 1,
      'strains': [
        {
          'id': 'missing',
          'name': 'Recovered Strain',
          'code': 'REC',
          'color': 42,
          'icon': 'palmate',
        },
        {
          'id': 'strain-1',
          'name': 'Incoming Overwrite',
          'code': 'NOO',
          'color': 9,
          'icon': 'oval',
        },
      ],
      'dosages': <dynamic>[],
    });
    await provider.commitImport(_parsePayload(json), mode: ImportMode.merge);

    // The placeholder is repaired; every other existing ID still wins.
    expect(provider.getStrain('missing')!.name, 'Recovered Strain');
    expect(provider.getStrain('missing')!.inStock, true);
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-orphan']);

    SharedPreferences.resetStatic();
    provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
    expect(provider.getStrain('missing')!.name, 'Recovered Strain');
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-orphan']);
  });

  test('replace requires explicit strains and dosages collections', () async {
    final provider = await _providerWithFixture();
    const strain = {
      'id': 'strain-9',
      'name': 'Incoming',
      'code': 'INC',
      'color': 9,
      'icon': 'oval',
    };
    const dose = {
      'id': 'dose-9',
      'strainId': 'strain-9',
      'amount': 2,
      'timestamp': '2025-03-01T08:00:00.000',
    };

    final cases = <String, Map<String, dynamic>>{
      'strains absent': {'dosages': [dose]},
      'strains null': {'strains': null, 'dosages': [dose]},
      'strains not a list': {'strains': 'oops', 'dosages': [dose]},
      'dosages absent': {'strains': [strain]},
      'dosages null': {'strains': [strain], 'dosages': null},
      'dosages not a list': {'strains': [strain], 'dosages': 42},
    };
    for (final entry in cases.entries) {
      final json = jsonEncode({'version': 1, ...entry.value});
      await expectLater(
        provider.previewImport(json),
        throwsArgumentError,
        reason: 'preview must reject: ${entry.key}',
      );
      await expectLater(
        provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
        throwsArgumentError,
        reason: 'commit must reject: ${entry.key}',
      );
      // Nothing local changed.
      expect(provider.strains.map((s) => s.id), ['strain-1'],
          reason: entry.key,);
      expect(provider.dosages.map((d) => d.id), ['dose-1'],
          reason: entry.key,);
    }

    // Explicit lists — including empty ones — do replace.
    await provider.commitImport(
      _parsePayload(jsonEncode({
        'version': 1,
        'strains': [strain],
        'dosages': <dynamic>[],
      }),),
      mode: ImportMode.replace,
    );
    expect(provider.strains.map((s) => s.id), ['strain-9']);
    expect(provider.dosages, isEmpty);
  });

  test('a settings-only backup cannot wipe the log', () async {
    // The review finding: a backup that parsed only settings used to
    // replace every local strain and dose with nothing.
    final provider = await _providerWithFixture();
    final json = jsonEncode({
      'version': 1,
      'settings': {'dailyLimit': 3},
    });

    await expectLater(provider.previewImport(json), throwsArgumentError);
    await expectLater(
      provider.commitImport(_parsePayload(json), mode: ImportMode.replace),
      throwsArgumentError,
    );

    expect(provider.strains.map((s) => s.id), ['strain-1']);
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
    expect(provider.settings.dailyLimit, 0);
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

  test('a malformed strain row keeps its doses under a placeholder',
      () async {
    // 'strain-bad' has an empty name: it cannot load as a strain, but its
    // dose and every unrelated record must survive.
    final strainsEncoded = jsonEncode([
      {
        'id': 'strain-bad',
        'name': '',
        'code': 'BAD',
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
      'not-a-strain',
    ]);
    SharedPreferences.setMockInitialValues({
      'strains': strainsEncoded,
      'dosages': jsonEncode([
        {
          'id': 'dose-orphan',
          'strainId': 'strain-bad',
          'amount': 1.5,
          'timestamp': '2025-01-01T08:00:00.000',
        },
        {
          'id': 'dose-1',
          'strainId': 'strain-1',
          'amount': 1.0,
          'timestamp': '2025-01-02T08:00:00.000',
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    // Nothing is lost: the valid strain keeps its dose, and the orphaned dose
    // is preserved under a placeholder with the original strain ID.
    expect(provider.getStrain('strain-1')!.name, 'Original');
    expect(provider.dosages.map((d) => d.id), ['dose-orphan', 'dose-1']);
    final placeholder = provider.getStrain('strain-bad');
    expect(placeholder, isNotNull);
    expect(placeholder!.name, 'Missing strain');
    expect(placeholder.inStock, false);

    // The damage is visible and the raw data is preserved, not rewritten.
    expect(provider.loadWarnings, isNotEmpty);
    expect(prefs.getString('strains'), strainsEncoded);
    expect(
      prefs.getString('_kratom_tracker_quarantine_strains'),
      strainsEncoded,
    );
  });

  test('warnings come only from what the current load found', () async {
    SharedPreferences.setMockInitialValues({
      'strains': '{not a list',
      'dosages': jsonEncode([
        {
          'id': 'dose-1',
          'strainId': 'strain-1',
          'amount': 1.0,
          'timestamp': '2025-01-01T08:00:00.000',
        },
      ]),
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
    expect(provider.loadWarnings, isNotEmpty);

    // A later provider still sees the damage in place and warns again —
    // from this load's own evidence, not from quarantine keys.
    SharedPreferences.resetStatic();
    final reloaded =
        await KratomProvider.create(await SharedPreferences.getInstance());
    expect(reloaded.loadWarnings, isNotEmpty);
    // Mutating memory does not silence the preserved corruption.
    await reloaded.addStrain('New', 'NEW', 2, 'oval');
    expect(reloaded.loadWarnings, isNotEmpty);

    // That save rewrote the canonical keys with healthy data. The next
    // provider finds nothing damaged — warnings are empty even though the
    // quarantined raw still sits in storage, never parsed as state.
    SharedPreferences.resetStatic();
    final healthy =
        await KratomProvider.create(await SharedPreferences.getInstance());
    expect(healthy.loadWarnings, isEmpty);
    expect(healthy.strains.map((s) => s.name), ['Missing strain', 'New']);
    expect(healthy.dosages.map((d) => d.id), ['dose-1']);
  });

  test('loadWarnings is an unmodifiable snapshot', () async {
    SharedPreferences.setMockInitialValues({'strains': 'garbage'});
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());

    expect(
      () => provider.loadWarnings.add('x'),
      throwsUnsupportedError,
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
