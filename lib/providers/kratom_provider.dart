import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/backup_codec.dart';
import '../domain/date_utils.dart';
import '../domain/strain_usage.dart';
import '../models/dosage.dart';
import '../models/settings.dart';
import '../models/strain.dart';

enum ImportMode { replace, merge }

const _transactionGenerationKeys = <String>[
  'strains',
  'dosages',
  'settings',
  'user_name',
];

class KratomProvider with ChangeNotifier {
  KratomProvider._(this._prefs);

  static const _strainsKey = 'strains';
  static const _dosagesKey = 'dosages';
  static const _settingsKey = 'settings';
  static const _userNameKey = 'user_name';
  static const _transactionKey = '_kratom_tracker_transaction';
  static const _quarantinePrefix = '_kratom_tracker_quarantine_';

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();
  List<Strain> _strains = [];
  List<Dosage> _dosages = [];
  UserSettings _settings = const UserSettings(
    enableNotifications: false,
    toleranceBreakInterval: 7,
  );
  DateTime _selectedDate = DateTime.now();
  String? _userName;
  bool _isReady = false;
  int _lastMutationStamp = 0;
  Future<void> _writeChain = Future<void>.value();
  final Map<DateTime, double> _dailyTotalCache = {};
  List<StrainUsage>? _strainUsageCache;
  DateTime? _strainUsageCacheDay;

  static Future<KratomProvider> create(SharedPreferences prefs) async {
    final provider = KratomProvider._(prefs);
    await provider._loadData();
    provider._isReady = true;
    return provider;
  }

  bool get isReady => _isReady;
  bool get isLoading => !_isReady;
  List<Strain> get strains => UnmodifiableListView(_strains);
  List<Dosage> get dosages => UnmodifiableListView(_dosages);
  UserSettings get settings => _settings;
  String? get userName => _userName;
  DateTime get selectedDate => _selectedDate;
  int get lastMutationStamp => _lastMutationStamp;

  Strain? getStrain(String id) {
    for (final strain in _strains) {
      if (strain.id == id) return strain;
    }
    return null;
  }

  String strainLabel(String id) => getStrain(id)?.name ?? 'Unknown strain';

  List<Dosage> getDosagesForDate(DateTime date) {
    final result = _dosages
        .where((dose) => inRangeInclusive(dose.timestamp, date, date))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  List<Dosage> getDosagesForDateRange(DateTime start, DateTime end) {
    return _dosages
        .where((dose) => inRangeInclusive(dose.timestamp, start, end))
        .toList(growable: false);
  }

  double totalForDate(DateTime date) {
    final day = startOfDay(date);
    return _dailyTotalCache.putIfAbsent(
      day,
      () => getDosagesForDate(day).fold(0, (sum, dose) => sum + dose.amount),
    );
  }

  List<StrainUsage> get strainUsage {
    final today = startOfDay(DateTime.now());
    if (_strainUsageCache == null || _strainUsageCacheDay != today) {
      _strainUsageCache = computeStrainUsage(_strains, _dosages);
      _strainUsageCacheDay = today;
    }
    return UnmodifiableListView(_strainUsageCache!);
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = startOfDay(date);
    _notifyMutation();
  }

  Future<void> addStrain(
    String name,
    String code,
    int color,
    String icon, {
    bool inStock = true,
  }) {
    return _persistMutation(
      mutate: () {
        if (name.trim().isEmpty ||
            code.trim().isEmpty ||
            icon.trim().isEmpty) {
          throw ArgumentError('Strain name, code, and icon must not be empty');
        }
        _strains = [
          ..._strains,
          Strain(
            id: _uuid.v4(),
            name: name.trim(),
            code: code.trim(),
            color: color,
            icon: icon,
            inStock: inStock,
          ),
        ];
        _invalidateComputedData();
        return true;
      },
    );
  }

  Future<void> updateStrain(
    String id, {
    String? name,
    String? code,
    int? color,
    String? icon,
    bool? inStock,
  }) {
    return _persistMutation(
      mutate: () {
        final index = _strains.indexWhere((strain) => strain.id == id);
        if (index < 0) {
          throw ArgumentError.value(id, 'id', 'unknown strain');
        }
        if (name != null && name.trim().isEmpty ||
            code != null && code.trim().isEmpty ||
            icon != null && icon.trim().isEmpty) {
          throw ArgumentError('Strain name, code, and icon must not be empty');
        }
        final updated = _strains[index].copyWith(
          name: name?.trim(),
          code: code?.trim(),
          color: color,
          icon: icon,
          inStock: inStock,
        );
        _strains = List<Strain>.of(_strains)..[index] = updated;
        _invalidateComputedData();
        return true;
      },
    );
  }

  /// Toggles whether a strain is currently on hand. A display/ranking concern
  /// only — never touches dosage records. Follows the same persist + cache
  /// invalidation + mutation-stamp path as [updateStrain].
  Future<void> setStrainInStock(String id, {required bool inStock}) {
    return _persistMutation(
      mutate: () {
        final index = _strains.indexWhere((strain) => strain.id == id);
        if (index < 0) {
          throw ArgumentError.value(id, 'id', 'unknown strain');
        }
        if (_strains[index].inStock == inStock) return false;
        final updated = _strains[index].copyWith(inStock: inStock);
        _strains = List<Strain>.of(_strains)..[index] = updated;
        _invalidateComputedData();
        return true;
      },
    );
  }

  Future<void> deleteStrain(String id) {
    return _persistMutation(
      mutate: () {
        if (!_strains.any((strain) => strain.id == id)) {
          throw ArgumentError.value(id, 'id', 'unknown strain');
        }
        _strains = _strains.where((strain) => strain.id != id).toList();
        _dosages = _dosages.where((dose) => dose.strainId != id).toList();
        _invalidateComputedData();
        return true;
      },
    );
  }

  /// Returns the created dosage so callers can act on it without having to
  /// diff the list to find the new id.
  Future<Dosage> addDosage(
    String strainId,
    double amount,
    DateTime timestamp, {
    String? notes,
  }) async {
    late Dosage dosage;
    await _persistMutation(
      mutate: () {
        _validateDosage(strainId, amount);
        dosage = Dosage(
          id: _uuid.v4(),
          strainId: strainId,
          amount: amount,
          timestamp: timestamp,
          notes: notes,
        );
        _dosages = [..._dosages, dosage];
        _invalidateComputedData();
        return true;
      },
    );
    return dosage;
  }

  Future<void> updateDosage({
    required String id,
    required String strainId,
    required double amount,
    required DateTime timestamp,
    String? notes,
  }) {
    return _persistMutation(
      mutate: () {
        final index = _dosages.indexWhere((dose) => dose.id == id);
        if (index < 0) {
          throw ArgumentError.value(id, 'id', 'unknown dosage');
        }
        _validateDosage(strainId, amount);
        final updated = Dosage(
          id: id,
          strainId: strainId,
          amount: amount,
          timestamp: timestamp,
          notes: notes,
        );
        _dosages = List<Dosage>.of(_dosages)..[index] = updated;
        _invalidateComputedData();
        return true;
      },
    );
  }

  Future<void> deleteDosage(String id) {
    return _persistMutation(
      mutate: () {
        if (!_dosages.any((dose) => dose.id == id)) {
          throw ArgumentError.value(id, 'id', 'unknown dosage');
        }
        _dosages = _dosages.where((dose) => dose.id != id).toList();
        _invalidateComputedData();
        return true;
      },
    );
  }

  Future<void> updateSettings(UserSettings settings) {
    return _persistMutation(
      mutate: () {
        if (!settings.dailyLimit.isFinite || settings.dailyLimit < 0) {
          throw ArgumentError.value(
            settings.dailyLimit,
            'settings.dailyLimit',
            'must be finite and non-negative',
          );
        }
        _settings = settings;
        return true;
      },
    );
  }

  Future<void> updateUserName(String? name) {
    final normalized = name?.trim();
    final nextName =
        normalized == null || normalized.isEmpty ? null : normalized;
    return _persistMutation(
      mutate: () {
        _userName = nextName;
        return true;
      },
    );
  }

  Future<String> exportJson() async {
    return jsonEncode({
      'version': currentBackupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'strains': _strains.map((strain) => strain.toJson()).toList(),
      'dosages': _dosages.map((dose) => dose.toJson()).toList(),
      'settings': _settings.toJson(),
      if (_userName != null) 'userName': _userName,
    });
  }

  Future<BackupSummary> previewImport(
    String jsonText, {
    ImportMode mode = ImportMode.replace,
  }) async {
    final result = parseBackup(jsonText);
    switch (result) {
      case BackupOk(:final payload, :final summary):
        _prepareImport(payload, mode);
        return summary;
      case BackupError(:final message, :final details):
        throw FormatException([message, ...details].join('\n'));
    }
  }

  Future<void> commitImport(
    BackupPayload p, {
    required ImportMode mode,
  }) {
    return _persistMutation(
      mutate: () {
        final plan = _prepareImport(p, mode);
        _strains = plan.strains;
        _dosages = plan.dosages;
        _settings = plan.settings;
        _userName = plan.userName;
        _invalidateComputedData();
        return true;
      },
    );
  }

  Future<void> clearAllData() {
    const settings = UserSettings(
      enableNotifications: false,
      toleranceBreakInterval: 7,
    );
    return _persistMutation(
      mutate: () {
        _strains = [];
        _dosages = [];
        _settings = settings;
        _userName = null;
        _invalidateComputedData();
        return true;
      },
    );
  }

  Future<void> refreshData() async {
    await _writeChain;
    await _loadData();
    _notifyMutation();
  }

  Future<void> _loadData() async {
    final generation = await _resolvePendingTransaction(reload: true);
    final strainsEncoded = generation == null
        ? _prefs.getString(_strainsKey)
        : generation[_strainsKey];
    final dosagesEncoded = generation == null
        ? _prefs.getString(_dosagesKey)
        : generation[_dosagesKey];
    final strains = _decodeList(strainsEncoded, Strain.fromJson);
    final dosages = _decodeList(dosagesEncoded, Dosage.fromJson);
    final seenStrainIds = <String>{};
    final validStrains = <Strain>[];
    var strainsCorrupt = strains.hadMalformed;
    for (final strain in strains.values) {
      if (strain.id.isEmpty ||
          strain.name.isEmpty ||
          strain.code.isEmpty ||
          !seenStrainIds.add(strain.id)) {
        strainsCorrupt = true;
        continue;
      }
      validStrains.add(strain);
    }
    final strainIds = seenStrainIds;
    final seenDoseIds = <String>{};
    final validDosages = <Dosage>[];
    var dosagesCorrupt = dosages.hadMalformed;
    for (final dose in dosages.values) {
      if (dose.id.isEmpty ||
          dose.strainId.isEmpty ||
          !dose.amount.isFinite ||
          dose.amount <= 0 ||
          dose.amount > 1000 ||
          !strainIds.contains(dose.strainId) ||
          !seenDoseIds.add(dose.id)) {
        dosagesCorrupt = true;
        continue;
      }
      validDosages.add(dose);
    }
    await _quarantineCorrupt(_strainsKey, strainsEncoded, strainsCorrupt);
    await _quarantineCorrupt(_dosagesKey, dosagesEncoded, dosagesCorrupt);
    _strains = validStrains;
    _dosages = validDosages;
    final settingsJson = generation == null
        ? _prefs.getString(_settingsKey)
        : generation[_settingsKey];
    if (settingsJson != null) {
      try {
        final decoded = jsonDecode(settingsJson);
        if (decoded is Map) {
          _settings = UserSettings.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (error) {
        debugPrint('Could not load settings: $error');
      }
    }
    _userName = generation == null
        ? _prefs.getString(_userNameKey)
        : generation[_userNameKey];
    _invalidateComputedData();
  }


  _DecodedList<T> _decodeList<T>(
    String? encoded,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (encoded == null) return _DecodedList([], false);
    try {
      final raw = jsonDecode(encoded);
      if (raw is! List) return _DecodedList([], true);
      var hadMalformed = false;
      final result = <T>[];
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(
              decode(item.map((key, value) => MapEntry(key.toString(), value))),
            );
          } catch (error) {
            hadMalformed = true;
            debugPrint('Skipped malformed stored record: $error');
          }
        } else {
          hadMalformed = true;
        }
      }
      return _DecodedList(result, hadMalformed);
    } catch (error) {
      debugPrint('Could not load stored list: $error');
      return _DecodedList([], true);
    }
  }

  Future<void> _quarantineCorrupt(
    String key,
    String? encoded,
    bool shouldQuarantine,
  ) async {
    if (!shouldQuarantine || encoded == null) return;
    final quarantineKey = '$_quarantinePrefix$key';
    if (_prefs.getString(quarantineKey) == null) {
      await _prefs.setString(quarantineKey, encoded);
    }
  }

  Future<void> _persistMutation({
    required bool Function() mutate,
  }) {
    return _enqueueWrite(() async {
      final pending = await _resolvePendingTransaction(reload: true);
      final previousStrains = _strains;
      final previousDosages = _dosages;
      final previousSettings = _settings;
      final previousUserName = _userName;
      final previousPersisted = pending ?? _readCanonicalGeneration();

      try {
        if (!mutate()) return;
        await _runTransaction(previousPersisted, _currentGeneration());
      } catch (error, stackTrace) {
        _strains = previousStrains;
        _dosages = previousDosages;
        _settings = previousSettings;
        _userName = previousUserName;
        _invalidateComputedData();
        try {
          await _resolvePendingTransaction(reload: true);
        } catch (_) {
          // The original mutation error is the actionable failure. A pending
          // journal keeps a later load/refresh able to recover the generation.
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      _notifyMutation();
    });
  }

  Map<String, String?> _readCanonicalGeneration() => {
        for (final key in _transactionGenerationKeys)
          key: _prefs.getString(key),
      };

  Map<String, String?> _currentGeneration() => {
        _strainsKey: _encodeStrains(),
        _dosagesKey: _encodeDosages(),
        _settingsKey: jsonEncode(_settings.toJson()),
        _userNameKey: _userName,
      };

  Future<void> _runTransaction(
    Map<String, String?> previous,
    Map<String, String?> target,
  ) async {
    await _writeTransaction(
      _Transaction(
        phase: _TransactionPhase.prepared,
        previous: previous,
        target: target,
      ),
    );
    await _writeGeneration(target);
    await _writeTransaction(
      _Transaction(
        phase: _TransactionPhase.committed,
        previous: previous,
        target: target,
      ),
    );
    try {
      await _requireWriteSucceeded(
        _prefs.remove(_transactionKey),
        _transactionKey,
      );
    } catch (_) {
      // The commit marker is the linearization point. Cleanup is retried by
      // the next load or queued mutation and must not turn success into error.
    }
  }

  Future<Map<String, String?>?> _resolvePendingTransaction({
    bool reload = false,
  }) async {
    if (reload) await _prefs.reload();
    final encoded = _prefs.getString(_transactionKey);
    if (encoded == null) return null;
    final transaction = _Transaction.decode(encoded);
    if (transaction == null) return null;
    final generation = transaction.targetForRecovery;
    var canClearJournal = true;
    if (transaction.phase == _TransactionPhase.prepared) {
      try {
        await _writeGeneration(generation);
      } catch (_) {
        canClearJournal = false;
        // Keep the prepared journal. Its prior generation remains the source
        // of truth until canonical repair can complete.
      }
    }
    if (canClearJournal) {
      try {
        await _requireWriteSucceeded(
          _prefs.remove(_transactionKey),
          _transactionKey,
        );
      } catch (_) {
        // Recovery is safe to retry; never replace the loaded generation with
        // a partially written canonical set.
      }
    }
    return generation;
  }

  Future<void> _writeTransaction(_Transaction transaction) {
    return _requireWriteSucceeded(
      _prefs.setString(_transactionKey, transaction.encode()),
      _transactionKey,
    );
  }

  Future<void> _writeGeneration(Map<String, String?> generation) async {
    for (final key in _transactionGenerationKeys) {
      final value = generation[key];
      if (value == null) {
        await _requireWriteSucceeded(_prefs.remove(key), key);
      } else {
        await _requireWriteSucceeded(_prefs.setString(key, value), key);
      }
    }
  }

  Future<void> _requireWriteSucceeded(Future<bool> result, String key) async {
    if (!await result) {
      throw StateError('Could not persist preference "$key"');
    }
  }

  Future<void> _enqueueWrite(Future<void> Function() action) {
    final operation = _writeChain.then((_) => action());
    _writeChain = operation.catchError((Object _) {});
    return operation;
  }

  String _encodeStrains() =>
      jsonEncode(_strains.map((strain) => strain.toJson()).toList());
  String _encodeDosages() =>
      jsonEncode(_dosages.map((dose) => dose.toJson()).toList());

  void _validateDosage(String strainId, double amount) {
    if (!_strains.any((strain) => strain.id == strainId)) {
      throw ArgumentError.value(strainId, 'strainId', 'unknown strain');
    }
    if (!amount.isFinite || amount <= 0 || amount > 1000) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must be finite, greater than zero, and at most 1000',
      );
    }
  }

  _ImportPlan _prepareImport(BackupPayload p, ImportMode mode) {
    _validatePayload(p);

    // Bare dose lists have no strain collection. Replace cannot reconstruct
    // strains from the file, so keep local strains when they can attach every
    // dose; otherwise reject with the same error preview uses.
    final legacyDoseOnly =
        p.strains.isEmpty && p.orphanedDosages.isEmpty;
    final nextStrains = mode == ImportMode.replace
        ? List<Strain>.of(legacyDoseOnly ? _strains : p.strains)
        : _mergeById(_strains, p.strains, (strain) => strain.id);
    final strainIds = nextStrains.map((strain) => strain.id).toSet();
    final importedDosages = <Dosage>[
      ...p.dosages,
      if (mode == ImportMode.merge)
        ...p.orphanedDosages.where(
          (dose) => strainIds.contains(dose.strainId),
        ),
    ];
    final droppedOrphans = mode == ImportMode.replace
        ? p.orphanedDosages
        : p.orphanedDosages.where(
            (dose) => !strainIds.contains(dose.strainId),
          );
    if (droppedOrphans.isNotEmpty ||
        importedDosages.any((dose) => !strainIds.contains(dose.strainId))) {
      throw ArgumentError('Imported dosage data references an unknown strain');
    }
    _validateImportedDosages(importedDosages);
    return _ImportPlan(
      strains: nextStrains,
      dosages: mode == ImportMode.replace
          ? importedDosages
          : _mergeById(_dosages, importedDosages, (dose) => dose.id),
      settings: mode == ImportMode.merge ? _settings : p.settings ?? _settings,
      userName: mode == ImportMode.merge ? _userName : p.userName ?? _userName,
    );
  }

  void _validatePayload(BackupPayload payload) {
    final strainIds = <String>{};
    for (final strain in payload.strains) {
      if (strain.id.isEmpty || !strainIds.add(strain.id)) {
        throw ArgumentError('Imported strains must have unique, non-empty IDs');
      }
    }
    _validateImportedDosages([
      ...payload.dosages,
      ...payload.orphanedDosages,
    ]);
  }

  void _validateImportedDosages(Iterable<Dosage> doses) {
    final dosageIds = <String>{};
    for (final dose in doses) {
      if (dose.id.isEmpty ||
          !dosageIds.add(dose.id) ||
          !dose.amount.isFinite ||
          dose.amount <= 0 ||
          dose.amount > 1000) {
        throw ArgumentError('Imported dosage data is invalid');
      }
    }
  }

  void _invalidateComputedData() {
    _dailyTotalCache.clear();
    _strainUsageCache = null;
    _strainUsageCacheDay = null;
  }

  void _notifyMutation() {
    _lastMutationStamp++;
    notifyListeners();
  }
}

enum _TransactionPhase { prepared, committed }

class _Transaction {
  final _TransactionPhase phase;
  final Map<String, String?> previous;
  final Map<String, String?> target;

  const _Transaction({
    required this.phase,
    required this.previous,
    required this.target,
  });

  Map<String, String?> get targetForRecovery =>
      phase == _TransactionPhase.prepared ? previous : target;

  String encode() => jsonEncode({
        'version': 1,
        'phase': phase.name,
        'previous': previous,
        'target': target,
      });

  static _Transaction? decode(String encoded) {
    try {
      final raw = jsonDecode(encoded);
      if (raw is! Map || raw['version'] != 1) return null;
      final phaseName = raw['phase'];
      final phase = switch (phaseName) {
        'prepared' => _TransactionPhase.prepared,
        'committed' => _TransactionPhase.committed,
        _ => null,
      };
      final previous = _decodeGeneration(raw['previous']);
      final target = _decodeGeneration(raw['target']);
      if (phase == null || previous == null || target == null) return null;
      return _Transaction(
        phase: phase,
        previous: previous,
        target: target,
      );
    } catch (_) {
      return null;
    }
  }
}

Map<String, String?>? _decodeGeneration(Object? encoded) {
  if (encoded is! Map) return null;
  final generation = <String, String?>{};
  for (final key in _transactionGenerationKeys) {
    if (!encoded.containsKey(key)) return null;
    final value = encoded[key];
    if (value != null && value is! String) return null;
    generation[key] = value as String?;
  }
  return generation;
}

class _DecodedList<T> {
  final List<T> values;
  final bool hadMalformed;

  const _DecodedList(this.values, this.hadMalformed);
}

class _ImportPlan {
  final List<Strain> strains;
  final List<Dosage> dosages;
  final UserSettings settings;
  final String? userName;

  const _ImportPlan({
    required this.strains,
    required this.dosages,
    required this.settings,
    required this.userName,
  });
}

List<T> _mergeById<T>(
  List<T> existing,
  List<T> incoming,
  String Function(T) idOf,
) {
  final existingIds = existing.map(idOf).toSet();
  return [
    ...existing,
    ...incoming.where((item) => existingIds.add(idOf(item))),
  ];
}
