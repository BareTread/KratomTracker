import 'dart:async';

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
            onTap: () => logDoseNow(
              sheetContext,
              strainId: dosage.strainId,
              amount: dosage.amount,
              sheetNavigator: Navigator.of(sheetContext),
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
      margin: _fabClearMargin,
      elevation: 0,
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

/// One-tap re-log shared by "Log again now" and the FAB's repeat pill.
/// [context] must stay mounted through the await: the sheet's own context for
/// "Log again now" (the row that opened the sheet can unmount mid-write when
/// the day page re-keys at midnight), the home screen's for the repeat pill.
/// [sheetNavigator] pops the options sheet after a successful write; null for
/// callers with nothing to dismiss. Capturing these BEFORE the await is the
/// guard: a write that already succeeded must still close the sheet and
/// confirm, and a second tap must not log a duplicate.
Future<void> logDoseNow(
  BuildContext context, {
  required String strainId,
  required double amount,
  NavigatorState? sheetNavigator,
}) async {
  if (_isLoggingAgain) return;
  _isLoggingAgain = true;
  try {
    final provider = context.read<KratomProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final strain = provider.getStrain(strainId);
    if (strain == null) {
      sheetNavigator?.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not log — this strain no longer exists'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final Dosage created;
    try {
      created = await provider.addDosage(
        strainId,
        amount,
        DateTime.now(),
      );
      // Fire-and-forget like every other haptic in the app: awaiting it
      // parks the write-confirm path on a platform channel that never
      // answers under flutter_test.
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not log dose: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    sheetNavigator?.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Logged ${strain.code} · ${_formatAmount(amount)}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: _fabClearMargin,
        elevation: 0,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await provider.deleteDosage(created.id);
            } on ArgumentError {
              // The dose is already gone — nothing to undo.
            }
          },
        ),
      ),
    );
  } finally {
    _isLoggingAgain = false;
  }
}

/// Matches the dose-row formatting in home_dosage_list.dart: up to two
/// decimals, trailing zeros stripped (16.6 → "16.6g", 2 → "2g").
String _formatAmount(double value) {
  final body = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
  return '${body}g';
}

/// The home FAB is a hand-positioned disc, not a Scaffold FAB, so Scaffold
/// never insets snackbars for it: a default floating bar's action button
/// lands dead under the disc. Right-margin clears the 56 px FAB plus its
/// 16 px screen edge and a small gap.
const _fabClearMargin = EdgeInsets.fromLTRB(16, 0, 88, 24);
