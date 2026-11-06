import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../shared/icons/app_icon.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Opens the settings-rate sheet ("Rate Aqademiq") — the floating sheet over
/// the dimmed settings.
///
/// The real settings screen behind is dimmed by the barrier — do not rebuild it.
Future<void> showRateSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: 'Rate Aqademiq',
    child: const _RateBody(),
  );
}

class _RateBody extends ConsumerStatefulWidget {
  const _RateBody();

  @override
  ConsumerState<_RateBody> createState() => _RateBodyState();
}

class _RateBodyState extends ConsumerState<_RateBody> {
  int _rating = 0;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_rating < 1 || _submitting) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(settingsRepositoryProvider).submitRating(rating: _rating);
    } on Object {
      // Non-fatal — thank the user regardless of a transient write failure.
    }
    // Swiped away mid-request: popping now would close the screen underneath.
    if (mounted) navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks for the feedback! 💜')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasRating = _rating > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How has Aqademiq been treating you?',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.4, color: colors.textMed),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: 14),
              Semantics(
                button: true,
                selected: i <= _rating,
                label: '$i star${i == 1 ? '' : 's'}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _rating = i),
                  child: AppIcon(
                    i <= _rating ? Icons.star : Icons.star_outline,
                    size: 30,
                    color: i <= _rating ? colors.accent : const Color(0xFFC9C5BD),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: _submitting ? 'Submitting…' : 'Submit rating',
          enabled: hasRating && !_submitting,
          onPressed: () => unawaited(_submit()),
        ),
      ],
    );
  }
}
