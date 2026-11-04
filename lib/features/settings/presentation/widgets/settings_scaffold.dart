import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/icons/app_icon.dart';

/// Shared scaffold for full-screen settings routes: a `bg` page, a back button +
/// title header (compact, or `big` with a gear), and a scrollable body with
/// bottom clearance. (Settings is presented full-screen with a back button.)
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.big = false,
    this.gear = false,
  });

  final String title;
  final List<Widget> children;
  final bool big;
  final bool gear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: big
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SettingsBackButton(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (gear) ...[
                              AppIcon(Icons.settings, size: 25, color: colors.text),
                              const SizedBox(width: 9),
                            ],
                            Text(title, style: AppText.sans(size: 34, weight: FontWeight.w800, color: colors.text)),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const SettingsBackButton(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(size: 22, weight: FontWeight.w800, color: colors.text),
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 38px white circular back button (prototype `BackBtn`).
class SettingsBackButton extends StatelessWidget {
  const SettingsBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      // v11 BackBtn: 44, white, the card shadow, the pack's back glyph.
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle, boxShadow: colors.cardShadow),
        child: AppIcon(Icons.arrow_back, size: 24, color: colors.text),
      ),
    );
  }
}
