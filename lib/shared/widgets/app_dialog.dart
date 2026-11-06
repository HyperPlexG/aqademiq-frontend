import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'app_bottom_sheet.dart' show AppScrim;
import 'ic.dart';
import 'primary_button.dart';

/// Presents a centered [AppDialog] over the dimmed real screen (v11
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

/// The v11 `CenterDialog`: 252 wide, radius 24, a 22/800 title with the quiet
/// ✕ beside it, an optional 15 sub-line, then the content.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.width = 252,
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
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x57000000), blurRadius: 64, offset: Offset(0, 20)),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      // Clear of the ✕ (20 glyph + 12 gap).
                      padding: const EdgeInsets.only(right: 32),
                      child: Text(
                        title,
                        style: AppText.sans(size: 22, weight: FontWeight.w800, height: 1.25, color: colors.text),
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle!,
                          style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.textMed),
                        ),
                      ),
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              ),
              // BarDismiss `tight`: a bare 20 glyph in a 44 target that
              // overhangs the title line and bleeds 12 past the content edge,
              // so the row is no taller than the title.
              Positioned(
                top: 7,
                right: 6,
                child: Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    key: const Key('app-dialog-close'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(child: Ic('close', size: 20, color: colors.textMed)),
                    ),
                  ),
                ),
              ),
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

/// The v11 alert (`DELETE_ACCOUNT_DIALOG`): a 22/800 title, a 17 message, and
/// two quiet text actions on the right — Cancel muted, the confirm in the
/// danger red when it cannot be taken back. Pops `false` / `true`.
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.danger = true,
    this.width = 252,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x57000000), blurRadius: 64, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.sans(size: 22, weight: FontWeight.w800, height: 1.25, color: colors.text),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.5, color: colors.textMed),
              ),
              const SizedBox(height: 3),
              // The 44 targets bleed past the padding, as the design's
              // `margin: -13px -8px -13px 0` does. Labels too long to sit side
              // by side wrap onto their own line rather than truncate.
              Transform.translate(
                offset: const Offset(8, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      _AlertAction(
                        label: cancelLabel,
                        color: colors.textMed,
                        weight: FontWeight.w700,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      _AlertAction(
                        label: confirmLabel,
                        color: danger ? colors.danger : colors.accent,
                        weight: FontWeight.w800,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertAction extends StatelessWidget {
  const _AlertAction({required this.label, required this.color, required this.weight, required this.onTap});

  final String label;
  final Color color;
  final FontWeight weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Sized to its label (widthFactor 1), so the Wrap can keep the two
        // side by side.
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.end,
                style: AppText.sans(size: 17, weight: weight, color: color),
              ),
            ),
          ),
        ),
      ),
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
  // The alert pops with its own context: the caller's may sit under a nested
  // navigator, and popping that would close the screen behind instead.
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: AppScrim.dialog,
    builder: (_) => AppAlert(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return ok == true;
}
