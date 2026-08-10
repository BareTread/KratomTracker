import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/backup_codec.dart';
import '../domain/date_utils.dart';
import '../domain/strain_usage.dart';
import '../models/dosage.dart';
import '../models/effect.dart';
import '../models/settings.dart';
import '../models/strain.dart';

enum ImportMode { replace, merge }

class KratomProvider with ChangeNotifier {
  KratomProvider._(this._prefs);

  static const int currentBackupVersion = 1;
  static const _strainsKey = 'strains';
  static const _dosagesKey = 'dosages';
  static const _effectsKey = 'effects';
  static const _settingsKey = 'settings';
  static const _userNameKey = 'user_name';
  static const _tempPrefix = '_kratom_tracker_tmp_';

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();
  List<Strain> _strains = [];
  List<Dosage> _dosages = [];
  List<Effect> _effects = [];
  UserSettings _settings = const UserSettings(
    enableNotifications: false,
    toleranceBreakInterval: 7,
    trackedEffects: [],
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
  List<Effect> get effects => UnmodifiableListView(_effects);
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

  List<Effect> effectsForDosage(String dosageId) => _effects
      .where((effect) => effect.dosageId == dosageId)
      .toList(growable: false);

  void setSelectedDate(DateTime date) {
    _selectedDate = startOfDay(date);
    _notifyMutation();
  }

  Future<void> addStrain(
    String name,
    String code,
    int color,
    String icon,
  ) async {
    if (name.trim().isEmpty || code.trim().isEmpty || icon.trim().isEmpty) {
      throw ArgumentError('Strain name, code, and icon must not be empty');
    }
    _strains.add(
      Strain(
        id: _uuid.v4(),
        name: name.trim(),
        code: code.trim(),
        color: color,
        icon: icon,
      ),
    );
    _invalidateComputedData();
    await _save({_strainsKey: _encodeStrains()});
    _notifyMutation();
  }

  Future<void> updateStrain(
    String id, {
    String? name,
    String? code,
    int? color,
    String? icon,
  }) async {
    final index = _strains.indexWhere((strain) => strain.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'unknown strain');
    if (name != null && name.trim().isEmpty ||
        code != null && code.trim().isEmpty ||
        icon != null && icon.trim().isEmpty) {
      throw ArgumentError('Strain name, code, and icon must not be empty');
    }
    _strains[index] = _strains[index].copyWith(
      name: name?.trim(),
      code: code?.trim(),
      color: color,
      icon: icon,
    );
    _invalidateComputedData();
    await _save({_strainsKey: _encodeStrains()});
    _notifyMutation();
  }

  Future<void> deleteStrain(String id) async {
    if (!_strains.any((strain) => strain.id == id)) {
      throw ArgumentError.value(id, 'id', 'unknown strain');
    }
    final dosageIds = _dosages
        .where((dose) => dose.strainId == id)
        .map((dose) => dose.id)
        .toSet();
    _strains.removeWhere((strain) => strain.id == id);
    _dosages.removeWhere((dose) => dose.strainId == id);
    _effects.removeWhere((effect) => dosageIds.contains(effect.dosageId));
    _invalidateComputedData();
    await _save({
      _strainsKey: _encodeStrains(),
      _dosagesKey: _encodeDosages(),
      _effectsKey: _encodeEffects(),
    });
    _notifyMutation();
  }

  /// Returns the created dosage so callers can act on it (e.g. offer to log
  /// its effects) without having to diff the list to find the new id.
  Future<Dosage> addDosage(
    String strainId,
    double amount,
    DateTime timestamp, {
    String? notes,
  }) async {
    _validateDosage(strainId, amount);
    final dosage = Dosage(
      id: _uuid.v4(),
      strainId: strainId,
      amount: amount,
      timestamp: timestamp,
      notes: notes,
    );
    _dosages.add(dosage);
    _invalidateComputedData();
    await _save({_dosagesKey: _encodeDosages()});
    _notifyMutation();
    return dosage;
  }

  Future<void> updateDosage({
    required String id,
    required String strainId,
    required double amount,
    required DateTime timestamp,
    String? notes,
  }) async {
    final index = _dosages.indexWhere((dose) => dose.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'unknown dosage');
    _validateDosage(strainId, amount);
    _dosages[index] = Dosage(
      id: id,
      strainId: strainId,
      amount: amount,
      timestamp: timestamp,
      notes: notes,
    );
    _invalidateComputedData();
    await _save({_dosagesKey: _encodeDosages()});
    _notifyMutation();
  }

  Future<void> deleteDosage(String id) async {
    if (!_dosages.any((dose) => dose.id == id)) {
      throw ArgumentError.value(id, 'id', 'unknown dosage');
    }
    _dosages.removeWhere((dose) => dose.id == id);
    _effects.removeWhere((effect) => effect.dosageId == id);
    _invalidateComputedData();
    await _save({
      _dosagesKey: _encodeDosages(),
      _effectsKey: _encodeEffects(),
    });
    _notifyMutation();
  }

  Future<void> addEffect(Effect e) async {
    if (_effects.any((effect) => effect.id == e.id)) {
      throw ArgumentError.value(e.id, 'e.id', 'duplicate effect');
    }
    _validateEffect(e);
    _effects.add(e);
    await _save({_effectsKey: _encodeEffects()});
    _notifyMutation();
  }

  Future<void> updateEffect(Effect e) async {
    final index = _effects.indexWhere((effect) => effect.id == e.id);
    if (index < 0) throw ArgumentError.value(e.id, 'e.id', 'unknown effect');
    _validateEffect(e);
    _effects[index] = e;
    await _save({_effectsKey: _encodeEffects()});
    _notifyMutation();
  }

  Future<void> deleteEffect(String id) async {
    if (!_effects.any((effect) => effect.id == id)) {
      throw ArgumentError.value(id, 'id', 'unknown effect');
    }
    _effects.removeWhere((effect) => effect.id == id);
    await _save({_effectsKey: _encodeEffects()});
    _notifyMutation();
  }

  Future<void> updateSettings(UserSettings settings) async {
    if (!settings.dailyLimit.isFinite || settings.dailyLimit < 0) {
      throw ArgumentError.value(
        settings.dailyLimit,
        'settings.dailyLimit',
        'must be finite and non-negative',
      );
    }
    _settings = settings;
    await _save({_settingsKey: jsonEncode(_settings.toJson())});
    _notifyMutation();
  }

  Future<void> updateUserName(String? name) async {
    final normalized = name?.trim();
    _userName = normalized == null || normalized.isEmpty ? null : normalized;
    await _enqueueWrite(() async {
      if (_userName == null) {
        await _prefs.remove(_userNameKey);
      } else {
        await _prefs.setString(_userNameKey, _userName!);
      }
    });
    _notifyMutation();
  }

  Future<String> exportJson() async {
    return jsonEncode({
      'version': currentBackupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'strains': _strains.map((strain) => strain.toJson()).toList(),
      'dosages': _dosages.map((dose) => dose.toJson()).toList(),
      'effects': _effects.map((effect) => effect.toJson()).toList(),
      'settings': _settings.toJson(),
      if (_userName != null) 'userName': _userName,
    });
  }

  Future<BackupSummary> previewImport(String jsonText) async {
    final result = parseBackup(jsonText);
    return switch (result) {
      BackupOk(:final summary) => summary,
      BackupError(:final message, :final details) =>
        throw FormatException([message, ...details].join('\n')),
    };
  }

  Future<void> commitImport(
    BackupPayload p, {
    required ImportMode mode,
  }) async {
    _validatePayload(p);

    final nextStrains = mode == ImportMode.replace
        ? List<Strain>.of(p.strains)
        : _mergeById(_strains, p.strains, (strain) => strain.id);
    final nextDosages = mode == ImportMode.replace
        ? List<Dosage>.of(p.dosages)
        : _mergeById(_dosages, p.dosages, (dose) => dose.id);
    final nextEffects = mode == ImportMode.replace
        ? List<Effect>.of(p.effects)
        : _mergeById(_effects, p.effects, (effect) => effect.id);
    final nextSettings =
        mode == ImportMode.merge ? _settings : p.settings ?? _settings;
    final nextUserName =
        mode == ImportMode.merge ? _userName : p.userName ?? _userName;

    final previousUserName = _userName;
    _strains = nextStrains;
    _dosages = nextDosages;
    _effects = nextEffects;
    _settings = nextSettings;
    _userName = nextUserName;
    _invalidateComputedData();

    final values = {
      _strainsKey: jsonEncode(nextStrains.map((e) => e.toJson()).toList()),
      _dosagesKey: jsonEncode(nextDosages.map((e) => e.toJson()).toList()),
      _effectsKey: jsonEncode(nextEffects.map((e) => e.toJson()).toList()),
      _settingsKey: jsonEncode(nextSettings.toJson()),
    };
    await _save(values);
    if (nextUserName != previousUserName) {
      await _enqueueWrite(() async {
        if (nextUserName == null) {
          await _prefs.remove(_userNameKey);
        } else {
          await _prefs.setString(_userNameKey, nextUserName);
        }
      });
    }

    _notifyMutation();
  }

  Future<void> clearAllData() async {
    final settings = const UserSettings();
    await _save({
      _strainsKey: '[]',
      _dosagesKey: '[]',
      _effectsKey: '[]',
      _settingsKey: jsonEncode(settings.toJson()),
    });
    _strains = [];
    _dosages = [];
    _effects = [];
    _settings = settings;
    _invalidateComputedData();
    _notifyMutation();
  }

  List<Strain> getRecommendedStrains({
    required Map<String, int> desiredEffects,
    int limit = 3,
  }) {
    if (limit < 0) throw ArgumentError.value(limit, 'limit');
    const weights = {
      EffectMetric.energy: 0.3,
      EffectMetric.mood: 0.3,
      EffectMetric.painRelief: 0.2,
      EffectMetric.focus: 0.2,
      EffectMetric.anxiety: 0.25,
    };
    final dosageById = {for (final dose in _dosages) dose.id: dose};
    final scores = <String, double>{};

    for (final strain in _strains) {
      final strainEffects = _effects.where((effect) {
        final dose = dosageById[effect.dosageId];
        return dose != null && dose.strainId == strain.id;
      }).toList(growable: false);
      if (strainEffects.isEmpty) continue;

      var score = 0.0;
      for (final desired in desiredEffects.entries) {
        final normalizedKey =
            desired.key == 'pain_relief' ? 'painRelief' : desired.key;
        final metric = EffectMetric.values
            .where((candidate) => candidate.key == normalizedKey)
            .firstOrNull;
        if (metric == null) continue;
        final values = strainEffects
            .map(metric.valueOf)
            .whereType<int>()
            .toList(growable: false);
        if (values.isEmpty) continue;
        final average = values.reduce((a, b) => a + b) / values.length;
        score += (5 - (average - desired.value).abs()) * weights[metric]!;
      }
      scores[strain.id] = score;
    }

    final sorted = _strains
        .where((strain) => scores.containsKey(strain.id))
        .toList()
      ..sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
    return sorted.take(limit).toList();
  }

  Future<void> refreshData() async {
    await _writeChain;
    await _loadData();
    _notifyMutation();
  }

  Future<void> _loadData() async {
    _strains = _decodeList(_readStored(_strainsKey), Strain.fromJson);
    _dosages = _decodeList(_readStored(_dosagesKey), Dosage.fromJson);
    _effects = _decodeList(_readStored(_effectsKey), Effect.fromJson);
    final settingsJson = _readStored(_settingsKey);
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
    _userName = _prefs.getString(_userNameKey);
    _invalidateComputedData();
  }

  String? _readStored(String key) =>
      _prefs.getString('$_tempPrefix$key') ?? _prefs.getString(key);

  List<T> _decodeList<T>(
    String? encoded,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (encoded == null) return [];
    try {
      final raw = jsonDecode(encoded);
      if (raw is! List) return [];
      final result = <T>[];
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(
              decode(item.map((key, value) => MapEntry(key.toString(), value))),
            );
          } catch (error) {
            debugPrint('Skipped malformed stored record: $error');
          }
        }
      }
      return result;
    } catch (error) {
      debugPrint('Could not load stored list: $error');
      return [];
    }
  }

  Future<void> _save(Map<String, String> values) {
    final snapshot = Map<String, String>.of(values);
    return _enqueueWrite(() async {
      for (final entry in snapshot.entries) {
        await _prefs.setString('$_tempPrefix${entry.key}', entry.value);
      }
      for (final entry in snapshot.entries) {
        await _prefs.setString(entry.key, entry.value);
      }
      for (final key in snapshot.keys) {
        await _prefs.remove('$_tempPrefix$key');
      }
    });
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
  String _encodeEffects() =>
      jsonEncode(_effects.map((effect) => effect.toJson()).toList());

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

  void _validateEffect(Effect effect) {
    if (!_dosages.any((dose) => dose.id == effect.dosageId)) {
      throw ArgumentError.value(effect.dosageId, 'effect.dosageId');
    }
    final ratings = [
      effect.mood,
      effect.energy,
      effect.painRelief,
      effect.anxiety,
      effect.focus,
    ];
    if (ratings.whereType<int>().any((value) => value < 1 || value > 5)) {
      throw ArgumentError('Effect ratings must be between 1 and 5');
    }
    if (effect.duration != null && effect.duration!.isNegative) {
      throw ArgumentError.value(effect.duration, 'effect.duration');
    }
  }

  void _validatePayload(BackupPayload payload) {
    final strainIds = <String>{};
    for (final strain in payload.strains) {
      if (strain.id.isEmpty || !strainIds.add(strain.id)) {
        throw ArgumentError('Imported strains must have unique, non-empty IDs');
      }
    }
    final dosageIds = <String>{};
    for (final dose in payload.dosages) {
      if (dose.id.isEmpty ||
          !dosageIds.add(dose.id) ||
          !dose.amount.isFinite ||
          dose.amount <= 0 ||
          dose.amount > 1000 ||
          payload.strains.isNotEmpty && !strainIds.contains(dose.strainId)) {
        throw ArgumentError('Imported dosage data is invalid');
      }
    }
    final effectIds = <String>{};
    for (final effect in payload.effects) {
      if (effect.id.isEmpty ||
          !effectIds.add(effect.id) ||
          !dosageIds.contains(effect.dosageId)) {
        throw ArgumentError('Imported effect data is invalid');
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
