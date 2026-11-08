import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/haptics/haptics_service.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/hold_to_confirm.dart';

/// Opens the settings-delete confirm dialog ("Delete account?") — the v11
/// alert: a 22 title, the 17 consequence, then a 2-second "Hold to delete"
/// and a Cancel action (haptics §4: a ratchet over the hold, then a knock).
///
/// Returns `true` when the hold completes (or a screen reader activates it),
/// `false` on cancel, and `null` if dismissed by tapping the barrier.
///
/// The real settings screen behind is dimmed by the barrier — do not rebuild it.
Future<bool?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0x6B140F1C),
    builder: (dialog) => AppAlert.custom(
      title: 'Delete account?',
      message: 'This permanently removes your profile and data. There is no undo.',
      width: 212,
      confirm: HoldToConfirm(
        label: 'Hold to delete',
        duration: deleteAccountHoldTime,
        holdMoment: HapticMoment.deleteAccountHold,
        doneMoment: HapticMoment.deleteAccountDone,
        onConfirmed: () => Navigator.of(dialog).pop(true),
        fill: dialog.colors.danger,
        height: 44,
      ),
    ),
  );
}
