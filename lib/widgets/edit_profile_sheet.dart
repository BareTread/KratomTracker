import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'sheet_header.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<KratomProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SheetHeader.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    helperText: 'Shown on Home. Stays on this device.',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    foregroundColor: AppColors.dark.surfaceSunken,
                  ),
                  onPressed: () {
                    final name = _nameController.text.trim();
                    context.read<KratomProvider>()
                        .updateUserName(name.isEmpty ? null : name);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
