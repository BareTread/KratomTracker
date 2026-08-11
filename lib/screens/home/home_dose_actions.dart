import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_dosage_form.dart';

Future<void> showDosageOptions(BuildContext context, Dosage dosage) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.c.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: sheetContext.c.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.replay_outlined),
            title: const Text('Log again now'),
            subtitle: const Text(
              'Add the same strain and amount at the current time',
            ),
            onTap: () => _logAgain(context, dosage),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Dose'),
            onTap: () {
              Navigator.pop(sheetContext);
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.c.surfaceRaised,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => EditDosageForm(dosage: dosage),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.c.caution),
            title: Text('Delete', style: TextStyle(color: context.c.caution)),
            onTap: () => showDialog<void>(
              context: sheetContext,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: dialogContext.c.surfaceRaised,
                title: const Text('Delete Dose'),
                content:
                    const Text('Are you sure you want to delete this dose?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await context
                          .read<KratomProvider>()
                          .deleteDosage(dosage.id);
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dose deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text(
                      'Delete',
                      style: TextStyle(color: context.c.caution),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _logAgain(BuildContext context, Dosage dosage) async {
  final provider = context.read<KratomProvider>();
  final strain = provider.getStrain(dosage.strainId);
  await provider.addDosage(
    dosage.strainId,
    dosage.amount,
    DateTime.now(),
  );
  await HapticFeedback.lightImpact();
  if (!context.mounted) return;
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        strain == null
            ? 'Dose logged'
            : 'Logged ${dosage.amount}g ${strain.code}',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
