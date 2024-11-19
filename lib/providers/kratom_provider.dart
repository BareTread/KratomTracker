import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/strain.dart';
import '../models/dosage.dart';
import '../models/effect.dart';
import '../models/settings.dart';

class KratomProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final _uuid = const Uuid();
  late List<Strain> _strains = [];
  late List<Dosage> _dosages = [];
  late List<Effect> _effects = [];
  late UserSettings _settings;
  DateTime _selectedDate = DateTime.now();

  static const int currentBackupVersion = 1;

  // Add effect categories
  static const Map<String, List<String>> effectCategories = {
    'energy': ['Low', 'Moderate', 'High'],
    'mood': ['Relaxed', 'Balanced', 'Euphoric'],
    'pain_relief': ['Mild', 'Moderate', 'Strong'],
    'focus': ['Scattered', 'Clear', 'Sharp'],
    'duration': ['2-3 hours', '3-4 hours', '4+ hours'],
  };

  // Add recommendation weights
  final Map<String, double> _recommendationWeights = {
    'energy': 0.3,
    'mood': 0.3,
    'pain_relief': 0.2,
    'focus': 0.2,
  };

  KratomProvider(this._prefs) {
    // Initialize settings with defaults
    _settings = UserSettings(
      enableNotifications: false,
      morningReminder: null,
      eveningReminder: null,
      dailyLimit: 0.0,
      enableToleranceTracking: false,
      toleranceBreakInterval: 7,
      trackedEffects: const [],
      darkMode: true,
      measurementUnit: 'g',
    );
    _loadData();
  }

  List<Strain> get strains => _strains;
  List<Dosage> get dosages => _dosages;
  DateTime get selectedDate => _selectedDate;

  List<Dosage> getDosagesForDate(DateTime date) {
    return _dosages
      .where((dosage) =>
        dosage.timestamp.year == date.year &&
        dosage.timestamp.month == date.month &&
        dosage.timestamp.day == date.day
      )
      .toList()
      // Sort by timestamp
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<Dosage> getDosagesForDateRange(DateTime start, DateTime end) {
    return _dosages.where((dosage) {
      return dosage.timestamp.isAfter(start) && 
             dosage.timestamp.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> addStrain(String name, String code, int color, String icon) async {
    final strain = Strain(
      id: _uuid.v4(),
      name: name,
      code: code,
      color: color,
      icon: icon,
    );
    _strains.add(strain);
    await _saveStrains();
    notifyListeners();
  }

  Future<void> addDosage(String strainId, double amount, DateTime timestamp, [String? notes]) async {
    final dosage = Dosage(
      id: _uuid.v4(),
      strainId: strainId,
      amount: amount,
      timestamp: timestamp,
      notes: notes,
    );
    _dosages.add(dosage);
    await _saveDosages();
    notifyListeners();
  }

  Future<void> _loadData() async {
    // Batch load data
    try {
      final strainData = _prefs.getString('strains');
      final dosageData = _prefs.getString('dosages');
      final effectData = _prefs.getString('effects');
      final settingsData = _prefs.getString('settings');

      if (strainData != null) _strains = (jsonDecode(strainData) as List).map((e) => Strain.fromJson(e)).toList();
      if (dosageData != null) _dosages = (jsonDecode(dosageData) as List).map((e) => Dosage.fromJson(e)).toList();
      if (effectData != null) _effects = (jsonDecode(effectData) as List).map((e) => Effect.fromJson(e)).toList();
      if (settingsData != null) _settings = UserSettings.fromJson(jsonDecode(settingsData));
      
      // Single notification for all updates
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _saveStrains() async {
    final strainsJson = json.encode(_strains.map((s) => s.toJson()).toList());
    await _prefs.setString('strains', strainsJson);
  }

  Future<void> _saveDosages() async {
    final dosagesJson = json.encode(_dosages.map((d) => d.toJson()).toList());
    await _prefs.setString('dosages', dosagesJson);
  }

  Future<void> _saveEffects() async {
    final effectsJson = json.encode(_effects.map((e) => e.toJson()).toList());
    await _prefs.setString('effects', effectsJson);
  }

  Future<void> _saveSettings() async {
    final settingsJson = jsonEncode(_settings.toJson());
    await _prefs.setString('settings', settingsJson);
  }

  Future<void> clearAllData() async {
    _strains.clear();
    _dosages.clear();
    _effects.clear();
    _settings = UserSettings(); // Reset to defaults

    await Future.wait([
      _saveStrains(),
      _saveDosages(),
      _saveEffects(),
      _saveSettings(),
    ]);

    notifyListeners();
  }

  Future<void> deleteStrain(String strainId) async {
    _strains.removeWhere((s) => s.id == strainId);
    // Remove all dosages associated with this strain
    _dosages.removeWhere((d) => d.strainId == strainId);
    await _saveStrains();
    await _saveDosages();
    notifyListeners();
  }

  Future<void> updateStrain(String id, {
    String? name,
    String? code,
    int? color,
    String? icon,
  }) async {
    final index = _strains.indexWhere((s) => s.id == id);
    if (index != -1) {
      final strain = _strains[index];
      _strains[index] = Strain(
        id: strain.id,
        name: name ?? strain.name,
        code: code ?? strain.code,
        color: color ?? strain.color,
        icon: icon ?? strain.icon,
      );
      await _saveStrains();
      notifyListeners();
    }
  }

  // Export data as JSON string
  Future<String> exportData() async {
    try {
      final data = {
        'version': currentBackupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'strains': _strains.map((s) => s.toJson()).toList(),
        'dosages': _dosages.map((d) => d.toJson()).toList(),
        'effects': _effects.map((e) => e.toJson()).toList(),
        'settings': _settings.toJson(),
      };
      
      return jsonEncode(data);
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }

  // Import data from JSON string
  Future<void> importData(String jsonData) async {
    try {
      final data = jsonDecode(jsonData);
      
      // Version check
      final version = data['version'] ?? 1;
      if (version > currentBackupVersion) {
        throw Exception('Unsupported backup version');
      }

      // Clear existing data
      _strains.clear();
      _dosages.clear();
      _effects.clear();

      // Import data
      if (data['strains'] != null) {
        _strains = (data['strains'] as List)
            .map((s) => Strain.fromJson(s))
            .toList();
      }
      
      if (data['dosages'] != null) {
        _dosages = (data['dosages'] as List)
            .map((d) => Dosage.fromJson(d))
            .toList();
      }
      
      if (data['effects'] != null) {
        _effects = (data['effects'] as List)
            .map((e) => Effect.fromJson(e))
            .toList();
      }

      if (data['settings'] != null) {
        _settings = UserSettings.fromJson(data['settings']);
      }

      // Save all imported data
      await Future.wait([
        _saveStrains(),
        _saveDosages(),
        _saveEffects(),
        _saveSettings(),
      ]);

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  Future<void> updateDosage(String id, String strainId, double amount, DateTime timestamp, String? notes) async {
    final index = _dosages.indexWhere((d) => d.id == id);
    if (index != -1) {
      _dosages[index] = Dosage(
        id: id,
        strainId: strainId,
        amount: amount,
        timestamp: timestamp,
        notes: notes,
      );
      await _saveDosages();
      notifyListeners();
    }
  }

  Future<void> deleteDosage(String id) async {
    _dosages.removeWhere((d) => d.id == id);
    await _saveDosages();
    notifyListeners();
  }

  Future<void> addEffect(Effect effect) async {
    _effects.add(effect);
    await _saveEffects();
    notifyListeners();
  }

  List<Strain> getRecommendedStrains({
    required Map<String, int> desiredEffects,
    int limit = 3,
  }) {
    // Calculate strain scores based on past effects
    Map<String, double> strainScores = {};
    
    for (var strain in _strains) {
      double score = 0;
      var strainEffects = _effects
          .where((e) => 
              _dosages.firstWhere((d) => d.id == e.dosageId).strainId == strain.id)
          .toList();

      if (strainEffects.isEmpty) continue;

      // Calculate average effect scores for this strain
      Map<String, double> avgEffects = {};
      for (var category in effectCategories.keys) {
        var categoryEffects = strainEffects
            .map((e) => e.toJson()[category])
            .whereType<int>()
            .toList();
        if (categoryEffects.isNotEmpty) {
          avgEffects[category] = categoryEffects.reduce((a, b) => a + b) / 
              categoryEffects.length;
        }
      }

      // Compare with desired effects
      for (var entry in desiredEffects.entries) {
        if (avgEffects.containsKey(entry.key)) {
          double difference = (avgEffects[entry.key]! - entry.value).abs();
          score += (5 - difference) * (_recommendationWeights[entry.key] ?? 0.25);
        }
      }

      strainScores[strain.id] = score;
    }

    // Sort strains by score and return top recommendations
    return _strains
        .where((s) => strainScores.containsKey(s.id))
        .toList()
        ..sort((a, b) => strainScores[b.id]!.compareTo(strainScores[a.id]!))
        ..take(limit);
  }

  Map<String, dynamic> getStrainAnalytics(String strainId) {
    var strainDosages = _dosages.where((d) => d.strainId == strainId).toList();
    var strainEffects = _effects
        .where((e) => strainDosages.any((d) => d.id == e.dosageId))
        .toList();

    // Calculate average effects
    Map<String, double> avgEffects = {};
    for (var category in effectCategories.keys) {
      var categoryEffects = strainEffects
          .map((e) => e.toJson()[category])
          .whereType<int>()
          .toList();
      if (categoryEffects.isNotEmpty) {
        avgEffects[category] = categoryEffects.reduce((a, b) => a + b) / 
            categoryEffects.length;
      }
    }

    // Calculate optimal dosage range
    var amounts = strainDosages.map((d) => d.amount).toList();
    var optimalRange = amounts.isEmpty ? null : {
      'min': amounts.reduce((a, b) => a < b ? a : b),
      'max': amounts.reduce((a, b) => a > b ? a : b),
      'avg': amounts.reduce((a, b) => a + b) / amounts.length,
    };

    return {
      'averageEffects': avgEffects,
      'optimalDosage': optimalRange,
      'totalUses': strainDosages.length,
      'effectivenessScore': avgEffects.isEmpty ? 0 : 
          avgEffects.values.reduce((a, b) => a + b) / avgEffects.length,
    };
  }

  // Add validation method
  bool validateBackup(String jsonData) {
    try {
      final data = jsonDecode(jsonData);
      return data['version'] != null &&
             data['timestamp'] != null &&
             data['strains'] != null &&
             data['dosages'] != null &&
             data['effects'] != null &&
             data['settings'] != null;
    } catch (e) {
      return false;
    }
  }

  // Add method to get backup info
  Map<String, dynamic> getBackupInfo(String jsonData) {
    final data = jsonDecode(jsonData);
    return {
      'timestamp': DateTime.parse(data['timestamp']),
      'strainCount': (data['strains'] as List).length,
      'dosageCount': (data['dosages'] as List).length,
      'effectCount': (data['effects'] as List).length,
    };
  }

  // Cache frequently accessed data
  late final Map<String, Strain> _strainCache = {};

  Strain getStrain(String strainId) {
    if (_strainCache.containsKey(strainId)) {
      return _strainCache[strainId]!;
    }
    final strain = _strains.firstWhere(
      (s) => s.id == strainId,
      orElse: () => throw Exception('Strain not found'),
    );
    _strainCache[strainId] = strain;
    return strain;
  }

  // Add settings getter and update method
  UserSettings get settings => _settings;

  Future<void> updateSettings({
    bool? darkMode,
    bool? enableNotifications,
    TimeOfDay? morningReminder,
    TimeOfDay? eveningReminder,
    double? dailyLimit,
    bool? enableToleranceTracking,
    int? toleranceBreakInterval,
    List<String>? trackedEffects,
    String? measurementUnit,
  }) async {
    _settings = UserSettings(
      darkMode: darkMode ?? _settings.darkMode,
      enableNotifications: enableNotifications ?? _settings.enableNotifications,
      morningReminder: morningReminder ?? _settings.morningReminder,
      eveningReminder: eveningReminder ?? _settings.eveningReminder,
      dailyLimit: dailyLimit ?? _settings.dailyLimit,
      enableToleranceTracking: enableToleranceTracking ?? _settings.enableToleranceTracking,
      toleranceBreakInterval: toleranceBreakInterval ?? _settings.toleranceBreakInterval,
      trackedEffects: trackedEffects ?? _settings.trackedEffects,
      measurementUnit: measurementUnit ?? _settings.measurementUnit,
    );
    await _saveSettings();
    notifyListeners();
  }

  // Add backup methods
  Future<Map<String, dynamic>> createBackup() async {
    return {
      'version': currentBackupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'strains': _strains.map((s) => s.toJson()).toList(),
      'dosages': _dosages.map((d) => d.toJson()).toList(),
      'effects': _effects.map((e) => e.toJson()).toList(),
      'settings': _settings.toJson(),
    };
  }

  Future<void> restoreBackup(String jsonData) async {
    final data = jsonDecode(jsonData);
    _strains = (data['strains'] as List).map((e) => Strain.fromJson(e)).toList();
    _dosages = (data['dosages'] as List).map((e) => Dosage.fromJson(e)).toList();
    _effects = (data['effects'] as List).map((e) => Effect.fromJson(e)).toList();
    _settings = UserSettings.fromJson(data['settings']);
    
    await Future.wait([
      _saveStrains(),
      _saveDosages(),
      _saveEffects(),
      _saveSettings(),
    ]);
    
    notifyListeners();
  }
} 