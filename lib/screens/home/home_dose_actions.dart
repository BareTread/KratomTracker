import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_dosage_form.dart';

bool _isLoggingAgain = false;

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
            onTap: () => _deleteWithUndo(context, sheetContext, dosage),
          ),
        ],
      ),
    ),
  );
}

/// Delete in one tap — the snackbar's Undo action is the safety net, so a
/// wrong-row delete costs one tap back instead of a confirm dialog on every
/// delete. Undo re-adds the dose at its original timestamp; the new record
/// gets a fresh ID, which nothing keys on.
Future<void> _deleteWithUndo(
  BuildContext context,
  BuildContext sheetContext,
  Dosage dosage,
) async {
  final provider = context.read<KratomProvider>();
  // Capture the messenger while the row context is definitely alive: the
  // undo callback can fire after the page beneath has been swiped away.
  final messenger = ScaffoldMessenger.of(context);
  await provider.deleteDosage(dosage.id);
  if (!sheetContext.mounted) return;
  Navigator.pop(sheetContext);
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Dose deleted'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await provider.addDosage(
              dosage.strainId,
              dosage.amount,
              dosage.timestamp,
              notes: dosage.notes,
            );
          } on ArgumentError {
            // The strain was deleted too while the bar was up; a dose
            // cannot come back without it.
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Could not undo — strain no longer exists'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    ),
  );
}

Future<void> _logAgain(BuildContext context, Dosage dosage) async {
  if (_isLoggingAgain) return;
  _isLoggingAgain = true;
  try {
    final provider = context.read<KratomProvider>();
    final strain = provider.getStrain(dosage.strainId);
    if (strain == null) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log — this strain no longer exists'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await provider.addDosage(
        dosage.strainId,
        dosage.amount,
        DateTime.now(),
      );
      await HapticFeedback.lightImpact();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not log dose: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged ${dosage.amount}g ${strain.code}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } finally {
    _isLoggingAgain = false;
  }
}
