import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                'Terms of service',
                style: AppType.display(size: 36, color: context.c.textPrimary),
              ),
            ),
            _buildSection(
              'Acceptance of terms',
              'By using this app, you agree to these terms of service. If you do not '
              'agree, please do not use the app.',
            ),
            _buildSection(
              'Purpose',
              'This app is designed for personal tracking purposes only. It is not '
              'intended to provide medical advice or encourage substance use.',
            ),
            _buildSection(
              'User responsibilities',
              'You are responsible for:\n'
              '• All data entered into the app\n'
              '• Maintaining the security of your device\n'
              '• Creating backups of your data\n'
              '• Using the app in accordance with local laws',
            ),
            _buildSection(
              'Disclaimer',
              'This app is provided "as is" without warranties of any kind. We are '
              'not responsible for any decisions made based on the data tracked '
              'in this app.',
            ),
            _buildSection(
              'Limitations',
              'We are not liable for any damages arising from the use or inability '
              'to use this app.',
            ),
            _buildSection(
              'Data ownership',
              'You retain full ownership of all data entered into the app. We do '
              'not claim any rights to your personal information or usage data.',
            ),
            _buildSection(
              'Modifications',
              'We reserve the right to modify these terms at any time. Continued '
              'use of the app constitutes acceptance of any changes.',
            ),
            _buildSection(
              'Legal compliance',
              'You agree to use this app in compliance with all applicable laws in your '
              'jurisdiction. The app is intended for personal tracking only and should not '
              'be used for any illegal purposes.',
            ),
            _buildSection(
              'Termination',
              'We reserve the right to terminate access to the app for any user who '
              'violates these terms or uses the app for illegal purposes.',
            ),
            _buildSection(
              'Governing law',
              'These terms are governed by applicable laws. Any disputes shall be resolved '
              'in accordance with the laws of your jurisdiction.',
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