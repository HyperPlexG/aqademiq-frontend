import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../widgets/settings_options.dart';

/// settings-gender sheet (spec §13a). Floats over the dimmed Profile screen and
/// returns the chosen label (or `null` on dismiss).
///
/// Options: Female, Male, Non-binary, "Prefer not to say" (selected when
/// [current] is unset).
Future<String?> showGenderSheet(BuildContext context, {String? current}) {
  return showAppBottomSheet<String>(
    context,
    title: 'Gender',
    child: _GenderOptions(current: current),
  );
}

class _GenderOptions extends StatelessWidget {
  const _GenderOptions({this.current});

  final String? current;

  static const _options = <String>[
    'Female',
    'Male',
    'Non-binary',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _options.contains(current) ? current : 'Prefer not to say';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final label in _options)
          SettingsOptionRow(
            label: label,
            selected: label == selected,
            onTap: () => Navigator.of(context).pop(label),
          ),
      ],
    );
  }
}
