import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class WebBackupService {
  static Future<void> downloadFile(String content, String fileName) async {
    try {
      // Create a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Kratom Tracker Backup',
      );
      
      // Clean up
      await file.delete();
    } catch (e) {
      debugPrint('Error sharing file: $e');
      rethrow;
    }
  }
} 