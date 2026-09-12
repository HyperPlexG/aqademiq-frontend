import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../services/haptics/haptic_governor.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../services/sound_settings_service.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../focus/providers/prism_audio_provider.dart';
import '../providers/haptic_settings_provider.dart';
import '../providers/prism_settings_provider.dart';
import 'widgets/settings_scaffold.dart';

/// settings-sounds — Prism (Focus audio + in-app sounds).
class PrismSettingsScreen extends ConsumerStatefulWidget {
  const PrismSettingsScreen({super.key});

  @override
  ConsumerState<PrismSettingsScreen> createState() => _PrismSettingsScreenState();
}

class _PrismSettingsScreenState extends ConsumerState<PrismSettingsScreen> {
  late double _masterVolume;
  late double _environmentVolume;
  late double _systemVolume;
  bool _allInApp = true;
  bool _createTask = true;
  bool _completeTask = true;
  bool _taskCountdown = true;
  bool _completeSubtask = true;

  @override
  void initState() {
    super.initState();
    final settings = SoundSettingsService.instance;
    _masterVolume = settings.masterVolume;
    _environmentVolume = settings.environmentVolume;
    _systemVolume = settings.systemVolume;
  }

  Future<void> _pickDefaultMode() async {
    final current = ref.read(prismDefaultModeProvider);
    final picked = await showAppBottomSheet<String>(
      context,
      title: 'Default Prism mode',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mode in prismModes)
            _ModeOption(
              label: mode,
              selected: mode == current,
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
    if (picked != null) ref.read(prismDefaultModeProvider.notifier).set(picked);
  }

  /// Off / Essential / Full (spec §6.5), in the same sheet the default Prism
  /// mode uses.
  Future<void> _pickHapticLevel() async {
    final current = ref.read(hapticSettingProvider);
    final picked = await showAppBottomSheet<HapticSetting>(
      context,
      title: 'Haptics',
      subtitle: 'Aqademiq never overrides your phone’s own vibration and '
          'reduce-motion settings — this only makes it quieter.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final level in HapticSetting.values)
            _ModeOption(
              label: level.label,
              sub: level.description,
              selected: level == current,
              onTap: () => Navigator.of(context).pop(level),
            ),
        ],
      ),
    );
    if (picked != null) ref.read(hapticSettingProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final defaultMode = ref.watch(prismDefaultModeProvider);
    final autoplay = ref.watch(prismAutoplayProvider);
    final haptics = ref.watch(hapticSettingProvider);
    final audio = ref.read(prismAudioControllerProvider.notifier);
    return SettingsScaffold(
      title: 'Prism',
      children: [
        const GroupLabel('Prism focus audio'),
        SetGroup(
          children: [
            SettingsRow(
              label: 'Play Prism in Focus',
              toggle: autoplay,
              onToggle: (v) => ref.read(prismAutoplayProvider.notifier).set(v),
            ),
            SettingsRow(
              label: 'Default mode',
              value: defaultMode,
              showChevron: true,
              last: true,
              onTap: _pickDefaultMode,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Prism volumes'),
        SetGroup(
          children: [
            _VolumeRow(
              label: 'Master',
              value: _masterVolume,
              onChanged: (v) {
                setState(() => _masterVolume = v);
                unawaited(audio.setMasterVolume(v));
              },
            ),
            _VolumeRow(
              label: 'Environment',
              sub: 'Rain, sea, ambience',
              value: _environmentVolume,
              onChanged: (v) {
                setState(() => _environmentVolume = v);
                unawaited(audio.setEnvironmentVolume(v));
              },
            ),
            _VolumeRow(
              label: 'Rhythm',
              sub: 'Pulse beats',
              value: _systemVolume,
              last: true,
              onChanged: (v) {
                setState(() => _systemVolume = v);
                unawaited(audio.setSystemVolume(v));
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Haptics'),
        SetGroup(
          children: [
            SettingsRow(
              label: 'Vibration',
              sub: 'Follows your phone’s accessibility settings.',
              value: haptics.label,
              showChevron: true,
              last: true,
              onTap: () => unawaited(_pickHapticLevel()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('In-app sounds'),
        SetGroup(
          children: [
            SettingsRow(
              label: 'All in-app sounds',
              toggle: _allInApp,
              onToggle: (v) => setState(() => _allInApp = v),
            ),
            SettingsRow(
              label: 'Create task',
              toggle: _createTask,
              onToggle: (v) => setState(() => _createTask = v),
            ),
            SettingsRow(
              label: 'Complete task',
              toggle: _completeTask,
              onToggle: (v) => setState(() => _completeTask = v),
            ),
            SettingsRow(
              label: 'Task countdown',
              toggle: _taskCountdown,
              onToggle: (v) => setState(() => _taskCountdown = v),
            ),
            SettingsRow(
              label: 'Complete a subtask item',
              toggle: _completeSubtask,
              onToggle: (v) => setState(() => _completeSubtask = v),
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// A [SetGroup] row holding a Prism volume slider (matches [SettingsRow]
/// metrics: 12/15 padding, bottom border unless [last]).
class _VolumeRow extends ConsumerWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.sub,
    this.last = false,
  });

  /// The volume sliders are continuous, so "detent" has to be invented: quantise
  /// the 0–1 travel into twenty stops and tick only when one is crossed
  /// (spec §4.4 — "a slider crossing sixty values must not tick sixty times").
  static int _detent(double v) => (v * 20).round();

  final String label;
  final String? sub;
  final double value;
  final bool last;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.sans(size: 13.5, height: 1.3, color: colors.text)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub!,
                      style: AppText.sans(size: 11, height: 1.4, color: colors.textMed),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 132,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.accentSoft,
                thumbColor: colors.accent,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: (v) {
                  if (_detent(v) != _detent(value)) {
                    ref.read(hapticsProvider).sliderStop();
                  }
                  onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable row in the default-Prism-mode / haptics-level picker sheet.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.hilite,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(width: 1.5, color: selected ? colors.accent : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.sans(size: 13.5, weight: FontWeight.w700, color: selected ? colors.accent : colors.text)),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          sub!,
                          style: AppText.sans(size: 11, height: 1.4, color: colors.textMed),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_circle, size: 20, color: colors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
