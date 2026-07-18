import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/mascot/ada_mascot.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Point-of-action sign-up gate for the feedback board. Voting, posting and
/// commenting require a real (non-guest) account — the backend returns `403`
/// for guests (FEEDBACK_BOARD_INTEGRATION.md §"Guest rule"). We gate these in
/// the UI and prompt sign-up here. [reason] completes "Create an account to …".
Future<void> showCreateAccountPrompt(
  BuildContext context, {
  required String reason,
}) {
  return showAppBottomSheet<void>(
    context,
    title: 'Create an account',
    subtitle: 'Create an account to $reason.',
    child: const _Body(),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AdaMascot(size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You're in guest mode. Create a free account to join the "
                'conversation — vote on ideas, post suggestions and reply.',
                style: AppText.sans(size: 11.5, height: 1.5, color: colors.textMed),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Create account →',
          onPressed: () {
            Navigator.of(context).pop();
            context.go(Routes.signup);
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Not now',
              style: AppText.sans(size: 11.5, color: colors.textMed),
            ),
          ),
        ),
      ],
    );
  }
}
