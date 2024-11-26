import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'web_backup_service.dart' if (dart.library.io) 'mobile_backup_service.dart';

class BackupService {
  final SharedPreferences prefs;

  BackupService(this.prefs);

  Future<void> pickFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result != null && context.mounted) {
          final bytes = result.files.first.bytes!;
          await processBackupBytes(bytes, context);
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result != null && context.mounted) {
          final file = File(result.files.first.path!);
          await processBackupFile(file, context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> processBackupBytes(List<int> bytes, BuildContext context) async {
    try {
      final String jsonString = utf8.decode(bytes);
      final Map<String, dynamic> backupData = json.decode(jsonString);
      if (context.mounted) {
        await _restoreFromBackup(backupData, context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid backup file format: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> processBackupFile(File file, BuildContext context) async {
    try {
      final String jsonString = await file.readAsString();
      final Map<String, dynamic> backupData = json.decode(jsonString);
      if (context.mounted) {
        await _restoreFromBackup(backupData, context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading backup file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromBackup(Map<String, dynamic> backupData, BuildContext context) async {
    try {
      // Clear existing data
      await prefs.clear();

      // Restore all data from backup
      for (var entry in backupData.entries) {
        final String key = entry.key;
        final dynamic value = entry.value;

        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(key, value);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> createBackup(BuildContext context) async {
    try {
      // Get all data from SharedPreferences
      final Map<String, dynamic> backupData = {};
      final Set<String> keys = prefs.getKeys();

      for (String key in keys) {
        backupData[key] = prefs.get(key);
      }

      // Convert to JSON
      final String jsonString = json.encode(backupData);

      if (kIsWeb) {
        await WebBackupService.downloadFile(
          jsonString,
          'kratom_tracker_backup.json',
        );
      } else {
        // Mobile platform handling
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/kratom_tracker_backup.json');
        await file.writeAsString(jsonString);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved to: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 