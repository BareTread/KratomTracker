import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/data/backup_codec.dart';
import 'package:kratom_tracker_plus/models/settings.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The settings model dropped five dead fields (notifications, reminders,
/// tolerance tracking). Stored JSON written by older builds still carries
/// them — including malformed values — and must load cleanly while the live
/// fields never re-emit the dead keys.
void main() {
  test('old stored settings with dead fields load without error', () {
    final settings = UserSettings.fromJson({
      'enableNotifications': true,
      'morningReminder': 8,
      'morningReminderMinute': 30,
      'eveningReminder': 21,
      'eveningReminderMinute': 45,
      'dailyLimit': 12.5,
      'enableToleranceTracking': true,
      'toleranceBreakInterval': 'not-a-number', // malformed legacy value
      'measurementUnit': 'oz',
      'performanceMode': true,
    });

    expect(settings.dailyLimit, 12.5);
    expect(settings.measurementUnit, 'oz');
    expect(settings.performanceMode, true);
  });

  test('toJson never re-emits dead keys', () {
    final settings = UserSettings.fromJson({
      'enableNotifications': true,
      'morningReminder': 8,
      'morningReminderMinute': 30,
      'eveningReminder': 21,
      'eveningReminderMinute': 45,
      'enableToleranceTracking': true,
      'toleranceBreakInterval': 14,
      'dailyLimit': 3,
    });

    expect(
      settings.toJson().keys,
      ['dailyLimit', 'measurementUnit', 'performanceMode'],
    );
  });

  test('stored settings JSON with dead keys loads into the provider',
      () async {
    SharedPreferences.setMockInitialValues({
      'settings': jsonEncode({
        'enableNotifications': false,
        'morningReminder': 'bogus',
        'dailyLimit': 5,
        'enableToleranceTracking': true,
        'toleranceBreakInterval': 7,
        'measurementUnit': 'g',
        'performanceMode': false,
      }),
    });
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());

    expect(provider.settings.dailyLimit, 5);
    expect(provider.settings.measurementUnit, 'g');
  });

  test('an old backup settings block imports with live fields only',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());

    final backup = jsonEncode({
      'version': 1,
      'strains': [
        {
          'id': 's1',
          'name': 'Green',
          'code': 'GRN',
          'color': 1,
          'icon': 'leaf',
        },
      ],
      'dosages': [
        {
          'id': 'd1',
          'strainId': 's1',
          'amount': 1,
          'timestamp': '2025-01-01T08:00:00.000',
        },
      ],
      'settings': {
        'enableNotifications': true,
        'morningReminder': 8,
        'toleranceBreakInterval': 30,
        'dailyLimit': 9,
        'measurementUnit': 'oz',
      },
    });

    await provider.previewImport(backup);
    final parsed = parseBackup(backup);
    expect(parsed, isA<BackupOk>());
    await provider.commitImport(
      (parsed as BackupOk).payload,
      mode: ImportMode.replace,
    );

    // Export again: the re-emitted settings carry only live keys.
    final exported =
        jsonDecode(await provider.exportJson()) as Map<String, dynamic>;
    expect(
      (exported['settings'] as Map).keys,
      ['dailyLimit', 'measurementUnit', 'performanceMode'],
    );
  });
}
