import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../providers/theme_provider.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  Future<void> _showAsyncDialog(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      _showSuccessDialog(context, successMessage);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, e.toString());
    }
  }

  Future<void> _createBackup(BuildContext context, KratomProvider provider) async {
    await _showAsyncDialog(
      context,
      () async {
        final backupData = await provider.createBackup();
        final backupJson = jsonEncode(backupData);
        
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final filename = 'kratom_tracker_backup_$timestamp.json';
        
        await Share.shareXFiles(
          [
            XFile.fromData(
              utf8.encode(backupJson) as dynamic,
              name: filename,
              mimeType: 'application/json',
            ),
          ],
          subject: 'Kratom Tracker Backup',
        );
      },
      'Backup created successfully',
    );
  }

  Future<void> _restoreBackup(BuildContext context, KratomProvider provider) async {
    await _showAsyncDialog(
      context,
      () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (result != null) {
          final file = File(result.files.single.path!);
          final jsonData = await file.readAsString();
          
          if (provider.validateBackup(jsonData)) {
            await provider.restoreBackup(jsonData);
          } else {
            throw Exception('Invalid backup file');
          }
        }
      },
      'Backup restored successfully',
    );
  }

  Future<void> _showClearDataDialog(BuildContext context, KratomProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This action cannot be undone. Consider creating a backup first.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _showAsyncDialog(
        context,
        () => provider.clearAllData(),
        'All data has been cleared',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Text(
              'Manage',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // App Settings Section
                _buildSectionHeader(
                  'App Settings',
                  Icons.settings_outlined,
                  Colors.blue,
                ),
                _buildThemeSettings(context),
                _buildNotificationSettings(context, provider),
                
                const SizedBox(height: 24),
                // Backup & Restore Section
                _buildSectionHeader(
                  'Backup & Restore',
                  Icons.cloud_outlined,
                  Colors.teal,
                ),
                _buildBackupCard(context, provider),
                
                const SizedBox(height: 24),
                // Data Management Section
                _buildSectionHeader(
                  'Data Management',
                  Icons.storage_outlined,
                  Colors.purple,
                ),
                _buildDataManagementCard(context, provider),
                
                const SizedBox(height: 24),
                // About Section
                _buildSectionHeader(
                  'About',
                  Icons.info_outline,
                  Colors.amber,
                ),
                _buildAboutCard(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSettings(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable dark theme'),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(BuildContext context, KratomProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Dosage Reminders'),
            subtitle: const Text(
              'Currently not implemented. We aim to provide tracking tools without encouraging unnecessary usage.',
              style: TextStyle(fontSize: 13),
            ),
            trailing: Switch(
              value: false,
              onChanged: null,  // Disabled switch
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(BuildContext context, KratomProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Create Backup'),
            subtitle: const Text('Export your data as JSON file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _createBackup(context, provider),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore Backup'),
            subtitle: const Text('Import data from backup file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _restoreBackup(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementCard(BuildContext context, KratomProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Clear All Data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Delete all tracked data'),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () => _showClearDataDialog(context, provider),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
} 