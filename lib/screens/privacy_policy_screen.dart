import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Privacy policy',
                style: AppType.display(size: 36, color: context.c.textPrimary),
              ),
            ),
            _buildSection(
              'Data collection and storage',
              'All data is stored locally on your device. We do not collect, store, '
              'or transmit any personal information or usage data to external servers.',
            ),
            _buildSection(
              'Your data',
              'Your dosage history, strain information, and settings are stored '
              'only on your device. You have full control over your data and can '
              'delete it at any time through the app settings.',
            ),
            _buildSection(
              'Backups',
              'When you create a backup, the data is exported as a local file on '
              'your device. We recommend keeping these backups secure as they '
              'contain your usage history.',
            ),
            _buildSection(
              'Permissions',
              'The app requires minimal permissions to function. We only request '
              'access to storage for backup/restore functionality.',
            ),
            _buildSection(
              'Third-party services',
              'This app does not integrate with any third-party services or '
              'analytics platforms. Your usage remains completely private.',
            ),
            _buildSection(
              'Updates',
              'This privacy policy may be updated periodically. Check back for '
              'any changes that may affect how your information is handled.',
            ),
            _buildSection(
              'Contact',
              'If you have any questions about this privacy policy or the app\'s '
              'data handling practices, please reach out through the official '
              'support channels.',
            ),
            _buildSection(
              'Data Security',
              'While all data is stored locally on your device, we recommend using your '
              'device\'s built-in security features (like screen lock) to protect your data. '
              'Keep your backups secure as they contain your personal information.',
            ),
            _buildSection(
              'Age Restriction',
              'This app is intended for use by adults only. We do not knowingly collect '
              'or store information from individuals under the legal age in their jurisdiction.',
            ),
            _buildSection(
              'Your Rights',
              'You have complete control over your data. You can access, modify, export, '
              'or delete all your data at any time through the app settings.',
            ),
            const SizedBox(height: 24),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: TextStyle(
                color: context.c.textTertiary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Builder(builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 15,
                  height: 1.5,
                  color: context.c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    },);
  }
} 