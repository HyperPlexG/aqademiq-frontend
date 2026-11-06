import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_dialog.dart';

/// Opens the settings-delete confirm dialog ("Delete account?") — the v11
/// alert: a 22 title, the 17 consequence, and Cancel / Delete text actions.
///
/// Returns `true` when the user confirms deletion, `false` on cancel,
/// and `null` if dismissed by tapping the barrier.
///
/// The real settings screen behind is dimmed by the barrier — do not rebuild it.
Future<bool?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0x6B140F1C),
    builder: (_) => const AppAlert(
      title: 'Delete account?',
      message: 'This permanently removes your profile and data. There is no undo.',
      confirmLabel: 'Delete',
      width: 212,
    ),
  );
}
