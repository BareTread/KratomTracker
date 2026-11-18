import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/models/settings.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identity property: exporting state, restoring it into a fresh provider via
/// replace-import, and exporting again must yield the same backup payload —
/// ignoring only the top-level `timestamp` envelope field, which is generated
/// at export time. Any other difference means restore rewrote user data
/// (e.g. an icon string that exports raw but normalises through
/// Strain.fromJson on restore).
void main() {
  test('export → replace-restore → export reproduces the backup payload',
      () async {
    SharedPreferences.setMockInitialValues({});
    final source =
        await KratomProvider.create(await SharedPreferences.getInstance());

    // 'Leaf' is the legacy Material icon name the public addStrain API still
    // accepts; Strain.fromJson normalises it to a LeafShape.name on restore.
    // 'palmate' is already canonical.
    await source.addStrain('Green Malay', 'GRN', 0xFF2E7D32, 'Leaf');
    await source.addStrain(
      'Red Bali',
      'RDB',
      0xFFB71C1C,
      'palmate',
      inStock: false,
    );

    final greenId = source.strains.first.id;
    final redId = source.strains.last.id;

    await source.addDosage(
      greenId,
      2.5,
      DateTime(2025, 3, 14, 9, 30), // local timestamp
      notes: 'Morning burn — calm, steady mood',
    );
    await source.addDosage(
      redId,
      3.25,
      DateTime.utc(2025, 11, 2, 22, 15), // UTC timestamp
      notes: 'late dose\nsplit across lines',
    );
    await source.addDosage(
      greenId,
      1.0,
      DateTime(2025, 3, 15, 18, 5), // no notes
    );

    await source.updateSettings(
      const UserSettings(
        dailyLimit: 12.5,
        measurementUnit: 'oz',
        performanceMode: true,
      ),
    );
    await source.updateUserName('  Alin  ');

    final firstExport = await source.exportJson();

    // Reset the SharedPreferences mock to empty and rebuild from the backup.
    SharedPreferences.setMockInitialValues({});
    final restored =
        await KratomProvider.create(await SharedPreferences.getInstance());
    final parsed = parseBackup(firstExport);
    expect(parsed, isA<BackupOk>());
    final payload = (parsed as BackupOk).payload;
    await restored.commitImport(payload, mode: ImportMode.replace);

    final secondExport = await restored.exportJson();

    final first = jsonDecode(firstExport) as Map<String, dynamic>
      ..remove('timestamp');
    final second = jsonDecode(secondExport) as Map<String, dynamic>
      ..remove('timestamp');

    // Flutter's equals matcher performs deep collection equality, so a
    // second equality convention is not needed here.
    expect(second, equals(first));
  });
}

