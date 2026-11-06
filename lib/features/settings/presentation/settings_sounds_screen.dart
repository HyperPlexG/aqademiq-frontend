import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../services/sound_settings_service.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../focus/providers/prism_audio_provider.dart';
import '../providers/prism_settings_provider.dart';
import 'widgets/settings_options.dart';
import 'widgets/settings_scaffold.dart';

/// settings-sounds — Prism (Focus audio + in-app sounds), v11 SOUNDS_SETTING.
/// The volumes stay between the two groups; Haptics lives on the Settings
/// home now (settings-haptics), as v11 has it.
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
      child: Builder(
        builder: (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final mode in prismModes)
              SettingsOptionRow(
                label: mode,
                selected: mode == current,
                onTap: () => Navigator.of(sheet).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (picked != null) ref.read(prismDefaultModeProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final defaultMode = ref.watch(prismDefaultModeProvider);
    final autoplay = ref.watch(prismAutoplayProvider);
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
/// metrics: 17/15 text, 12/15 padding, an inset hairline unless [last]).
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
    // The inset hairline SettingsRow draws: from the text to the edge.
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      margin: const EdgeInsets.only(left: 15),
      padding: const EdgeInsets.fromLTRB(0, 12, 15, 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.sans(size: 17, height: 1.3, color: colors.text)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub!,
                      style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.4, color: colors.textMed),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.accentSoft,
                thumbColor: colors.accent,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
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
