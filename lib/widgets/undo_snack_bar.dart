import 'package:flutter/material.dart';

/// How long a confirmation-with-Undo stays up. Long enough to reach the
/// button after noticing a mistake, short enough to get out of the way —
/// in line with Gmail/Photos-style undo bars.
const undoSnackBarDuration = Duration(seconds: 4);

/// Shows "[message] · Undo" and lets it time out on its own.
///
/// Flutter's SnackBar defaults `persist` to true whenever it has an action,
/// which leaves the bar on screen until it is tapped or swiped; `persist:
/// false` restores the timeout. Any bar already showing is replaced rather
/// than queued, so two quick logs don't leave a stale confirmation waiting
/// its turn.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: undoSnackBarDuration,
        persist: false,
        // Clears the FAB on the right.
        margin: const EdgeInsets.fromLTRB(16, 0, 88, 24),
        elevation: 0,
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
}
