import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/strain.dart';
import '../models/dosage.dart';
import '../models/effect.dart';
import '../models/settings.dart';
import '../services/notification_service.dart';

class KratomProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final _uuid = const Uuid();
  late List<Strain> _strains = [];
  late List<Dosage> _dosages = [];
  late List<Effect> _effects = [];
  late UserSettings _settings;
  DateTime _selectedDate = DateTime.now();
  String? _userName;

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

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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
    _userName = _prefs.getString('user_name');
  }

  List<Strain> get strains => _strains;
  List<Dosage> get dosages => _dosages;
  DateTime get selectedDate => _selectedDate;
  String? get userName => _userName;

  List<Dosage> getDosagesForDate(DateTime date) {
    // Clean the input date
    final cleanDate = DateTime(date.year, date.month, date.day);
    
    return _dosages
      .where((dosage) {
        final doseDate = DateTime(
          dosage.timestamp.year,
          dosage.timestamp.month,
          dosage.timestamp.day,
        );
        return doseDate.isAtSameMomentAs(cleanDate);
      })
      .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<Dosage> getDosagesForDateRange(DateTime start, DateTime end) {
    return _dosages.where((dosage) {
      return dosage.timestamp.isAfter(start) && 
             dosage.timestamp.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
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

  Future<void> addDosage(
    String strainId,
    double amount,
    DateTime timestamp, [
    String? notes,
    List<String>? tags,
  ]) async {
    final dosage = Dosage(
      id: _uuid.v4(),
      strainId: strainId,
      amount: amount,
      timestamp: timestamp,
      notes: notes,
      tags: tags ?? [],
    );
    _dosages.add(dosage);
    await _saveDosages();
    notifyListeners();

    // Check for daily limit and notify if needed
    await _checkDailyLimit(timestamp);

    // Check for tolerance tracking
    await _checkToleranceBreak();
  }

  Future<void> _loadData() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final strainData = _prefs.getString('strains');
      final dosageData = _prefs.getString('dosages');
      final effectData = _prefs.getString('effects');
      final settingsData = _prefs.getString('settings');

      if (strainData != null) {
        _strains = (jsonDecode(strainData) as List)
            .map((e) => Strain.fromJson(e))
            .toList();
      }
      if (dosageData != null) {
        _dosages = (jsonDecode(dosageData) as List)
            .map((e) => Dosage.fromJson(e))
            .toList();
      }
      if (effectData != null) {
        _effects = (jsonDecode(effectData) as List)
            .map((e) => Effect.fromJson(e))
            .toList();
      }
      if (settingsData != null) {
        _settings = UserSettings.fromJson(jsonDecode(settingsData));
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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

  Future<void> updateDosage({
    required String id,
    required String strainId,
    required double amount,
    required DateTime timestamp,
    String? notes,
    List<String>? tags,
  }) async {
    final index = _dosages.indexWhere((d) => d.id == id);
    if (index != -1) {
      _dosages[index] = Dosage(
        id: id,
        strainId: strainId,
        amount: amount,
        timestamp: timestamp,
        notes: notes,
        tags: tags ?? _dosages[index].tags,
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

  // Add memory optimization
  static const int _maxCacheSize = 100;
  
  // Implement LRU cache
  final Map<String, MapEntry<DateTime, Strain>> _strainCache = {};
  
  Strain getStrain(String strainId) {
    // Clean old cache entries if needed
    if (_strainCache.length > _maxCacheSize) {
      final sortedEntries = _strainCache.entries.toList()
        ..sort((a, b) => a.value.key.compareTo(b.value.key));
      for (var i = 0; i < _maxCacheSize / 2; i++) {
        _strainCache.remove(sortedEntries[i].key);
      }
    }

    // Update or add cache entry
    if (_strainCache.containsKey(strainId)) {
      final strain = _strainCache[strainId]!.value;
      _strainCache[strainId] = MapEntry(DateTime.now(), strain);
      return strain;
    }

    final strain = _strains.firstWhere(
      (s) => s.id == strainId,
      orElse: () => throw Exception('Strain not found'),
    );
    _strainCache[strainId] = MapEntry(DateTime.now(), strain);
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

  Future<void> updateUserName(String? name) async {
    _userName = name;
    notifyListeners();
    // Save to SharedPreferences
    if (name != null) {
      await _prefs.setString('user_name', name);
    } else {
      await _prefs.remove('user_name');
    }
  }

  Future<void> refreshData() async {
    await _loadData();
  }

  // ==================== NEW FEATURES ====================

  // Duplicate detection
  bool isPotentialDuplicate(String strainId, DateTime timestamp, {int minutesThreshold = 30}) {
    final recentDosages = _dosages.where((d) {
      final timeDiff = timestamp.difference(d.timestamp).inMinutes.abs();
      return d.strainId == strainId && timeDiff <= minutesThreshold;
    });
    return recentDosages.isNotEmpty;
  }

  // Get daily total
  double getDailyTotal(DateTime date) {
    final dosages = getDosagesForDate(date);
    return dosages.fold(0.0, (sum, d) => sum + d.amount);
  }

  // Check daily limit and notify
  Future<void> _checkDailyLimit(DateTime timestamp) async {
    if (_settings.dailyLimit <= 0 || !_settings.enableNotifications) return;

    final dailyTotal = getDailyTotal(timestamp);

    try {
      if (dailyTotal >= _settings.dailyLimit) {
        await NotificationService().showDailyLimitExceeded(
          dailyTotal,
          _settings.dailyLimit,
        );
      } else if (dailyTotal >= _settings.dailyLimit * 0.8) {
        // Warn at 80% of limit
        await NotificationService().showDailyLimitWarning(
          dailyTotal,
          _settings.dailyLimit,
        );
      }
    } catch (e) {
      debugPrint('Error checking daily limit: $e');
    }
  }

  // Check tolerance break
  Future<void> _checkToleranceBreak() async {
    if (!_settings.enableToleranceTracking || !_settings.enableNotifications) return;

    final consecutiveDays = getConsecutiveUsageDays();

    if (consecutiveDays >= _settings.toleranceBreakInterval) {
      try {
        await NotificationService().showToleranceBreakReminder(
          consecutiveDays,
          _settings.toleranceBreakInterval,
        );
      } catch (e) {
        debugPrint('Error checking tolerance break: $e');
      }
    }
  }

  // Get consecutive usage days
  int getConsecutiveUsageDays() {
    if (_dosages.isEmpty) return 0;

    final sortedDosages = List<Dosage>.from(_dosages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final uniqueDays = <String>[];
    for (var dosage in sortedDosages) {
      final dateKey = DateFormat('yyyy-MM-dd').format(dosage.timestamp);
      if (!uniqueDays.contains(dateKey)) {
        uniqueDays.add(dateKey);
      }
    }

    // Count consecutive days from today backwards
    int consecutive = 0;
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(checkDate);

      if (uniqueDays.contains(dateKey)) {
        consecutive++;
      } else if (i > 0) {
        // Break if we find a day with no usage (but not on first day)
        break;
      }
    }

    return consecutive;
  }

  // Search and filter dosages
  List<Dosage> searchDosages({
    String? query,
    String? strainId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) {
    var results = List<Dosage>.from(_dosages);

    // Filter by strain
    if (strainId != null) {
      results = results.where((d) => d.strainId == strainId).toList();
    }

    // Filter by date range
    if (startDate != null) {
      results = results.where((d) => d.timestamp.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      results = results.where((d) => d.timestamp.isBefore(endDate.add(const Duration(days: 1)))).toList();
    }

    // Filter by tags
    if (tags != null && tags.isNotEmpty) {
      results = results.where((d) {
        return tags.any((tag) => d.tags.contains(tag));
      }).toList();
    }

    // Filter by query (notes or strain name)
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      results = results.where((d) {
        final strain = _strains.firstWhere((s) => s.id == d.strainId, orElse: () => throw Exception('Strain not found'));
        final matchesStrain = strain.name.toLowerCase().contains(lowerQuery);
        final matchesNotes = d.notes?.toLowerCase().contains(lowerQuery) ?? false;
        return matchesStrain || matchesNotes;
      }).toList();
    }

    return results..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Advanced analytics - Peak usage times
  Map<String, int> getPeakUsageTimes() {
    final timeSlots = <String, int>{
      'Early Morning (0-6)': 0,
      'Morning (6-9)': 0,
      'Late Morning (9-12)': 0,
      'Afternoon (12-15)': 0,
      'Late Afternoon (15-18)': 0,
      'Evening (18-21)': 0,
      'Night (21-24)': 0,
    };

    for (var dosage in _dosages) {
      final hour = dosage.timestamp.hour;
      if (hour < 6) {
        timeSlots['Early Morning (0-6)'] = timeSlots['Early Morning (0-6)']! + 1;
      } else if (hour < 9) {
        timeSlots['Morning (6-9)'] = timeSlots['Morning (6-9)']! + 1;
      } else if (hour < 12) {
        timeSlots['Late Morning (9-12)'] = timeSlots['Late Morning (9-12)']! + 1;
      } else if (hour < 15) {
        timeSlots['Afternoon (12-15)'] = timeSlots['Afternoon (12-15)']! + 1;
      } else if (hour < 18) {
        timeSlots['Late Afternoon (15-18)'] = timeSlots['Late Afternoon (15-18)']! + 1;
      } else if (hour < 21) {
        timeSlots['Evening (18-21)'] = timeSlots['Evening (18-21)']! + 1;
      } else {
        timeSlots['Night (21-24)'] = timeSlots['Night (21-24)']! + 1;
      }
    }

    return timeSlots;
  }

  // Weekly summary
  Map<String, dynamic> getWeeklySummary() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final weekDosages = getDosagesForDateRange(weekStart, weekEnd);
    final totalAmount = weekDosages.fold(0.0, (sum, d) => sum + d.amount);

    final dailyAmounts = <String, double>{};
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayKey = DateFormat('EEEE').format(day);
      final dayDosages = getDosagesForDate(day);
      dailyAmounts[dayKey] = dayDosages.fold(0.0, (sum, d) => sum + d.amount);
    }

    return {
      'totalDosages': weekDosages.length,
      'totalAmount': totalAmount,
      'avgPerDay': totalAmount / 7,
      'dailyBreakdown': dailyAmounts,
      'daysActive': dailyAmounts.values.where((v) => v > 0).length,
    };
  }

  // Monthly summary
  Map<String, dynamic> getMonthlySummary() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final monthDosages = getDosagesForDateRange(monthStart, monthEnd);
    final totalAmount = monthDosages.fold(0.0, (sum, d) => sum + d.amount);

    final uniqueDays = <String>{};
    for (var dosage in monthDosages) {
      uniqueDays.add(DateFormat('yyyy-MM-dd').format(dosage.timestamp));
    }

    return {
      'totalDosages': monthDosages.length,
      'totalAmount': totalAmount,
      'avgPerDay': totalAmount / uniqueDays.length,
      'daysActive': uniqueDays.length,
      'daysInMonth': monthEnd.day,
    };
  }

  // Strain comparison
  Map<String, dynamic> compareStrains(List<String> strainIds) {
    final comparison = <String, Map<String, dynamic>>{};

    for (var strainId in strainIds) {
      final strainDosages = _dosages.where((d) => d.strainId == strainId).toList();
      final strainEffects = _effects
          .where((e) => strainDosages.any((d) => d.id == e.dosageId))
          .toList();

      final totalAmount = strainDosages.fold(0.0, (sum, d) => sum + d.amount);
      final avgAmount = strainDosages.isEmpty ? 0.0 : totalAmount / strainDosages.length;

      // Calculate average effects
      final avgMood = strainEffects.isEmpty ? 0.0 :
          strainEffects.fold(0, (sum, e) => sum + e.mood) / strainEffects.length;
      final avgEnergy = strainEffects.isEmpty ? 0.0 :
          strainEffects.fold(0, (sum, e) => sum + e.energy) / strainEffects.length;
      final avgPain = strainEffects.isEmpty ? 0.0 :
          strainEffects.fold(0, (sum, e) => sum + e.painRelief) / strainEffects.length;

      comparison[strainId] = {
        'totalUses': strainDosages.length,
        'totalAmount': totalAmount,
        'avgAmount': avgAmount,
        'avgMood': avgMood,
        'avgEnergy': avgEnergy,
        'avgPainRelief': avgPain,
      };
    }

    return comparison;
  }

  // Effectiveness trends over time
  Map<String, dynamic> getEffectivenessTrends(String strainId, {int days = 30}) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    final recentDosages = _dosages.where((d) {
      return d.strainId == strainId && d.timestamp.isAfter(startDate);
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final trends = <String, List<double>>{
      'mood': [],
      'energy': [],
      'painRelief': [],
    };

    for (var dosage in recentDosages) {
      final effect = _effects.firstWhere(
        (e) => e.dosageId == dosage.id,
        orElse: () => throw Exception('Effect not found'),
      );

      trends['mood']!.add(effect.mood.toDouble());
      trends['energy']!.add(effect.energy.toDouble());
      trends['painRelief']!.add(effect.painRelief.toDouble());
    }

    return {
      'trends': trends,
      'sampleSize': recentDosages.length,
      'dateRange': days,
    };
  }

  // Get all unique tags
  List<String> getAllTags() {
    final tags = <String>{};
    for (var dosage in _dosages) {
      tags.addAll(dosage.tags);
    }
    return tags.toList()..sort();
  }

  // Tag analytics
  Map<String, int> getTagUsageCount() {
    final tagCounts = <String, int>{};
    for (var dosage in _dosages) {
      for (var tag in dosage.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    return tagCounts;
  }

} 