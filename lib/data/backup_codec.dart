import 'dart:convert';

import '../models/_coerce.dart';
import '../models/dosage.dart';
import '../models/settings.dart';
import '../models/strain.dart';

const int currentBackupVersion = 1;

class BackupPayload {
  final int version;
  final DateTime? createdAt;
  final List<Strain> strains;
  final List<Dosage> dosages;
  final UserSettings? settings;
  final String? userName;
  final List<Dosage> orphanedDosages;

  /// True when the backup file carried an explicit `strains` list — a full
  /// export — even when the list was empty. False for absent, null, or
  /// non-list values: they cannot express "no strains" and must not clear
  /// local strains.
  final bool hasStrainCollection;

  /// Same contract for `dosages`: explicit list only. A bare top-level dose
  /// array counts as an explicit dosages collection.
  final bool hasDosageCollection;

  const BackupPayload({
    required this.version,
    required this.createdAt,
    required this.strains,
    required this.dosages,
    required this.settings,
    required this.userName,
    this.orphanedDosages = const [],
    required this.hasStrainCollection,
    required this.hasDosageCollection,
  });
}

class BackupSummary {
  final int strainCount;
  final int dosageCount;
  final DateTime? earliestDose;
  final DateTime? latestDose;
  final double totalGrams;
  final List<String> warnings;

  const BackupSummary({
    required this.strainCount,
    required this.dosageCount,
    required this.earliestDose,
    required this.latestDose,
    required this.totalGrams,
    required this.warnings,
  });
}

sealed class BackupParseResult {
  const BackupParseResult();
}

class BackupOk extends BackupParseResult {
  final BackupPayload payload;
  final BackupSummary summary;

  const BackupOk(this.payload, this.summary);
}

class BackupError extends BackupParseResult {
  final String message;
  final List<String> details;

  const BackupError(this.message, [this.details = const []]);
}

BackupParseResult parseBackup(String jsonText) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (error) {
    return BackupError('Backup is not valid JSON', [error.message]);
  } catch (error) {
    return BackupError('Backup could not be read', [error.toString()]);
  }

  if (decoded is! Map && decoded is! List) {
    return const BackupError(
      'Backup must be an object or a list of dosages',
    );
  }

  final root = decoded is Map ? _stringMap(decoded) : null;
  final version = root == null ? 1 : asInt(root['version'], fallback: 1);
  if (version > currentBackupVersion) {
    return BackupError(
      'Backup version $version is newer than supported version '
      '$currentBackupVersion',
    );
  }

  final warnings = <String>[];
  final strains = _parseStrains(root?['strains'], warnings);
  final rawDosages = _parseDosages(
    decoded is List ? decoded : root?['dosages'],
    warnings,
  );
  final hasStrainCollection = root?['strains'] is List;
  final hasDosageCollection =
      decoded is List || root?['dosages'] is List;
  final strainIds = strains.map((strain) => strain.id).toSet();
  final orphanedDosages = hasStrainCollection
      ? rawDosages
          .where((dose) => !strainIds.contains(dose.strainId))
          .toList(growable: false)
      : const <Dosage>[];
  final orphanedDosageCount = orphanedDosages.length;
  final dosages = hasStrainCollection
      ? rawDosages
          .where((dose) => strainIds.contains(dose.strainId))
          .toList(growable: false)
      : rawDosages;
  if (orphanedDosageCount > 0) {
    // The import recovers these under a placeholder strain that keeps the
    // original missing strain ID (merge reattaches to a matching local
    // strain), so the warning must not claim they were dropped.
    warnings.add(
      '$orphanedDosageCount ${_plural(orphanedDosageCount, 'dose', 'doses')} '
      'referenced a strain missing from the backup',
    );
  }

  // A valid backup schema can be empty: the app exports strains/dosages/
  // settings/userName keys even with no records, and restoring its own
  // empty export must work. Garbage that only happens to decode as a Map —
  // no recognised keys at all — still gets rejected.
  final hasBackupShape = root != null &&
      (root['strains'] is List ||
          root['dosages'] is List ||
          root['settings'] is Map ||
          root['userName'] is String ||
          root['user_name'] is String);
  if (strains.isEmpty &&
      dosages.isEmpty &&
      orphanedDosages.isEmpty &&
      !hasBackupShape) {
    return BackupError(
      'Backup contained no recoverable strains or dosages',
      warnings,
    );
  }

  UserSettings? settings;
  if (root?['settings'] is Map) {
    try {
      settings = UserSettings.fromJson(_stringMap(root!['settings'] as Map));
    } catch (error) {
      warnings.add('Settings were malformed and were skipped: $error');
    }
  }

  final createdAt = DateTime.tryParse(
    asString(root?['createdAt'] ?? root?['timestamp']),
  );
  final sortedDates = [...dosages, ...orphanedDosages]
      .map((dose) => dose.timestamp)
      .toList()
    ..sort();
  final importedDosages = [...dosages, ...orphanedDosages];
  final payload = BackupPayload(
    version: version,
    createdAt: createdAt,
    strains: List.unmodifiable(strains),
    dosages: List.unmodifiable(dosages),
    settings: settings,
    userName: _optionalString(root?['userName'] ?? root?['user_name']),
    orphanedDosages: List.unmodifiable(orphanedDosages),
    hasStrainCollection: hasStrainCollection,
    hasDosageCollection: hasDosageCollection,
  );
  final summary = BackupSummary(
    strainCount: strains.length,
    dosageCount: importedDosages.length,
    earliestDose: sortedDates.isEmpty ? null : sortedDates.first,
    latestDose: sortedDates.isEmpty ? null : sortedDates.last,
    totalGrams: importedDosages.fold(0, (sum, dose) => sum + dose.amount),
    warnings: List.unmodifiable(warnings),
  );
  return BackupOk(payload, summary);
}

List<Strain> _parseStrains(dynamic value, List<String> warnings) {
  if (value == null) return const [];
  if (value is! List) {
    warnings.add('Strains were not a list and were skipped');
    return const [];
  }
  var malformed = 0;
  final result = <Strain>[];
  for (final item in value) {
    if (item is! Map) {
      malformed++;
      continue;
    }
    final map = _stringMap(item);
    // Per-row isolation: a single undecodable strain (e.g. a non-finite
    // number reaching asInt) must not abort the whole backup — the rest of
    // the file still parses and doses referencing the bad row are kept as
    // orphans by the caller.
    final Strain strain;
    try {
      strain = Strain.fromJson(map);
    } catch (_) {
      malformed++;
      continue;
    }
    if (strain.id.isEmpty || strain.name.isEmpty || strain.code.isEmpty) {
      malformed++;
      continue;
    }
    result.add(strain);
  }
  if (malformed > 0) {
    warnings.add('$malformed malformed strains were skipped');
  }
  return result;
}

List<Dosage> _parseDosages(dynamic value, List<String> warnings) {
  if (value == null) return const [];
  if (value is! List) {
    warnings.add('Dosages were not a list and were skipped');
    return const [];
  }
  var malformed = 0;
  final result = <Dosage>[];
  for (final item in value) {
    if (item is! Map) {
      malformed++;
      continue;
    }
    final map = _stringMap(item);
    final timestamp = DateTime.tryParse(asString(map['timestamp']));
    final amount = asDouble(map['amount'], fallback: double.nan);
    if (asString(map['id']).isEmpty ||
        asString(map['strainId']).isEmpty ||
        timestamp == null ||
        !amount.isFinite ||
        amount <= 0) {
      malformed++;
      continue;
    }
    result.add(Dosage.fromJson(map));
  }
  if (malformed > 0) {
    warnings.add(
      '$malformed ${_plural(malformed, 'malformed dosage was', 'malformed '
          'dosages were')} skipped',
    );
  }
  return result;
}

Map<String, dynamic> _stringMap(Map<dynamic, dynamic> value) =>
    value.map((key, value) => MapEntry(key.toString(), value));

String? _optionalString(dynamic value) {
  final result = asString(value);
  return result.isEmpty ? null : result;
}

String _plural(int count, String singular, String plural) =>
    count == 1 ? singular : plural;
