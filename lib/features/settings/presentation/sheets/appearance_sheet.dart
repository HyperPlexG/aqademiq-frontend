import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../widgets/settings_options.dart';

/// FRAMES `settings-appearance` — Light / Dark / System picker, wired to the live
/// theme (`themeModeProvider`), in the floating sheet.
Future<void> showAppearanceSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: 'Appearance',
    child: const _AppearanceOptions(),
  );
}

class _AppearanceOptions extends ConsumerWidget {
  const _AppearanceOptions();

  static const List<(ThemeMode, String, String, String)> _options = [
    (ThemeMode.light, 'light_mode', 'Light', 'Always bright'),
    (ThemeMode.dark, 'dark_mode', 'Dark', 'Easy on the eyes'),
    (ThemeMode.system, 'brightness_auto', 'System', 'Match your device'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in _options) ...[
          SettingsOptionCard(
            icon: o.$2,
            label: o.$3,
            sub: o.$4,
            selected: mode == o.$1,
            onTap: () {
              ref.read(themeModeProvider.notifier).set(o.$1);
              Navigator.of(context).pop();
            },
          ),
          if (o.$1 != ThemeMode.system) const SizedBox(height: 9),
        ],
      ],
    );
  }
}
