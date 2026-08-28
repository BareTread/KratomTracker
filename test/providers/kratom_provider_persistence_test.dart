import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/settings.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('journal prepare false and throw leave the prior generation intact',
      () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      harness.store.failAt(1, throwError: throwError);

      await expectLater(
        harness.provider.updateStrain('strain-1', name: 'Unsaved'),
        throwsA(isA<StateError>()),
      );

      await _expectFixtureEverywhere(harness);
    }
  });

  test('a failed prepare does not poison a later queued write', () async {
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

  test('partial canonical false and throw recover one prior generation',
      () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      // Prepare succeeds, strains are written, and the dosage write fails.
      harness.store.failAt(3, throwError: throwError);

      await expectLater(
        harness.provider.updateStrain('strain-1', name: 'Unsaved'),
        throwsA(isA<StateError>()),
      );

      await _expectFixtureEverywhere(harness);
    }
  });

  test('the original error survives a failed rollback and later load repairs it',
      () async {
    final harness = await _createHarness();
    // The first false is the operation error. The next throw prevents its
    // immediate recovery write, leaving the prepared journal for a fresh load.
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

  test('commit marker false and throw resolve to the prior generation',
      () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      // Prepare + four canonical writes complete; the commit marker fails.
      harness.store.failAt(6, throwError: throwError);

      await expectLater(
        harness.provider.updateStrain('strain-1', name: 'Unsaved'),
        throwsA(isA<StateError>()),
      );

      await _expectFixtureEverywhere(harness);
    }
  });

  test('cleanup false and throw preserve the committed generation', () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      harness.store.failNextRemoveOf(
        '_kratom_tracker_transaction',
        throwError: throwError,
      );

      // Cleanup is after the commit marker and is therefore best effort.
      await harness.provider.updateUserName('Bob');
      expect(harness.provider.userName, 'Bob');

      await harness.provider.refreshData();
      expect(harness.provider.userName, 'Bob');
      final reloaded = await _reloadProvider();
      expect(reloaded.userName, 'Bob');

      // The queue can clean the committed journal and continue normally.
      await harness.provider.addStrain('Later', 'LATER', 4, 'Leaf');
      expect(harness.provider.strains.map((strain) => strain.name), [
        'Original',
        'Later',
      ]);
    }
  });

  test('a failed username removal never mixes with the other fields', () async {
    for (final throwError in [false, true]) {
      final harness = await _createHarness();
      // Clear writes all fields as one generation; username removal is call 5.
      harness.store.failAt(5, throwError: throwError);

      await expectLater(
        harness.provider.clearAllData(),
        throwsA(isA<StateError>()),
      );

      await _expectFixtureEverywhere(harness);
    }
  });

  test('orphaned per-key temporary values are never preferred', () async {
    final harness = await _createHarness(withOrphanedTemp: true);

    expect(harness.provider.strains.map((strain) => strain.name), ['Original']);
    await harness.provider.refreshData();
    expect(harness.provider.strains.map((strain) => strain.name), ['Original']);
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

Future<_Harness> _createHarness({bool withOrphanedTemp = false}) async {
  final data = <String, Object>{
    'flutter.strains': jsonEncode([
      {
        'id': 'strain-1',
        'name': 'Original',
        'code': 'ONE',
        'color': 1,
        'icon': 'Leaf',
      },
    ]),
    'flutter.dosages': jsonEncode([
      {
        'id': 'dose-1',
        'strainId': 'strain-1',
        'amount': 1.0,
        'timestamp': '2025-01-01T08:00:00.000',
      },
    ]),
    'flutter.settings': jsonEncode(
      const UserSettings(
        enableNotifications: false,
        dailyLimit: 5,
        toleranceBreakInterval: 7,
      ).toJson(),
    ),
    'flutter.user_name': 'Alice',
  };
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
    final scheduledFailure = _failures.remove(_writeCount);
    final targetedFailure = isRemove && _failureRemoveKey == key;
    if (targetedFailure) {
      _failureRemoveKey = null;
    }
    if (scheduledFailure != null || targetedFailure) {
      final throwError = targetedFailure
          ? _failureRemoveThrows
          : (scheduledFailure ?? false);
      if (throwError) {
        throw StateError('simulated preferences failure for "$key"');
      }
      return false;
    }
    return write();
  }
}
