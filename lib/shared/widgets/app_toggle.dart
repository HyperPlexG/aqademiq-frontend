import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../services/haptics/haptics_service.dart';

/// iOS-style pill toggle (v11 `Toggle`): 51×31 track, 27×27 knob, accent
/// track when on, `textDim` when off.
///
/// A tap latches on and unlatches off (haptics §4, "Toggles"). It fires
/// before [onChanged], so a screen that plays its own moment for the same tap
/// (a frost day, an app row) wins the frame.
class AppToggle extends ConsumerWidget {
  const AppToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final onChanged = this.onChanged;
    return GestureDetector(
      onTap: onChanged == null
          ? null
          : () {
              ref.read(hapticsProvider).play(value ? HapticMoment.toggleOff : HapticMoment.toggleOn);
              onChanged(!value);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 51,
        height: 31,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? colors.accent : colors.textDim,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
