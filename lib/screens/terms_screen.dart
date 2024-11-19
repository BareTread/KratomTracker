import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Acceptance of Terms',
              'By using this app, you agree to these terms of service. If you do not '
              'agree, please do not use the app.',
            ),
            _buildSection(
              'Purpose',
              'This app is designed for personal tracking purposes only. It is not '
              'intended to provide medical advice or encourage substance use.',
            ),
            _buildSection(
              'User Responsibilities',
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
              'Data Ownership',
              'You retain full ownership of all data entered into the app. We do '
              'not claim any rights to your personal information or usage data.',
            ),
            _buildSection(
              'Modifications',
              'We reserve the right to modify these terms at any time. Continued '
              'use of the app constitutes acceptance of any changes.',
            ),
            const SizedBox(height: 24),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
} 