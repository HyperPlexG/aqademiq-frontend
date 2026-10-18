import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import 'app_bottom_sheet.dart' show AppScrim;
import 'primary_button.dart';

/// Presents a centered [AppDialog] over the dimmed real screen (prototype
/// `CenterDialog`, scrim 0.40).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: AppScrim.dialog,
    builder: (_) => AppDialog(title: title, subtitle: subtitle, child: child),
  );
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.width = 226,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sheetTop),
            boxShadow: const [
              BoxShadow(color: Color(0x57000000), blurRadius: 64, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.sans(size: 19, weight: FontWeight.w800, color: colors.text),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
                      child: Text('✕', style: TextStyle(fontSize: 12, color: colors.textMed, height: 1)),
                    ),
                  ),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle!,
                    style: AppText.sans(size: 11, color: colors.textMed),
                  ),
                ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A destructive/confirm action button row for dialogs.
class DialogConfirmButton extends StatelessWidget {
  const DialogConfirmButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PrimaryButton(label: label, onPressed: onPressed),
    );
  }
}

/// Asks before something that cannot be taken back, and returns true only when
/// the user confirms. Closing the dialog any other way is a no.
///
/// [message] should say what actually happens — what goes and what stays —
/// rather than only warn. Names the thing too: "Delete task?" alone does not
/// say which row is about to go.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final ok = await showAppDialog<bool>(
    context,
    title: title,
    subtitle: message,
    // The dialog's own context: the caller's may sit under a nested navigator,
    // and popping that would close the screen behind instead of the dialog.
    child: Builder(
      builder: (dialog) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogConfirmButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(
              cancelLabel,
              style: AppText.sans(size: 13, color: dialog.colors.textMed),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
