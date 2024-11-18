import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  bool _isProcessing = false;

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError 
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _showRestoreConfirmDialog(
    BuildContext context,
    Map<String, dynamic> backupInfo,
    Function() onConfirm,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup date: ${DateFormat('MMM d, y').format(backupInfo['timestamp'])}'),
            Text('Strains: ${backupInfo['strainCount']}'),
            Text('Dosages: ${backupInfo['dosageCount']}'),
            Text('Effects: ${backupInfo['effectCount']}'),
            const SizedBox(height: 16),
            const Text(
              'Warning: This will replace all existing data. '
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackup() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final provider = context.read<KratomProvider>();
      final data = await provider.exportData();
      
      final now = DateTime.now();
      final fileName = 'kratom_tracker_backup_${now.year}${now.month}${now.day}.json';
      
      if (!mounted) return;
      
      final bytes = Uint8List.fromList(utf8.encode(data));
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Kratom Tracker Backup',
      );

      if (!mounted) return;
      _showMessage('Backup created successfully');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to create backup: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;

      final file = File(result.files.single.path!);
      final jsonData = await file.readAsString();

      if (!mounted) return;
      final provider = context.read<KratomProvider>();
      
      // Validate backup first
      if (!provider.validateBackup(jsonData)) {
        throw Exception('Invalid backup file');
      }

      // Show backup info before restoring
      final backupInfo = provider.getBackupInfo(jsonData);
      
      if (!mounted) return;

      await _showRestoreConfirmDialog(
        context,
        backupInfo,
        () async {
          if (!mounted) return;
          await provider.importData(jsonData);
          if (!mounted) return;
          _showMessage('Data restored successfully');
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to restore backup: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.backup,
                    title: 'Backup & Restore',
                  ),
                  Card(
                    child: Column(
                      children: [
                        _ManageOption(
                          icon: Icons.file_upload,
                          title: 'Create Backup',
                          subtitle: 'Export your data as JSON file',
                          onTap: _handleBackup,
                        ),
                        const Divider(height: 1),
                        _ManageOption(
                          icon: Icons.file_download,
                          title: 'Restore Backup',
                          subtitle: 'Import data from backup file',
                          onTap: _handleRestore,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    icon: Icons.delete_outline,
                    title: 'Data Management',
                  ),
                  Card(
                    child: _ManageOption(
                      icon: Icons.delete_forever,
                      title: 'Clear All Data',
                      subtitle: 'Delete all tracked data',
                      iconColor: Colors.red,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Clear All Data'),
                              ],
                            ),
                            content: const Text(
                              'This action will permanently delete all your tracked data. '
                              'Consider creating a backup before proceeding.\n\n'
                              'Are you sure you want to continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<KratomProvider>().clearAllData();
                                  Navigator.pop(context);
                                  _showMessage('All data has been cleared');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Clear All Data'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ManageOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
} 