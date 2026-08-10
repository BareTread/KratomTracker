import 'package:flutter/material.dart';
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

Future<void> showNotePopup(
  BuildContext context,
  String note,
  Color strainColor,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: dialogContext.c.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: strainColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.notes, color: strainColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Note',
                    style: TextStyle(
                      color: strainColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: dialogContext.c.hairline),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                note,
                style: TextStyle(
                  color: dialogContext.c.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Close', style: TextStyle(color: strainColor)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
