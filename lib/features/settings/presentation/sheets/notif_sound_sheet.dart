import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../widgets/settings_options.dart';

/// Presents the "Notification sound" sheet (`settings-notif-sound`) — a
/// floating sheet over the dimmed Notifications screen. Lists five sound
/// options as pill rows. Tapping an option pops with its label; returns `null`
/// on dismiss.
Future<String?> showNotifSoundSheet(BuildContext context, {String current = 'Chime'}) {
  return showAppBottomSheet<String>(
    context,
    title: 'Notification sound',
    child: _SoundOptions(current: current),
  );
}

const _sounds = <String>['Chime', 'Pulse', 'Glass', 'Drop', 'None'];

class _SoundOptions extends StatelessWidget {
  const _SoundOptions({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sound in _sounds)
          SettingsOptionRow(
            label: sound,
            selected: sound == current,
            onTap: () => Navigator.of(context).pop(sound),
          ),
      ],
    );
  }
}
