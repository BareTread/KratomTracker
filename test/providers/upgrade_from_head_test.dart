import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/settings.dart';
import 'package:kratom_tracker_plus/models/strain.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  group('upgrade from v2.17.4 (HEAD) storage', () {
    test(
        'HEAD per-key storage loads identically, warns nothing, writes '
        'nothing, and saves with HEAD\'s journal transaction', () async {
      final strainMaps = _headStrains();
      final doseMaps = _headDosages();
      final strainsEncoded = jsonEncode(strainMaps);
      final dosagesEncoded = jsonEncode(doseMaps);
      final settingsEncoded = jsonEncode(_headSettings());
      final harness = await _install({
        'flutter.strains': strainsEncoded,
        'flutter.dosages': dosagesEncoded,
        'flutter.settings': settingsEncoded,
        'flutter.user_name': 'Sam',
        'flutter.darkMode': true,
      });
      final provider = harness.provider;
      final prefs = harness.prefs;

      // Loading HEAD data must read, never write.
      expect(
        harness.store.writes,
        isEmpty,
        reason: 'load must not write to storage',
      );
      expect(provider.loadWarnings, isEmpty);
      expect(
        provider.strains,
        [for (final map in strainMaps) Strain.fromJson(map)],
      );
      for (var i = 0; i < strainMaps.length; i++) {
        final loaded = provider.strains[i];
        final map = strainMaps[i];
        expect(loaded.id, map['id'], reason: 'strain $i id');
        expect(loaded.name, map['name'], reason: 'strain $i name');
        expect(loaded.code, map['code'], reason: 'strain $i code');
        expect(loaded.color, map['color'], reason: 'strain $i color');
        expect(loaded.inStock, map['inStock'], reason: 'strain $i inStock');
      }
      expect(
        provider.dosages,
        [for (final map in doseMaps) Dosage.fromJson(map)],
      );
      expect(
        provider.settings,
        const UserSettings(
          dailyLimit: 12.5,
          measurementUnit: 'g',
          performanceMode: true,
        ),
      );
      expect(provider.userName, 'Sam');
      expect(ThemeProvider(prefs).themeMode, ThemeMode.dark);

      // An unchanged save — the user name stays 'Sam' — still runs HEAD's
      // transaction: prepare, the four canonical writes, commit, cleanup.
      await provider.updateUserName('Sam');
      expect(harness.store.writes, [
        'set:_kratom_tracker_transaction',
        'set:strains',
        'set:dosages',
        'set:settings',
        'set:user_name',
        'set:_kratom_tracker_transaction',
        'remove:_kratom_tracker_transaction',
      ]);

      // Every canonical key now holds HEAD's own encoding of the same
      // state — computed from literal constants here, not echoed from the
      // provider. The only legal diffs from the stored fixture are the
      // fields the new model no longer serialises (obsolete settings keys)
      // and icons already canonicalised by Strain.fromJson at load: legacy
      // 'leaf'/'Leaf' → 'lance', and 'spa' — not in any icon table —
      // resolves to 'trifol' via the deterministic code hash for 'GML'.
      final expectedStrains = jsonEncode([
        {
          'id': 'strain-1',
          'name': 'Red Bali',
          'code': 'RBL',
          'color': 0xFF4CAF50,
          'icon': 'lance',
          'inStock': true,
        },
        {
          'id': 'strain-2',
          'name': 'Maeng "Da" — ñ',
          'code': 'MGD',
          'color': 0xFF2196F3,
          'icon': 'lance',
          'inStock': true,
        },
        {
          'id': 'strain-3',
          'name': 'Green Malay',
          'code': 'GML',
          'color': 0xFFFF9800,
          'icon': 'trifol',
          'inStock': false,
        },
        {
          'id': 'strain-4',
          'name': 'White Borneo',
          'code': 'WBR',
          'color': 0xFF9C27B0,
          'icon': 'lance',
          'inStock': true,
        },
        {
          'id': 'strain-5',
          'name': 'Gold Reserve',
          'code': 'GLD',
          'color': 0xFF795548,
          'icon': 'oval',
          'inStock': true,
        },
      ]);
      const expectedSettings =
          '{"dailyLimit":12.5,"measurementUnit":"g","performanceMode":true}';
      expect(prefs.getString('strains'), expectedStrains);
      // The dose list must survive the save byte-for-byte, not just
      // value-equal against the decoded fixture.
      expect(prefs.getString('dosages'), dosagesEncoded);
      expect(prefs.getString('settings'), expectedSettings);
      expect(prefs.getString('user_name'), 'Sam');
      expect(prefs.getBool('darkMode'), true);
      expect(prefs.getString('_kratom_tracker_transaction'), isNull);
      expect(prefs.getString('_kratom_tracker_state'), isNull);

      // Restart: the canonical keys alone reproduce the fixture state —
      // asserted against the fixture maps, not against provider memory.
      final preRestartExport = await _exportWithoutTimestamp(provider);
      var reloaded = await _reloadProvider();
      expect(
        reloaded.strains,
        [for (final map in strainMaps) Strain.fromJson(map)],
      );
      expect(
        reloaded.dosages,
        [for (final map in doseMaps) Dosage.fromJson(map)],
      );
      expect(
        reloaded.settings,
        const UserSettings(
          dailyLimit: 12.5,
          measurementUnit: 'g',
          performanceMode: true,
        ),
      );
      expect(reloaded.userName, 'Sam');
      expect(reloaded.loadWarnings, isEmpty);
      expect(await _exportWithoutTimestamp(reloaded), preRestartExport);

      // A second save transacts over the upgraded keys and round-trips.
      harness.store.clearLog();
      final beforeSecondRestart = reloaded;
      await beforeSecondRestart.updateUserName('Samantha');
      expect(harness.store.writes, [
        'set:_kratom_tracker_transaction',
        'set:strains',
        'set:dosages',
        'set:settings',
        'set:user_name',
        'set:_kratom_tracker_transaction',
        'remove:_kratom_tracker_transaction',
      ]);

      reloaded = await _reloadProvider();
      _expectSameState(
        reloaded,
        beforeSecondRestart,
        context: 'after second restart',
      );
      expect(reloaded.userName, 'Samantha');
      expect(reloaded.dosages, provider.dosages);
      expect(reloaded.loadWarnings, isEmpty);
      expect(
        await _exportWithoutTimestamp(reloaded),
        await _exportWithoutTimestamp(beforeSecondRestart),
      );
    });

    test(
        'a HEAD install with no user name and no settings key loads with '
        'defaults and no warnings', () async {
      final harness = await _install({
        'flutter.strains': jsonEncode(_headStrains()),
        'flutter.dosages': jsonEncode(_headDosages().take(3).toList()),
      });
      final provider = harness.provider;
      expect(harness.store.writes, isEmpty);
      expect(provider.loadWarnings, isEmpty);
      expect(provider.userName, isNull);
      expect(provider.settings, const UserSettings());
      expect(provider.strains, hasLength(5));
      expect(provider.dosages, hasLength(3));
    });

    test(
        'a lingering committed HEAD journal equal to canonical data loads '
        'identically with no warnings', () async {
      final strainMaps = _headStrains();
      final doseMaps = _headDosages();
      final canonical = <String, String?>{
        'strains': jsonEncode(strainMaps),
        'dosages': jsonEncode(doseMaps),
        'settings': jsonEncode(_headSettings()),
        'user_name': 'Sam',
      };
      // A crash after commit can leave the journal behind. 'committed'
      // recovers the target generation — equal to the canonical per-key
      // data here — so the load is identical and silent.
      final journal = jsonEncode({
        'version': 1,
        'phase': 'committed',
        'previous': <String, String?>{
          'strains': jsonEncode([
            {
              'id': 'strain-old',
              'name': 'Pre-commit strain',
              'code': 'OLD',
              'color': 1,
              'icon': 'oval',
              'inStock': true,
            },
          ]),
          'dosages': '[]',
          'settings': null,
          'user_name': 'Before',
        },
        'target': canonical,
      });
      final harness = await _install({
        for (final entry in canonical.entries)
          'flutter.${entry.key}': entry.value!,
        'flutter._kratom_tracker_transaction': journal,
      });
      final provider = harness.provider;
      expect(harness.store.writes, ['remove:_kratom_tracker_transaction']);
      expect(
        harness.prefs.getString('_kratom_tracker_transaction'),
        isNull,
      );
      expect(provider.loadWarnings, isEmpty);
      expect(
        provider.strains,
        [for (final map in strainMaps) Strain.fromJson(map)],
      );
      expect(
        provider.dosages,
        [for (final map in doseMaps) Dosage.fromJson(map)],
      );
      expect(
        provider.settings,
        const UserSettings(
          dailyLimit: 12.5,
          measurementUnit: 'g',
          performanceMode: true,
        ),
      );
      expect(provider.userName, 'Sam');
    });
  });

  group('healthy data never triggers recovery warnings', () {
    // One case per warning trigger, each built from the healthy state that
    // sits closest to it. Triggers: malformed strain or dose rows, a dose
    // whose strain is missing, undecodable settings, quarantine keys left
    // by an earlier damaged load.
    final edgeCases = <String, Future<void> Function(KratomProvider)>{
      // userName null removes the key; the next load treats absent as fine.
      'null user name': (p) =>
          p.updateUserName(null),
      // Empty collections encode as "[]" strings, not as absent keys.
      'everything cleared (empty lists, default settings)': (p) =>
          p.clearAllData(),
      // Deleting a strain removes its doses: no orphan placeholder.
      'strain deleted with its doses (missing-strain trigger)': (p) async {
        await p.addStrain('Gone', 'GON', 1, 'oval');
        await p.addDosage(p.strains.last.id, 1, DateTime(2025, 1, 1));
        await p.deleteStrain(p.strains.last.id);
      },
      // Boundary amounts that load validation accepts.
      'amount exactly 1000 and tiny amount (malformed-dose trigger)':
          (p) async {
        await p.addDosage(p.strains.first.id, 1000, DateTime(2025, 1, 1));
        await p.addDosage(p.strains.first.id, 1e-9, DateTime(2025, 1, 2));
      },
      // Settings at extremes still decode as a map.
      'extreme settings (settings trigger)': (p) => p.updateSettings(
            const UserSettings(
              dailyLimit: 1e300,
              measurementUnit: '',
              performanceMode: true,
            ),
          ),
    };
    for (final entry in edgeCases.entries) {
      test('healthy edge state loads silently: ${entry.key}', () async {
        final harness = await _install({});
        await harness.provider.addStrain('Base', 'BAS', 2, 'lance');
        await entry.value(harness.provider);
        final reloaded = await _reloadProvider();
        expect(reloaded.loadWarnings, isEmpty);
        expect(reloaded.strains, harness.provider.strains);
        expect(reloaded.dosages, harness.provider.dosages);
        expect(reloaded.settings, harness.provider.settings);
        expect(reloaded.userName, harness.provider.userName);
        expect(
          harness.prefs
              .getKeys()
              .where((k) => k.startsWith('_kratom_tracker_quarantine_')),
          isEmpty,
        );
      });
    }

    test('random valid states round-trip save->load with zero warnings',
        () async {
      const seed = 0xC0FFEE;
      final rng = Random(seed);
      for (var i = 0; i < 60; i++) {
        final where = 'seed $seed iteration $i';
        final harness = await _install({});
        final provider = harness.provider;

        final strainCount = 1 + rng.nextInt(8);
        for (var s = 0; s < strainCount; s++) {
          await provider.addStrain(
            _awkwardName(rng),
            'C${rng.nextInt(10000)}',
            (rng.nextInt(0x10000) << 16) | rng.nextInt(0x10000),
            _icons[rng.nextInt(_icons.length)],
            inStock: rng.nextBool(),
          );
        }
        final doseCount = 1 + rng.nextInt(24);
        for (var d = 0; d < doseCount; d++) {
          final strain = provider.strains[rng.nextInt(provider.strains.length)];
          await provider.addDosage(
            strain.id,
            _randomAmount(rng),
            _randomTimestamp(rng),
            notes: _randomNotes(rng),
          );
        }
        // Random edits and deletes, all through the public API.
        if (provider.dosages.isNotEmpty && rng.nextBool()) {
          final dose = provider.dosages[rng.nextInt(provider.dosages.length)];
          await provider.updateDosage(
            id: dose.id,
            strainId: provider.strains[rng.nextInt(provider.strains.length)].id,
            amount: _randomAmount(rng),
            timestamp: _randomTimestamp(rng),
            notes: _randomNotes(rng),
          );
        }
        if (provider.dosages.length > 1 && rng.nextBool()) {
          await provider.deleteDosage(
            provider.dosages[rng.nextInt(provider.dosages.length)].id,
          );
        }
        if (provider.strains.length > 1 && rng.nextInt(3) == 0) {
          await provider.deleteStrain(
            provider.strains[rng.nextInt(provider.strains.length)].id,
          );
        }
        if (rng.nextBool()) {
          final strain = provider.strains[rng.nextInt(provider.strains.length)];
          await provider.updateStrain(
            strain.id,
            name: _awkwardName(rng),
            icon: _icons[rng.nextInt(_icons.length)],
            inStock: rng.nextBool(),
          );
        }
        if (rng.nextBool()) {
          final strain = provider.strains[rng.nextInt(provider.strains.length)];
          await provider.setStrainInStock(
            strain.id,
            inStock: rng.nextBool(),
          );
        }
        await provider.updateSettings(
          UserSettings(
            dailyLimit: rng.nextBool() ? 0 : rng.nextDouble() * 40,
            measurementUnit: _units[rng.nextInt(_units.length)],
            performanceMode: rng.nextBool(),
          ),
        );
        await provider.updateUserName(_randomUserName(rng));

        expect(
          provider.loadWarnings,
          isEmpty,
          reason: '$where: pre-restart warnings',
        );

        final expectedStrains = provider.strains.toList();
        final expectedDosages = provider.dosages.toList();
        final expectedSettings = provider.settings;
        final expectedName = provider.userName;
        final expectedExport = await _exportWithoutTimestamp(provider);

        var reloaded = await _reloadProvider();
        expect(
          reloaded.loadWarnings,
          isEmpty,
          reason: '$where: restart warnings',
        );
        expect(
          reloaded.strains,
          expectedStrains,
          reason: '$where: strains after restart',
        );
        expect(
          reloaded.dosages,
          expectedDosages,
          reason: '$where: dosages after restart',
        );
        expect(
          reloaded.settings,
          expectedSettings,
          reason: '$where: settings after restart',
        );
        expect(
          reloaded.userName,
          expectedName,
          reason: '$where: userName after restart',
        );
        expect(
          await _exportWithoutTimestamp(reloaded),
          expectedExport,
          reason: '$where: export after restart',
        );

        // One more mutation transacts over the canonical keys and survives a
        // second restart.
        final strain = reloaded.strains[rng.nextInt(reloaded.strains.length)];
        final added = await reloaded.addDosage(
          strain.id,
          _randomAmount(rng),
          _randomTimestamp(rng),
          notes: _randomNotes(rng),
        );
        reloaded = await _reloadProvider();
        expect(
          reloaded.loadWarnings,
          isEmpty,
          reason: '$where: second restart warnings',
        );
        expect(
          reloaded.dosages.last,
          added,
          reason: '$where: added dose after second restart',
        );
      }
    });
  });
}

const _icons = ['Leaf', 'spa', 'lance', 'oval', 'zzz'];
const _units = ['g', 'mg', 'oz', 'ml', 'µg'];

/// HEAD's per-key strain fixture: one out of stock, one legacy icon name
/// ('Leaf' normalises to 'lance' on read), one unicode/quote name.
List<Map<String, dynamic>> _headStrains() => [
      {
        'id': 'strain-1',
        'name': 'Red Bali',
        'code': 'RBL',
        'color': 0xFF4CAF50,
        'icon': 'leaf',
        'inStock': true,
      },
      {
        'id': 'strain-2',
        'name': 'Maeng "Da" — ñ',
        'code': 'MGD',
        'color': 0xFF2196F3,
        'icon': 'Leaf',
        'inStock': true,
      },
      {
        'id': 'strain-3',
        'name': 'Green Malay',
        'code': 'GML',
        'color': 0xFFFF9800,
        'icon': 'spa',
        'inStock': false,
      },
      {
        'id': 'strain-4',
        'name': 'White Borneo',
        'code': 'WBR',
        'color': 0xFF9C27B0,
        'icon': 'lance',
        'inStock': true,
      },
      {
        'id': 'strain-5',
        'name': 'Gold Reserve',
        'code': 'GLD',
        'color': 0xFF795548,
        'icon': 'oval',
        'inStock': true,
      },
    ];

/// ~200 HEAD doses over ~6 months with local (no Z) ISO timestamps,
/// including a 23:59:59.999 / 00:00:00.000 boundary pair, microseconds,
/// newline-and-quote notes, null notes, and a long-double amount.
List<Map<String, dynamic>> _headDosages() {
  final strainIds = [for (final s in _headStrains()) s['id'] as String];
  final start = DateTime(2025, 4, 1, 6, 30);
  return [
    for (var i = 0; i < 200; i++)
      {
        'id': 'dose-${i.toString().padLeft(4, '0')}',
        'strainId': strainIds[i % strainIds.length],
        'amount': i == 5 ? 2.3333333333333335 : 1.0 + (i % 60) * 0.1,
        'timestamp': (switch (i) {
          0 => DateTime(2025, 7, 4, 23, 59, 59, 999),
          1 => DateTime(2025, 7, 5),
          2 => DateTime(2025, 7, 5, 7, 30, 0, 123, 456),
          _ => start.add(Duration(hours: i * 21, minutes: (i * 37) % 60)),
        })
            .toIso8601String(),
        'notes': switch (i % 11) {
          0 => 'split dose\nsecond "line" of notes',
          3 => 'plain note $i',
          _ => null,
        },
      },
  ];
}

/// HEAD's full UserSettings.toJson — the legacy keys must be ignored.
Map<String, dynamic> _headSettings() => {
      'enableNotifications': true,
      'morningReminder': 8,
      'morningReminderMinute': 30,
      'eveningReminder': 21,
      'eveningReminderMinute': 15,
      'dailyLimit': 12.5,
      'enableToleranceTracking': true,
      'toleranceBreakInterval': 14,
      'measurementUnit': 'g',
      'performanceMode': true,
    };

String _awkwardName(Random rng) {
  final pool = [
    'Maeng "Da" — ñ',
    r'White\Borneo',
    'Green\nMalay',
    'Red 🌿 Bali',
    'x' * 200,
    '  padded  ',
  ];
  return pool[rng.nextInt(pool.length)];
}

double _randomAmount(Random rng) =>
    rng.nextInt(20) == 0 ? 1000.0 : 0.001 + rng.nextDouble() * 999;

/// Timestamps across ~2 years; every tenth value lands on a midnight or
/// end-of-day boundary.
DateTime _randomTimestamp(Random rng) {
  switch (rng.nextInt(10)) {
    case 0:
      return DateTime(
        2024 + rng.nextInt(2),
        1 + rng.nextInt(12),
        1 + rng.nextInt(28),
      );
    case 1:
      return DateTime(
        2024 + rng.nextInt(2),
        1 + rng.nextInt(12),
        1 + rng.nextInt(28),
        23,
        59,
        59,
        999,
      );
    default:
      return DateTime(2024, 1, 1).add(
        Duration(
          seconds: rng.nextInt(2 * 366 * 24 * 3600),
          microseconds: rng.nextInt(1000000),
        ),
      );
  }
}

String? _randomNotes(Random rng) {
  final pool = <String?>[null, '', '  ', 'multi\nline "note"', 'plain'];
  return pool[rng.nextInt(pool.length)];
}

String? _randomUserName(Random rng) {
  final pool = <String?>[null, '  ', 'Sam', 'O"\'Neíl 🌿', 'n' * 150];
  return pool[rng.nextInt(pool.length)];
}

/// exportJson contains a volatile 'timestamp' field; drop it before
/// comparing exports.
Future<Map<String, dynamic>> _exportWithoutTimestamp(
  KratomProvider provider,
) async {
  final map = jsonDecode(await provider.exportJson()) as Map<String, dynamic>;
  map.remove('timestamp');
  return map;
}

void _expectSameState(
  KratomProvider actual,
  KratomProvider expected, {
  required String context,
}) {
  expect(actual.strains, expected.strains, reason: '$context: strains');
  expect(actual.dosages, expected.dosages, reason: '$context: dosages');
  expect(actual.settings, expected.settings, reason: '$context: settings');
  expect(actual.userName, expected.userName, reason: '$context: userName');
}

Future<_Harness> _install(Map<String, Object> data) async {
  final store = _LoggingPreferencesStore(data);
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  return _Harness(store, prefs, await KratomProvider.create(prefs));
}

Future<KratomProvider> _reloadProvider() async {
  SharedPreferences.resetStatic();
  return KratomProvider.create(await SharedPreferences.getInstance());
}

class _Harness {
  const _Harness(this.store, this.prefs, this.provider);

  final _LoggingPreferencesStore store;
  final SharedPreferences prefs;
  final KratomProvider provider;
}

/// Records every mutating platform call as 'set:key' or 'remove:key',
/// with the 'flutter.' prefix the shared_preferences mock applies itself.
class _LoggingPreferencesStore extends InMemorySharedPreferencesStore {
  _LoggingPreferencesStore(super.data) : super.withData();

  final List<String> writes = [];

  void clearLog() => writes.clear();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writes.add('set:${key.replaceFirst('flutter.', '')}');
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    writes.add('remove:${key.replaceFirst('flutter.', '')}');
    return super.remove(key);
  }
}
