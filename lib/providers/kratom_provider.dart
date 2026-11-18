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
import '../widgets/strain_mark.dart';

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
  UserSettings _settings = const UserSettings();
  DateTime _selectedDate = DateTime.now();
  String? _userName;
  bool _isReady = false;
  int _lastMutationStamp = 0;
  Future<void> _writeChain = Future<void>.value();
  List<String> _loadWarnings = const [];

  /// Damaged raw values found at load whose canonical key a later save
  /// would rewrite (key -> raw bytes). The next write must quarantine each
  /// value first or fail, so a save can never silently drop damaged data.
  final Map<String, String> _pendingQuarantine = {};
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

  /// Problems found while loading persisted state — corrupt records,
  /// quarantined data, or damage an interrupted save's recovery had to
  /// preserve before overwriting it. Every entry describes real evidence
  /// left on disk; nothing is rewritten silently.
  List<String> get loadWarnings => _loadWarnings;

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
            // Store the canonical LeafShape name — the same value
            // Strain.fromJson produces on read — so an export reproduces
            // stored data verbatim instead of a legacy alias.
            icon: resolveLeafShape(icon, code.trim()).name,
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
        final nextCode = code?.trim() ?? _strains[index].code;
        final updated = _strains[index].copyWith(
          name: name?.trim(),
          code: code?.trim(),
          color: color,
          icon: icon == null ? null : resolveLeafShape(icon, nextCode).name,
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
        final plan = _prepareImport(payload, mode);
        return plan.previewWarnings.isEmpty
            ? summary
            : BackupSummary(
                strainCount: summary.strainCount,
                dosageCount: summary.dosageCount,
                earliestDose: summary.earliestDose,
                latestDose: summary.latestDose,
                totalGrams: summary.totalGrams,
                warnings: List.unmodifiable([
                  ...summary.warnings,
                  ...plan.previewWarnings,
                ]),
              );
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
    const settings = UserSettings();
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

  Future<void> refreshData() {
    // Serialized on the same chain as writes: a reload must never overlap a
    // queued mutation, or it could read pre-mutation storage and assign the
    // stale generation over freshly mutated memory.
    return _enqueueWrite(() async {
      await _loadData();
      _notifyMutation();
    });
  }

  Future<void> _loadData() async {
    final warnings = <String>[];
    _pendingQuarantine.clear();
    final recovery = await _resolvePendingTransaction(reload: true);
    final generation = recovery.generation;
    final generationOrPrefs = generation ??
        {
          for (final key in _transactionGenerationKeys)
            key: _prefs.getString(key),
        };
    final strainsEncoded = generationOrPrefs[_strainsKey];
    final dosagesEncoded = generationOrPrefs[_dosagesKey];
    final strains = _decodeList(strainsEncoded, Strain.fromJson);
    final dosages = _decodeList(dosagesEncoded, Dosage.fromJson);
    final seenStrainIds = <String>{};
    final validStrains = <Strain>[];
    var strainsCorrupt = strains.hadMalformed;
    for (final strain in strains.values) {
      if (!_isReadableStrainRow(strain, seenStrainIds)) {
        strainsCorrupt = true;
        continue;
      }
      validStrains.add(strain);
    }
    final strainIds = seenStrainIds;
    final seenDoseIds = <String>{};
    final validDosages = <Dosage>[];
    final missingStrainIds = <String>{};
    var dosagesCorrupt = dosages.hadMalformed;
    for (final dose in dosages.values) {
      if (!_isReadableDosageRow(dose, seenDoseIds)) {
        dosagesCorrupt = true;
        continue;
      }
      if (!strainIds.contains(dose.strainId)) {
        // The strain row is missing or unreadable. Keep the dose under a
        // placeholder carrying the original strain ID rather than dropping
        // real history.
        missingStrainIds.add(dose.strainId);
      }
      validDosages.add(dose);
    }
    for (final id in missingStrainIds) {
      validStrains.add(_placeholderStrain(id));
    }
    if (strainsCorrupt && strainsEncoded != null) {
      _pendingQuarantine[_strainsKey] = strainsEncoded;
    }
    if (dosagesCorrupt && dosagesEncoded != null) {
      _pendingQuarantine[_dosagesKey] = dosagesEncoded;
    }
    if (strainsCorrupt || dosagesCorrupt) {
      warnings.add(
        'Some saved records were damaged and were preserved in place; '
        'unaffected data was loaded normally.',
      );
    }
    if (missingStrainIds.isNotEmpty) {
      warnings.add(
        'Some doses referenced a strain that could not be loaded and were '
        'kept under a placeholder.',
      );
    }
    _strains = validStrains;
    _dosages = validDosages;
    final settingsJson = generationOrPrefs[_settingsKey];
    if (settingsJson != null) {
      var settingsLoaded = false;
      try {
        final decoded = jsonDecode(settingsJson);
        if (decoded is Map) {
          _settings = UserSettings.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
          settingsLoaded = true;
        }
      } catch (error) {
        debugPrint('Could not load settings: $error');
      }
      if (!settingsLoaded) {
        _pendingQuarantine[_settingsKey] = settingsJson;
        warnings.add(
          'Saved settings were damaged and defaults are in use; the damaged '
          'copy was preserved.',
        );
      }
    }
    if (recovery.encounteredDamaged) {
      warnings.add(
        'An interrupted save was rolled back; damaged data found '
        'underneath was preserved.',
      );
    }
    _userName = generationOrPrefs[_userNameKey];
    // Best effort at load: a failure here keeps the entry pending, and the
    // next save refuses to overwrite the damaged raw until it succeeds.
    try {
      await _flushQuarantine();
    } catch (error) {
      debugPrint('Could not quarantine damaged data yet: $error');
    }
    _loadWarnings = List.unmodifiable(warnings);
    _invalidateComputedData();
  }

  /// Copies every pending damaged value to quarantine with checked writes.
  /// Throws while any copy is not durably stored.
  Future<void> _flushQuarantine() async {
    for (final key in _pendingQuarantine.keys.toList()) {
      await _quarantineCorrupt(key, _pendingQuarantine[key], true);
      _pendingQuarantine.remove(key);
    }
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

  /// Preserves a corrupt raw value under a quarantine key. The base key is
  /// used first; when it already holds DIFFERENT damage, the new value goes
  /// to the next free numbered slot — first-wins must never silently lose a
  /// later corrupt source that a routine save would otherwise overwrite.
  Future<void> _quarantineCorrupt(
    String key,
    String? encoded,
    bool shouldQuarantine,
  ) async {
    if (!shouldQuarantine || encoded == null) return;
    final base = '$_quarantinePrefix$key';
    var candidate = base;
    for (var slot = 2; ; slot++) {
      final held = _prefs.getString(candidate);
      if (held == null) {
        try {
          await _requireWriteSucceeded(
            _prefs.setString(candidate, encoded),
            candidate,
          );
        } catch (_) {
          // The preferences cache already holds the value even though the
          // platform write failed; resync so a retry is not skipped as done.
          await _prefs.reload();
          rethrow;
        }
        return;
      }
      if (held == encoded) return;
      candidate = '$base.$slot';
    }
  }

  Future<void> _persistMutation({
    required bool Function() mutate,
  }) {
    return _enqueueWrite(() async {
      final recovery = await _resolvePendingTransaction(reload: true);
      final previousStrains = _strains;
      final previousDosages = _dosages;
      final previousSettings = _settings;
      final previousUserName = _userName;
      final previousPersisted =
          recovery.generation ?? _readCanonicalGeneration();

      try {
        if (!mutate()) return;
        // The canonical values get rewritten below: every damaged raw whose
        // only copy sits in one of those keys must be durably quarantined
        // first, or this save fails and rolls back.
        await _quarantineUnreadableCanonical();
        await _flushQuarantine();
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

  /// Stages any unreadable canonical value for quarantine. Called before a
  /// generation write overwrites the canonical keys, so damage that appeared
  /// since the last load is preserved exactly once instead of erased.
  Future<void> _quarantineUnreadableCanonical() async {
    for (final key in _transactionGenerationKeys) {
      final stored = _prefs.getString(key);
      if (stored != null &&
          stored != _pendingQuarantine[key] &&
          _isUnreadableStoredValue(key, stored)) {
        _pendingQuarantine[key] = stored;
      }
    }
  }

  /// The row checks [_loadData] applies, kept as shared predicates so an
  /// "unreadable" stored value means exactly what load would flag damaged.
  static bool _isReadableStrainRow(Strain strain, Set<String> seenIds) =>
      strain.id.isNotEmpty &&
      strain.name.isNotEmpty &&
      strain.code.isNotEmpty &&
      seenIds.add(strain.id);

  static bool _isReadableDosageRow(Dosage dose, Set<String> seenIds) =>
      dose.id.isNotEmpty &&
      dose.strainId.isNotEmpty &&
      dose.amount.isFinite &&
      dose.amount > 0 &&
      dose.amount <= 1000 &&
      seenIds.add(dose.id);

  /// Row-level unreadability: the collection parses, every row decodes, and
  /// each row passes the validity checks load applies — including unique,
  /// non-empty IDs. A dose whose strain is missing is still readable; load
  /// keeps it under a placeholder.
  static bool _decodedRowsUnreadable<T>(
    Object? decoded,
    T Function(Map<String, dynamic>) decode,
    bool Function(T, Set<String>) isReadableRow,
  ) {
    if (decoded is! List) return true;
    final seenIds = <String>{};
    for (final item in decoded) {
      if (item is! Map) return true;
      try {
        final row = decode(item.map((k, v) => MapEntry(k.toString(), v)));
        if (!isReadableRow(row, seenIds)) return true;
      } catch (_) {
        return true;
      }
    }
    return false;
  }

  bool _isUnreadableStoredValue(String key, String value) {
    // user_name is stored raw — every string is a valid value.
    if (key != _strainsKey && key != _dosagesKey && key != _settingsKey) {
      return false;
    }
    try {
      final decoded = jsonDecode(value);
      switch (key) {
        case _strainsKey:
          return _decodedRowsUnreadable<Strain>(
            decoded,
            Strain.fromJson,
            _isReadableStrainRow,
          );
        case _dosagesKey:
          return _decodedRowsUnreadable<Dosage>(
            decoded,
            Dosage.fromJson,
            _isReadableDosageRow,
          );
        default:
          if (decoded is! Map) return true;
          try {
            UserSettings.fromJson(
              decoded.map((k, v) => MapEntry(k.toString(), v)),
            );
            return false;
          } catch (_) {
            return true;
          }
      }
    } catch (_) {
      return true;
    }
  }

  /// A journal recovery that overwrites a canonical key carrying unreadable
  /// raw data must first stage that raw for quarantine — recovery otherwise
  /// erases the only copy of damaged bytes it never parses.
  void _preserveDamagedBeforeOverwrite(Map<String, String?> incoming) {
    for (final key in _transactionGenerationKeys) {
      final stored = _prefs.getString(key);
      if (stored != null &&
          stored != incoming[key] &&
          _isUnreadableStoredValue(key, stored)) {
        _pendingQuarantine[key] = stored;
      }
    }
  }

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

  /// `encounteredDamaged` is true when a prepared-journal recovery found
  /// damaged canonical bytes it must preserve before restoring the recorded
  /// generation — evidence produced by THIS recovery, so the load that ran
  /// it warns even though the recovered rows themselves decode fine. It is
  /// set when the damage is discovered, before the quarantine copy runs:
  /// whether or not that copy lands, the damaged raw is preserved (copied
  /// before repair, or left in place while the journal still waits).
  Future<({Map<String, String?>? generation, bool encounteredDamaged})>
      _resolvePendingTransaction({
    bool reload = false,
  }) async {
    var encounteredDamaged = false;
    if (reload) await _prefs.reload();
    final encoded = _prefs.getString(_transactionKey);
    if (encoded == null) {
      return (generation: null, encounteredDamaged: false);
    }
    final transaction = _Transaction.decode(encoded);
    if (transaction == null) {
      return (generation: null, encounteredDamaged: false);
    }
    final generation = transaction.targetForRecovery;
    var canClearJournal = true;
    if (transaction.phase == _TransactionPhase.prepared) {
      try {
        _preserveDamagedBeforeOverwrite(generation);
        // Damage discovered by this recovery is evidence now — even if the
        // quarantine copy fails and the raw survives only in place, this
        // load must not report a clean state.
        encounteredDamaged = _pendingQuarantine.isNotEmpty;
        await _flushQuarantine();
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
    return (generation: generation, encounteredDamaged: encounteredDamaged);
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

    // Replace must never guess: a backup missing explicit `strains` or
    // `dosages` collections (absent, null, or not a list) cannot express
    // "replace everything" and is rejected outright. Explicit lists —
    // including empty ones — are honoured. Merge is additive, so a bare
    // legacy dose list is still allowed to attach to local strains.
    if (mode == ImportMode.replace &&
        !(p.hasStrainCollection && p.hasDosageCollection)) {
      throw ArgumentError(
        'Replace requires a backup with explicit strains and dosages lists',
      );
    }
    final importedDosages = <Dosage>[
      ...p.dosages,
      ...p.orphanedDosages,
    ];
    // Merge fills gaps only: existing strain IDs win — except a local
    // placeholder, which an incoming real strain with the same ID
    // legitimately repairs.
    final nextStrains = mode == ImportMode.replace
        ? List<Strain>.of(p.strains)
        : _mergeStrains(_strains, p.strains);
    final strainIds = nextStrains.map((strain) => strain.id).toSet();
    final missingStrainIds = <String>{};
    for (final dose in importedDosages) {
      if (!strainIds.contains(dose.strainId)) {
        missingStrainIds.add(dose.strainId);
      }
    }
    for (final id in missingStrainIds) {
      nextStrains.add(_placeholderStrain(id));
    }
    // Preview boundary: parseBackup cannot see local strain IDs, so warn
    // here for doses that will restore under a placeholder WITHOUT already
    // being reported as orphaned against the backup's own strain list.
    final orphanStrainIds =
        p.orphanedDosages.map((dose) => dose.strainId).toSet();
    final unreported = missingStrainIds.difference(orphanStrainIds);
    final unreportedDoseCount = importedDosages
        .where((dose) => unreported.contains(dose.strainId))
        .length;
    final previewWarnings = <String>[
      if (unreportedDoseCount > 0)
        '$unreportedDoseCount '
        '${unreportedDoseCount == 1 ? 'dose' : 'doses'} will restore under '
        'a placeholder because the strain is missing from the backup',
    ];
    _validateImportedDosages(importedDosages);
    return _ImportPlan(
      strains: nextStrains,
      dosages: mode == ImportMode.replace
          ? importedDosages
          : _mergeById(_dosages, importedDosages, (dose) => dose.id),
      settings: mode == ImportMode.merge ? _settings : p.settings ?? _settings,
      userName: mode == ImportMode.merge ? _userName : p.userName ?? _userName,
      previewWarnings: previewWarnings,
    );
  }

  /// A neutral, deterministic stand-in for a strain the data references but
  /// no longer describes. The original strain ID is kept so records stay
  /// linked; `inStock` is false so the placeholder reads as history, not an
  /// available strain. Merge compares against this exact shape to detect
  /// placeholders, so keep it stable.
  Strain _placeholderStrain(String missingId) => Strain(
        id: missingId,
        name: 'Missing strain',
        code: 'LOST',
        color: 0xFF9E9E9E,
        icon: 'oval',
        inStock: false,
      );

  /// Union by ID where the local row wins — unless the local row is exactly
  /// the placeholder a damaged load or earlier import created for that ID,
  /// in which case the incoming real strain replaces it.
  List<Strain> _mergeStrains(List<Strain> existing, List<Strain> incoming) {
    final merged = List<Strain>.of(existing);
    for (final strain in incoming) {
      final index = merged.indexWhere((local) => local.id == strain.id);
      if (index < 0) {
        merged.add(strain);
      } else if (merged[index] == _placeholderStrain(strain.id)) {
        merged[index] = strain;
      }
    }
    return merged;
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

  /// Warnings the parser could not know about because they depend on local
  /// strain IDs — surfaced by [previewImport] only; commit ignores them.
  final List<String> previewWarnings;

  const _ImportPlan({
    required this.strains,
    required this.dosages,
    required this.settings,
    required this.userName,
    this.previewWarnings = const [],
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
