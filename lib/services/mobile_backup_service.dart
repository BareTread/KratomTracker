import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class WebBackupService {
  static Future<void> downloadFile(String content, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Kratom Tracker Backup',
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
      rethrow;
    }
  }
} 