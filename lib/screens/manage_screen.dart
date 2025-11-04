import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/notification_service.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final settings = provider.settings;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Enable Notifications'),
            subtitle: const Text('Daily reminders and alerts'),
            trailing: Switch(
              value: settings.enableNotifications,
              onChanged: (value) async {
                await provider.updateSettings(enableNotifications: value);
                if (value) {
                  await NotificationService().scheduleReminders(provider.settings);
                } else {
                  await NotificationService().cancelAllReminders();
                }
              },
            ),
          ),
          if (settings.enableNotifications) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Morning Reminder'),
              subtitle: Text(settings.morningReminder != null
                  ? 'Set for ${settings.morningReminder!.format(context)}'
                  : 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: settings.morningReminder ?? const TimeOfDay(hour: 8, minute: 0),
                );
                if (time != null) {
                  await provider.updateSettings(morningReminder: time);
                  await NotificationService().scheduleReminders(provider.settings);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.nightlight_outlined),
              title: const Text('Evening Reminder'),
              subtitle: Text(settings.eveningReminder != null
                  ? 'Set for ${settings.eveningReminder!.format(context)}'
                  : 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: settings.eveningReminder ?? const TimeOfDay(hour: 20, minute: 0),
                );
                if (time != null) {
                  await provider.updateSettings(eveningReminder: time);
                  await NotificationService().scheduleReminders(provider.settings);
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('Daily Limit'),
              subtitle: Text(settings.dailyLimit > 0
                  ? '${settings.dailyLimit.toStringAsFixed(1)}g per day'
                  : 'No limit set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDailyLimitDialog(context, provider),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Tolerance Tracking'),
              subtitle: Text(settings.enableToleranceTracking
                  ? 'Alert every ${settings.toleranceBreakInterval} days'
                  : 'Disabled'),
              trailing: Switch(
                value: settings.enableToleranceTracking,
                onChanged: (value) async {
                  await provider.updateSettings(enableToleranceTracking: value);
                },
              ),
            ),
            if (settings.enableToleranceTracking) ...[
              const Divider(height: 1),
              ListTile(
                leading: const SizedBox(width: 24), // Indent
                title: const Text('Break Interval (days)'),
                subtitle: Text('${settings.toleranceBreakInterval} days'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showToleranceIntervalDialog(context, provider),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showDailyLimitDialog(BuildContext context, KratomProvider provider) async {
    final controller = TextEditingController(
      text: provider.settings.dailyLimit > 0
          ? provider.settings.dailyLimit.toStringAsFixed(1)
          : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Daily Limit'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Daily limit (grams)',
            hintText: '0 for no limit',
            suffixText: 'g',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? 0;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await provider.updateSettings(dailyLimit: result);
    }
  }

  Future<void> _showToleranceIntervalDialog(BuildContext context, KratomProvider provider) async {
    final controller = TextEditingController(
      text: provider.settings.toleranceBreakInterval.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolerance Break Interval'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Days',
            hintText: 'Recommended: 7-30 days',
            suffixText: 'days',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 7;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await provider.updateSettings(toleranceBreakInterval: result);
    }
  }

  Widget _buildBackupCard(BuildContext context, KratomProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Create Backup (JSON)'),
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
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export to CSV'),
            subtitle: const Text('Export data for spreadsheet analysis'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportCsv(context, provider),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Generate PDF Report'),
            subtitle: const Text('Create a professional report'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportPdf(context, provider),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, KratomProvider provider) async {
    final options = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Basic Dosage Log'),
              subtitle: const Text('Date, time, strain, amount, notes'),
              onTap: () => Navigator.pop(context, 'basic'),
            ),
            ListTile(
              title: const Text('Detailed with Effects'),
              subtitle: const Text('Includes mood, energy, pain ratings'),
              onTap: () => Navigator.pop(context, 'detailed'),
            ),
            ListTile(
              title: const Text('Monthly Summary'),
              subtitle: const Text('Grouped by month'),
              onTap: () => Navigator.pop(context, 'monthly'),
            ),
            ListTile(
              title: const Text('Strain Analytics'),
              subtitle: const Text('Strain effectiveness data'),
              onTap: () => Navigator.pop(context, 'strains'),
            ),
          ],
        ),
      ),
    );

    if (options == null) return;

    await _showAsyncDialog(
      context,
      () async {
        final strainMap = {for (var s in provider.strains) s.id: s};
        String csvContent;
        String filename;

        switch (options) {
          case 'basic':
            csvContent = await CsvExportService.generateDosagesCsv(
              provider.dosages,
              strainMap,
            );
            filename = 'kratom_dosages.csv';
            break;
          case 'detailed':
            csvContent = await CsvExportService.generateDetailedCsv(
              provider.dosages,
              strainMap,
              [], // Effects - would need to be added to provider
            );
            filename = 'kratom_detailed.csv';
            break;
          case 'monthly':
            csvContent = await CsvExportService.generateMonthlySummaryCsv(
              provider.dosages,
            );
            filename = 'kratom_monthly_summary.csv';
            break;
          case 'strains':
            final analytics = {
              for (var strain in provider.strains)
                strain.id: provider.getStrainAnalytics(strain.id)
            };
            csvContent = await CsvExportService.generateStrainAnalyticsCsv(
              provider.strains,
              analytics,
            );
            filename = 'kratom_strain_analytics.csv';
            break;
          default:
            return;
        }

        await CsvExportService.exportAndShare(csvContent, filename);
      },
      'CSV exported successfully',
    );
  }

  Future<void> _exportPdf(BuildContext context, KratomProvider provider) async {
    final timeRange = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Last 7 Days'),
              onTap: () => Navigator.pop(context, '7days'),
            ),
            ListTile(
              title: const Text('Last 30 Days'),
              onTap: () => Navigator.pop(context, '30days'),
            ),
            ListTile(
              title: const Text('Last 90 Days'),
              onTap: () => Navigator.pop(context, '90days'),
            ),
            ListTile(
              title: const Text('All Time'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
      ),
    );

    if (timeRange == null) return;

    await _showAsyncDialog(
      context,
      () async {
        DateTime? startDate;
        DateTime? endDate;

        switch (timeRange) {
          case '7days':
            endDate = DateTime.now();
            startDate = endDate.subtract(const Duration(days: 7));
            break;
          case '30days':
            endDate = DateTime.now();
            startDate = endDate.subtract(const Duration(days: 30));
            break;
          case '90days':
            endDate = DateTime.now();
            startDate = endDate.subtract(const Duration(days: 90));
            break;
        }

        final strainMap = {for (var s in provider.strains) s.id: s};

        await PdfExportService.generateAndShareReport(
          dosages: provider.dosages,
          strainMap: strainMap,
          effects: [], // Effects - would need to be added to provider
          userName: provider.userName ?? 'User',
          startDate: startDate,
          endDate: endDate,
        );
      },
      'PDF report generated successfully',
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
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.favorite_outline,
              color: Colors.red,
            ),
            title: const Text('Support Development'),
            subtitle: const Text('Buy me a coffee if you find the app useful'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              const url = 'https://buymeacoffee.com/alint';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
        ],
      ),
    );
  }
} 