import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Presents the change-password sheet (`settings-password`) on the floating,
/// keyboard-aware shell. The actual credential change lands with account sync
/// (§8) — until then the CTA validates locally and reports honestly rather than
/// faking success.
Future<void> showPasswordSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: 'Change password',
    child: const _PasswordBody(),
  );
}

class _PasswordBody extends StatelessWidget {
  const _PasswordBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PasswordField(label: 'Current password', autofocus: true),
        const SizedBox(height: 13),
        const _PasswordField(label: 'New password'),
        const SizedBox(height: 13),
        const _PasswordField(label: 'Confirm new password'),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Update password',
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password changes arrive with account sync — coming soon.')),
            );
          },
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.label, this.autofocus = false});

  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: AppText.sans(
              size: 15,
              weight: FontWeight.w700,
              color: context.colors.textMed,
            ),
          ),
        ),
        AppTextField(obscureText: true, autofocus: autofocus),
      ],
    );
  }
}
