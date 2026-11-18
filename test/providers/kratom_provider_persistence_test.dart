import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/models/settings.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('one mutation runs the journal transaction in order', () async {
    final harness = await _createHarness();
    harness.store.clearLog();

    await harness.provider.updateStrain('strain-1', name: 'Renamed');

    // Prepare, the four canonical writes, commit, cleanup — nothing else.
    expect(harness.store.writes, [
      'set:_kratom_tracker_transaction',
      'set:strains',
      'set:dosages',
      'set:settings',
      'set:user_name',
      'set:_kratom_tracker_transaction',
      'remove:_kratom_tracker_transaction',
    ]);
    expect(harness.provider.getStrain('strain-1')!.name, 'Renamed');
    final reloaded = await _reloadProvider();
    expect(reloaded.getStrain('strain-1')!.name, 'Renamed');
  });

  test('a failed canonical write rolls back memory and never notifies',
      () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      // Calls: 1 prepare, 2 strains, 3 dosages — fail the third.
      harness.store.failAt(3, throwError: throwError);
      var notified = 0;
      harness.provider.addListener(() => notified++);

      await expectLater(
        harness.provider.updateStrain('strain-1', name: 'Unsaved'),
        throwsA(isA<StateError>()),
      );

      expect(notified, 0);
      // The prepared journal lets the catch block restore the previous
      // generation, so memory, refresh, and reload all agree.
      await _expectFixtureEverywhere(harness);
    }
  });

  test('a failed journal prepare writes nothing canonical', () async {
    final harness = await _createHarness();
    harness.store.clearLog();
    harness.store.failAt(1);

    await expectLater(
      harness.provider.updateStrain('strain-1', name: 'Unsaved'),
      throwsStateError,
    );

    expect(harness.store.writes, ['set:_kratom_tracker_transaction']);
    expect(harness.provider.getStrain('strain-1')!.name, 'Original');

    // A retry works: the chain was not poisoned by the failed write.
    await harness.provider.updateStrain('strain-1', name: 'Unsaved');
    expect(harness.provider.getStrain('strain-1')!.name, 'Unsaved');
    final reloaded = await _reloadProvider();
    expect(reloaded.getStrain('strain-1')!.name, 'Unsaved');
  });

  test('a failed write does not poison a later queued write', () async {
    final harness = await _createHarness();
    harness.store.failAt(1);

    final failed = harness.provider.updateStrain('strain-1', name: 'Unsaved');
    final queued = harness.provider.addStrain('Saved', 'SAVE', 3, 'Leaf');

    await expectLater(failed, throwsA(isA<StateError>()));
    await queued;

    expect(harness.provider.strains.map((strain) => strain.name), [
      'Original',
      'Saved',
    ]);
    final reloaded = await _reloadProvider();
    expect(reloaded.strains.map((strain) => strain.name), [
      'Original',
      'Saved',
    ]);
  });

  test('a prepared journal restores the previous generation', () async {
    // Canonical per-key data was partially overwritten with the newer
    // generation before the crash; the prepared journal still picks the
    // complete previous generation, not a mix.
    final harness = await _createHarness(withJournalPhase: 'prepared');

    _expectFixture(harness.provider);
    final reloaded = await _reloadProvider();
    _expectFixture(reloaded);
  });

  test('a committed journal restores the target generation', () async {
    final harness = await _createHarness(withJournalPhase: 'committed');

    expect(harness.provider.strains.map((s) => s.name), ['Newer']);
    expect(harness.provider.dosages.map((d) => d.id), ['dose-new']);
    expect(harness.provider.userName, 'Carol');
    final reloaded = await _reloadProvider();
    expect(reloaded.strains.map((s) => s.name), ['Newer']);
  });

  test('a failed journal cleanup keeps data and clears on the next load',
      () async {
    final harness = await _createHarness();
    harness.store.failNextRemoveOf('_kratom_tracker_transaction');

    await harness.provider.updateStrain('strain-1', name: 'Renamed');
    expect(harness.provider.getStrain('strain-1')!.name, 'Renamed');

    // The leftover committed journal replays its target — the same data —
    // and the next load's recovery removes it.
    final reloaded = await _reloadProvider();
    expect(reloaded.getStrain('strain-1')!.name, 'Renamed');
    expect(
      harness.prefs.getString('_kratom_tracker_transaction'),
      isNull,
    );
  });

  test('the first mutation after a journal recovery writes one transaction',
      () async {
    final harness = await _createHarness(withJournalPhase: 'committed');
    harness.store.clearLog();

    await harness.provider.addStrain('Later', 'LATE', 4, 'Leaf');

    expect(harness.store.writes, [
      'set:_kratom_tracker_transaction',
      'set:strains',
      'set:dosages',
      'set:settings',
      'set:user_name',
      'set:_kratom_tracker_transaction',
      'remove:_kratom_tracker_transaction',
    ]);
    final reloaded = await _reloadProvider();
    expect(reloaded.strains.map((s) => s.name), ['Newer', 'Later']);
  });

  test(
      'a refresh overlapping a queued mutation cannot lose the mutation',
      () async {
    // Regression: refreshData used to await the write chain without joining
    // it. A mutation enqueued during that wait could finish its writes while
    // the refresh's reload was still in flight, after which the refresh
    // assigned the pre-mutation snapshot over the new state. The store
    // answers the next getAll immediately but with the map captured at call
    // time — the exact pre-mutation view the race produced.
    final harness = await _createHarness();
    harness.store.freezeNextRead();

    final refresh = harness.provider.refreshData();
    final mutation = harness.provider.addStrain('Saved', 'SAVE', 3, 'Leaf');
    await Future.wait([refresh, mutation]);

    expect(harness.provider.strains.map((s) => s.name), [
      'Original',
      'Saved',
    ]);
    final reloaded = await _reloadProvider();
    expect(reloaded.strains.map((s) => s.name), ['Original', 'Saved']);
  });

  test(
      'a damaged canonical value is quarantined before the next save '
      'rewrites it', () async {
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.strains': '{not valid json',
    });
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    expect(provider.strains.map((s) => s.name), ['Missing strain']);
    expect(provider.dosages.map((d) => d.id), ['dose-1']);
    expect(provider.loadWarnings, isNotEmpty);
    // The damaged original is preserved verbatim — both in place and in
    // quarantine — so nothing silently rewrites it.
    expect(prefs.getString('strains'), '{not valid json');
    expect(
      prefs.getString('_kratom_tracker_quarantine_strains'),
      '{not valid json',
    );

    store.clearLog();
    await provider.addStrain('New', 'NEW', 2, 'oval');
    // Quarantine was already durable, so the journal transaction ran.
    expect(store.writes.first, 'set:_kratom_tracker_transaction');
    expect(prefs.getString('strains'), isNot('{not valid json'));

    // The healthy canonical write ends the warnings; the quarantined
    // evidence stays in storage but never warns again.
    final reloaded = await _reloadProvider();
    expect(reloaded.loadWarnings, isEmpty);
    expect(reloaded.strains.map((s) => s.name), ['Missing strain', 'New']);
    expect(reloaded.dosages.map((d) => d.id), ['dose-1']);
  });

  test(
      'a failed quarantine write gates the save and rolls memory back',
      () async {
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.strains': '{not valid json',
      'flutter.dosages': '[]',
    });
    // The load-time quarantine write fails (disk full, say); the damaged
    // value stays pending.
    store.failAt(1);
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);
    expect(await store.rawValue('_kratom_tracker_quarantine_strains'), isNull);
    expect(provider.loadWarnings, isNotEmpty);

    // The save retries quarantine first; while that fails, nothing else is
    // written and the mutation rolls back.
    store.failAt(1);
    await expectLater(
      provider.addStrain('New', 'NEW', 2, 'oval'),
      throwsStateError,
    );
    expect(await store.rawValue('strains'), '{not valid json');
    expect(provider.strains, isEmpty);

    // Storage recovers: quarantine first, then the journal transaction.
    store.clearLog();
    await provider.addStrain('New', 'NEW', 2, 'oval');
    expect(store.writes, [
      'set:_kratom_tracker_quarantine_strains',
      'set:_kratom_tracker_transaction',
      'set:strains',
      'set:dosages',
      'set:settings',
      'set:user_name',
      'set:_kratom_tracker_transaction',
      'remove:_kratom_tracker_transaction',
    ]);
    expect(
      await store.rawValue('_kratom_tracker_quarantine_strains'),
      '{not valid json',
    );

    final reloaded = await _reloadProvider();
    expect(reloaded.loadWarnings, isEmpty);
    expect(reloaded.strains.map((s) => s.name), ['New']);
  });

  test(
      'journal recovery quarantines a damaged canonical value it would '
      'overwrite', () async {
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      // The crash left a torn strains write the prepared journal rolls back.
      'flutter.strains': '{torn write',
      'flutter._kratom_tracker_transaction': _journal('prepared'),
    });
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    _expectFixture(provider);
    // Recovery preserved the torn bytes before restoring the previous
    // generation over the damaged canonical key.
    expect(
      prefs.getString('_kratom_tracker_quarantine_strains'),
      '{torn write',
    );
    expect(prefs.getString('strains'), _fixtureGeneration()['strains']);
    expect(prefs.getString('_kratom_tracker_transaction'), isNull);
  });

  test(
      'prepared recovery quarantines a parseable list carrying a malformed '
      'row before overwriting it', () async {
    // A valid JSON List whose middle row is not a map is unreadable at the
    // row level, not the collection level — recovery must still stage the
    // exact raw bytes before restoring the previous generation over them.
    final damaged = jsonEncode([
      {'id': 'strain-1', 'name': 'Original', 'code': 'ONE'},
      'not a map',
    ]);
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.strains': damaged,
      'flutter._kratom_tracker_transaction': _journal('prepared'),
    });
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    _expectFixture(provider);
    expect(
      prefs.getString('_kratom_tracker_quarantine_strains'),
      damaged,
    );
    expect(prefs.getString('strains'), _fixtureGeneration()['strains']);
    expect(prefs.getString('_kratom_tracker_transaction'), isNull);
    // The recovery itself produced evidence, so THIS load warns even though
    // the recovered rows decode cleanly.
    expect(provider.loadWarnings, isNotEmpty);

    final reloaded = await _reloadProvider();
    _expectFixture(reloaded);
    expect(reloaded.loadWarnings, isEmpty);
  });

  test(
      'a save quarantines a malformed row that appeared after the last load',
      () async {
    final harness = await _createHarness();
    // Damage lands outside the provider — a torn external write the next
    // save would otherwise silently overwrite. Two strain rows share an id,
    // and one has an empty name: valid JSON List, unreadable rows.
    final damaged = jsonEncode([
      {
        'id': 'strain-1',
        'name': '',
        'code': 'ONE',
        'color': 1,
        'icon': 'Leaf',
      },
      {
        'id': 'strain-1',
        'name': 'Duplicate',
        'code': 'DUP',
        'color': 2,
        'icon': 'oval',
      },
    ]);
    await harness.store.setValue('String', 'flutter.strains', damaged);

    await harness.provider.updateStrain('strain-1', name: 'Renamed');

    expect(
      harness.prefs.getString('_kratom_tracker_quarantine_strains'),
      damaged,
    );
    expect(harness.prefs.getString('strains'), isNot(damaged));
    final reloaded = await _reloadProvider();
    expect(reloaded.getStrain('strain-1')!.name, 'Renamed');
    expect(reloaded.loadWarnings, isEmpty);
  });

  test(
      'a failed commit marker rolls back to the prior generation',
      () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      // Prepare + four canonical writes complete; the commit marker fails,
      // so the prepared journal's previous generation wins.
      harness.store.failAt(6, throwError: throwError);

      await expectLater(
        harness.provider.updateStrain('strain-1', name: 'Unsaved'),
        throwsA(isA<StateError>()),
      );

      await _expectFixtureEverywhere(harness);
    }
  });

  test(
      'the original error survives a failed rollback and a later load '
      'repairs it', () async {
    final harness = await _createHarness();
    // Call 3 (the dosages write) fails the transaction; call 4 — the
    // rollback's first canonical repair write — throws, so the prepared
    // journal stays for a later load to finish recovery.
    harness.store.failCalls({3: false, 4: true});

    Object? error;
    try {
      await harness.provider.updateStrain('strain-1', name: 'Unsaved');
      fail('the mutation should fail');
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<StateError>());
    expect('$error', contains('dosages'));
    await _expectFixtureEverywhere(harness);
  });

  test(
      'a failed username removal in a clear never mixes with the other '
      'fields', () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      // Clear writes all four fields as one generation; the user_name
      // removal is the fifth platform call.
      harness.store.failAt(5, throwError: throwError);

      await expectLater(
        harness.provider.clearAllData(),
        throwsA(isA<StateError>()),
      );

      await _expectFixtureEverywhere(harness);
    }
  });

  test(
      'a failed quarantine write keeps the prepared journal instead of '
      'erasing damaged data', () async {
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.strains': '{torn write',
      'flutter._kratom_tracker_transaction': _journal('prepared'),
    });
    // Fail the recovery's quarantine copy. The canonical repair must not
    // run, or the damaged raw is gone for good.
    store.failAt(1);
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    _expectFixture(provider);
    // The damaged raw survived only in place (the quarantine copy failed),
    // yet THIS load still encountered it — the warning must not wait for a
    // successful copy.
    expect(provider.loadWarnings, isNotEmpty);
    expect(await store.rawValue('strains'), '{torn write');
    expect(
      await store.rawValue('_kratom_tracker_transaction'),
      _journal('prepared'),
    );

    // Once storage recovers, the next save preserves the raw and repairs.
    await provider.addStrain('New', 'NEW', 2, 'oval');
    expect(
      await store.rawValue('_kratom_tracker_quarantine_strains'),
      '{torn write',
    );
    final reloaded = await _reloadProvider();
    expect(reloaded.strains.map((s) => s.name), ['Original', 'New']);
    expect(reloaded.loadWarnings, isEmpty);
  });

  test('damaged settings warn and are quarantined instead of silently reset',
      () async {
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.settings': '{broken',
    });
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);

    expect(provider.settings, const UserSettings());
    expect(provider.loadWarnings.join('\n'), contains('settings'));
    expect(
      await store.rawValue('_kratom_tracker_quarantine_settings'),
      '{broken',
    );
    expect(provider.strains.map((s) => s.name), ['Original']);
  });

  test(
      'a replace preserves a second corrupt canonical value when quarantine '
      'already holds a different one', () async {
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.strains': '{corrupt new',
      'flutter._kratom_tracker_quarantine_strains': '{corrupt older',
    });
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);
    // This load's damage went to the numbered slot beside the older copy.
    expect(
      prefs.getString('_kratom_tracker_quarantine_strains.2'),
      '{corrupt new',
    );

    await provider.commitImport(
      (parseBackup(await provider.exportJson()) as BackupOk).payload,
      mode: ImportMode.replace,
    );

    final quarantined = prefs
        .getKeys()
        .where((k) => k.startsWith('_kratom_tracker_quarantine_'))
        .map((k) => prefs.getString(k))
        .toSet();
    expect(quarantined, containsAll(['{corrupt older', '{corrupt new']));
  });

  test('a second corrupt source is quarantined beside earlier evidence',
      () async {
    final malformedStrains = jsonEncode([
      {'id': 'strain-bad', 'name': '', 'code': 'BAD'},
      {
        'id': 'strain-1',
        'name': 'Original',
        'code': 'ONE',
        'color': 1,
        'icon': 'Leaf',
      },
    ]);
    final store = _ControlledPreferencesStore({
      ..._legacyFixture(),
      'flutter.strains': malformedStrains,
      'flutter.dosages': jsonEncode([
        {
          'id': 'dose-1',
          'strainId': 'strain-bad',
          'amount': 1.0,
          'timestamp': '2025-01-01T08:00:00.000',
        },
      ]),
      'flutter._kratom_tracker_quarantine_strains': 'earlier corruption A',
    });
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final provider = await KratomProvider.create(prefs);
    expect(provider.getStrain('strain-bad')!.name, 'Missing strain');
    expect(provider.getStrain('strain-1')!.name, 'Original');

    await provider.addStrain('Later', 'LATE', 4, 'Leaf');
    final reloaded = await _reloadProvider();

    final quarantined = prefs
        .getKeys()
        .where((k) => k.startsWith('_kratom_tracker_quarantine_'))
        .map((k) => prefs.getString(k))
        .toSet();
    expect(
      quarantined,
      containsAll(['earlier corruption A', malformedStrains]),
    );
    // The healthy save ended the warnings even though evidence remains.
    expect(reloaded.loadWarnings, isEmpty);
    expect(reloaded.dosages.map((d) => d.id), ['dose-1']);
  });

  test('orphaned per-key temporary values are never preferred', () async {
    final harness = await _createHarness(withOrphanedTemp: true);

    expect(harness.provider.strains.map((strain) => strain.name), ['Original']);
    await harness.provider.refreshData();
    expect(harness.provider.strains.map((strain) => strain.name), ['Original']);
  });
  test(
      'a clear survives stale quarantine and a leftover committed journal',
      () async {
    final harness = await _createHarness();
    // Old quarantine evidence plus a committed journal a crashed cleanup
    // left behind — a fresh load must never replay them into cleared state.
    await harness.store.setValue(
      'String',
      'flutter._kratom_tracker_quarantine_strains',
      '{old damaged strains',
    );
    await harness.store.setValue(
      'String',
      'flutter._kratom_tracker_quarantine_dosages',
      '{old damaged dosages',
    );
    await harness.store.setValue(
      'String',
      'flutter._kratom_tracker_transaction',
      _journal('committed'),
    );

    await harness.provider.clearAllData();

    final reloaded = await _reloadProvider();
    expect(reloaded.strains, isEmpty);
    expect(reloaded.dosages, isEmpty);
    expect(reloaded.userName, isNull);
    expect(reloaded.settings, const UserSettings());
    // Neither the stale quarantine keys nor the consumed journal warn.
    expect(reloaded.loadWarnings, isEmpty);
    // Platform truth, not the prefs cache: the store still decides what a
    // fresh provider sees.
    expect(
      await harness.store.rawValue('_kratom_tracker_transaction'),
      isNull,
    );
    expect(await harness.store.rawValue('strains'), '[]');
    expect(await harness.store.rawValue('dosages'), '[]');
    expect(
      await harness.store.rawValue('settings'),
      jsonEncode(const UserSettings().toJson()),
    );
    expect(await harness.store.rawValue('user_name'), isNull);
  });

  test(
      'a clear that cannot remove its journal still reloads empty — the '
      'committed clear target wins over prior state', () async {
    final harness = await _createHarness();
    harness.store.failNextRemoveOf('_kratom_tracker_transaction');

    // Journal cleanup fails; clearAllData still succeeds and leaves a
    // committed journal whose target is the EMPTY generation.
    await harness.provider.clearAllData();
    // The prefs cache dropped the key optimistically; the platform copy is
    // the one a fresh load will replay.
    expect(
      await harness.store.rawValue('_kratom_tracker_transaction'),
      isNotNull,
    );

    final reloaded = await _reloadProvider();
    // Replaying the committed target restores the cleared data, never the
    // generation the clear replaced — prior state cannot resurrect.
    expect(reloaded.strains, isEmpty);
    expect(reloaded.dosages, isEmpty);
    expect(reloaded.userName, isNull);
    expect(reloaded.settings, const UserSettings());
    expect(reloaded.loadWarnings, isEmpty);
  });

}

Future<KratomProvider> _reloadProvider() async {
  SharedPreferences.resetStatic();
  return KratomProvider.create(await SharedPreferences.getInstance());
}

Future<void> _expectFixtureEverywhere(_Harness harness) async {
  _expectFixture(harness.provider);
  await harness.provider.refreshData();
  _expectFixture(harness.provider);
  final reloaded = await _reloadProvider();
  _expectFixture(reloaded);
}

void _expectFixture(KratomProvider provider) {
  expect(provider.strains.map((strain) => strain.name), ['Original']);
  expect(provider.dosages.map((dosage) => dosage.id), ['dose-1']);
  expect(provider.settings.dailyLimit, 5);
  expect(provider.userName, 'Alice');
}

Map<String, String?> _fixtureGeneration() => {
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
      'settings': jsonEncode(
        const UserSettings(dailyLimit: 5).toJson(),
      ),
      'user_name': 'Alice',
    };

Map<String, String?> _newerGeneration() => {
      'strains': jsonEncode([
        {
          'id': 'strain-9',
          'name': 'Newer',
          'code': 'NWR',
          'color': 9,
          'icon': 'palmate',
        },
      ]),
      'dosages': jsonEncode([
        {
          'id': 'dose-new',
          'strainId': 'strain-9',
          'amount': 2.0,
          'timestamp': '2025-02-01T08:00:00.000',
        },
      ]),
      'settings': jsonEncode(
        const UserSettings(dailyLimit: 7).toJson(),
      ),
      'user_name': 'Carol',
    };

/// The shared_preferences mock applies the 'flutter.' prefix itself, so
/// fixture maps and write-log assertions use the prefixed keys.
Map<String, Object> _legacyFixture() => {
      for (final entry in _fixtureGeneration().entries)
        'flutter.${entry.key}': entry.value!,
    };

String _journal(String phase) => jsonEncode({
      'version': 1,
      'phase': phase,
      'previous': _fixtureGeneration(),
      'target': _newerGeneration(),
    });

Future<_Harness> _createHarness({
  bool withOrphanedTemp = false,
  String? withJournalPhase,
}) async {
  final data = _legacyFixture();
  if (withOrphanedTemp) {
    data['flutter._kratom_tracker_tmp_strains'] = jsonEncode([
      {
        'id': 'temp-strain',
        'name': 'Wrong temporary value',
        'code': 'TEMP',
        'color': 99,
        'icon': 'Leaf',
      },
    ]);
  }
  if (withJournalPhase == 'prepared') {
    data['flutter._kratom_tracker_transaction'] = _journal('prepared');
    // Simulate a torn canonical write: the prepared journal's recorded
    // previous generation is the intact source of truth while 'strains'
    // was already overwritten with the newer value.
    data['flutter.strains'] = _newerGeneration()['strains']!;
  } else if (withJournalPhase == 'committed') {
    data['flutter._kratom_tracker_transaction'] = _journal('committed');
    // A committed journal means the target generation already landed on
    // the canonical keys; only journal cleanup was lost to the crash.
    for (final entry in _newerGeneration().entries) {
      data['flutter.${entry.key}'] = entry.value!;
    }
  }
  final store = _ControlledPreferencesStore(data);
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  return _Harness(
    store: store,
    prefs: prefs,
    provider: await KratomProvider.create(prefs),
  );
}

class _Harness {
  const _Harness({
    required this.store,
    required this.prefs,
    required this.provider,
  });

  final _ControlledPreferencesStore store;
  final SharedPreferences prefs;
  final KratomProvider provider;
}

class _ControlledPreferencesStore extends InMemorySharedPreferencesStore {
  _ControlledPreferencesStore(super.data) : super.withData();

  int _writeCount = 0;
  final Map<int, bool> _failures = {};
  String? _failureRemoveKey;
  bool _failureRemoveThrows = false;
  bool _freezeNextRead = false;

  /// One entry per mutating platform call, 'set:key' or 'remove:key' with
  /// the 'flutter.' prefix stripped.
  final List<String> writes = [];

  void clearLog() => writes.clear();

  /// What the platform actually holds, bypassing the Dart-side cache.
  Future<Object?> rawValue(String key) async =>
      (await getAll())['flutter.$key'];

  void failAt(int relativeCall, {bool throwError = false}) {
    failCalls({relativeCall: throwError});
  }

  void failCalls(Map<int, bool> relativeFailures) {
    _failures
      ..clear()
      ..addEntries(
        relativeFailures.entries.map(
          (entry) => MapEntry(_writeCount + entry.key, entry.value),
        ),
      );
    _failureRemoveKey = null;
  }

  void failNextRemoveOf(String key, {bool throwError = false}) {
    _failures.clear();
    _failureRemoveKey = 'flutter.$key';
    _failureRemoveThrows = throwError;
  }

  /// Answers the next getAll late and with the map captured at call time —
  /// a reader racing queued writes sees the pre-write store, matching the
  /// on-disk ordering that made refreshData lose a concurrent mutation.
  void freezeNextRead() => _freezeNextRead = true;

  @override
  Future<Map<String, Object>> getAll() {
    if (_freezeNextRead) {
      _freezeNextRead = false;
      final frozen = super.getAll();
      return Future<void>.delayed(const Duration(milliseconds: 20))
          .then((_) => frozen);
    }
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    return _write(key, () => super.setValue(valueType, key, value));
  }

  @override
  Future<bool> remove(String key) {
    return _write(key, () => super.remove(key), isRemove: true);
  }

  Future<bool> _write(
    String key,
    Future<bool> Function() write, {
    bool isRemove = false,
  }) async {
    _writeCount++;
    writes.add(
      '${isRemove ? 'remove' : 'set'}:${key.replaceFirst('flutter.', '')}',
    );
    final scheduledFailure = _failures.remove(_writeCount);
    final targetedFailure = isRemove && _failureRemoveKey == key;
    if (targetedFailure) {
      _failureRemoveKey = null;
    }
    if (scheduledFailure != null || targetedFailure) {
      final throwError =
          targetedFailure ? _failureRemoveThrows : (scheduledFailure ?? false);
      if (throwError) {
        throw StateError('simulated preferences failure for "$key"');
      }
      return false;
    }
    return write();
  }
}
