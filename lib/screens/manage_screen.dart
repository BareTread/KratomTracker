import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_version.dart';
import '../data/backup_codec.dart';
import '../providers/kratom_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/sheet_header.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Test seam for the support-link launcher. Production uses [launchUrl].
@visibleForTesting
Future<bool> Function(Uri url, {LaunchMode mode}) launchSupportUrl = launchUrl;

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

  Future<void> _createBackup(
    BuildContext context,
    KratomProvider provider,
  ) async {
    await _showAsyncDialog(
      context,
      () async {
        final backupJson = await provider.exportJson();

        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final filename = 'herbal_tracker_plus_backup_$timestamp.json';

        await Share.shareXFiles(
          [
            XFile.fromData(
              utf8.encode(backupJson) as dynamic,
              name: filename,
              mimeType: 'application/json',
            ),
          ],
          subject: 'Herbal Tracker+ Backup',
        );
      },
      'Backup created successfully',
    );
  }

  Future<void> _restoreBackup(
    BuildContext context,
    KratomProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || !context.mounted) return;

      final path = result.files.single.path;
      if (path == null) {
        if (!context.mounted) return;
        _showErrorDialog(
          context,
          'Could not access the selected file. Please try again.',
        );
        return;
      }
      final file = File(path);
      final jsonData = await file.readAsString();
      final summary = await provider.previewImport(jsonData);
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current data?'),
          content: Text(
            'Import ${summary.strainCount} strains and '
            '${summary.dosageCount} doses. This replaces current data.'
            '${summary.warnings.isEmpty ? '' : '\n\n${summary.warnings.join('\n')}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      final parsed = parseBackup(jsonData);
      if (parsed case BackupOk(:final payload)) {
        await provider.commitImport(payload, mode: ImportMode.replace);
        if (context.mounted) {
          _showSuccessDialog(context, 'Backup restored successfully');
        }
      } else {
        throw const FormatException('Invalid backup file');
      }
    } catch (e) {
      if (context.mounted) _showErrorDialog(context, e.toString());
    }
  }

  Future<void> _showClearDataDialog(
    BuildContext context,
    KratomProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This deletes all strains, all logged doses, and your profile name, '
          'and resets your tracking settings. Your appearance choice is kept. '
          'This cannot be undone. Create a backup first if you may want this back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.c.caution),
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
              style: AppType.display(size: 34, color: context.c.textPrimary),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.loadWarnings.isNotEmpty)
                  _buildLoadWarnings(provider),
                _buildSectionHeader('Profile & display'),
                _buildProfileCard(context),
                _buildSectionHeader('Backup & restore'),
                _buildBackupCard(context, provider),
                _buildSectionHeader('Data'),
                _buildDataManagementCard(context, provider),
                _buildSectionHeader('About'),
                _buildAboutCard(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Center(
                    child: Text(
                      'Herbal Tracker+ $kAppVersion',
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 12,
                        color: context.c.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Quiet section label: sentence-case grey text, no rule, no tracked caps.
  Widget _buildSectionHeader(String title) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.textTertiary,
          letterSpacing: 0,
        ),
      ),
    );
  }

  /// The one quiet trailing mark for rows that navigate or open elsewhere:
  /// an 18dp chevron (or external-link glyph) in tertiary ink at 0.7 alpha.
  Widget _trailingIcon(IconData icon) =>
      Icon(icon, size: 18, color: context.c.textTertiary.withValues(alpha: 0.7));

  /// Persistent calm notice shown when the provider reports load warnings.
  /// Border-only caution styling — no alert icon stack, no dismiss.
  Widget _buildLoadWarnings(KratomProvider provider) {
    final c = context.c;
    return Padding(
      key: const Key('manage-load-warnings'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.caution.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Some saved data could not be loaded',
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your other data is intact. Make a backup now, or restore one '
              'if something is missing.',
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 14,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final warning in provider.loadWarnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '– $warning',
                  style: TextStyle(
                    fontFamily: AppType.sans,
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _createBackup(context, provider),
                    child: const Text('Create backup'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _restoreBackup(context, provider),
                    child: const Text('Restore backup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final c = context.c;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text('Profile'),
            trailing: _trailingIcon(Icons.chevron_right),
            onTap: () => showAppSheet<void>(
              context,
              builder: (_) => const EditProfileSheet(),
            ),
          ),
          Divider(height: 1, color: c.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance'),
                const SizedBox(height: 8),
                Consumer<ThemeProvider>(
                  builder: (context, theme, _) => Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        for (final mode in ThemeMode.values)
                          Expanded(
                            child: _AppearanceSegment(
                              label: switch (mode) {
                                ThemeMode.system => 'System',
                                ThemeMode.light => 'Light',
                                ThemeMode.dark => 'Dark',
                              },
                              selected: theme.themeMode == mode,
                              onTap: () => context
                                  .read<ThemeProvider>()
                                  .setThemeMode(mode),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(BuildContext context, KratomProvider provider) {
    final hairline = context.c.hairline;
    return _panel(
      child: Column(
        children: [
          ListTile(
            title: const Text('Create backup'),
            trailing: _trailingIcon(Icons.chevron_right),
            onTap: () => _createBackup(context, provider),
          ),
          Divider(height: 1, color: hairline),
          ListTile(
            title: const Text('Restore backup'),
            trailing: _trailingIcon(Icons.chevron_right),
            onTap: () => _restoreBackup(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementCard(
    BuildContext context,
    KratomProvider provider,
  ) {
    final caution = context.c.caution;
    return _panel(
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Clear all data',
              style: TextStyle(color: caution),
            ),
            trailing: _trailingIcon(Icons.chevron_right),
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
    final c = context.c;
    return _panel(
      child: Column(
        children: [
          
          ListTile(
            title: const Text('Privacy policy'),
            trailing: _trailingIcon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: c.hairline),
          ListTile(
            title: const Text('Terms of service'),
            trailing: _trailingIcon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: c.hairline),
          ListTile(
            title: const Text('Support development'),
            trailing: _trailingIcon(Icons.open_in_new),
            onTap: () => _openSupportLink(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupportLink(BuildContext context) async {
    const url = 'https://buymeacoffee.com/alint';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchSupportUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// One segment of the Appearance control: transparent on the sunken track,
/// a raised pill (surface + hairline) when selected.
class _AppearanceSegment extends StatelessWidget {
  const _AppearanceSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: double.infinity,
            decoration: selected
                ? BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.hairline),
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? c.textPrimary : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
