import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/mood_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/mood_blob.dart';
import '../../../shared/widgets/primary_button.dart';

/// Frame `mood-morning` — full-screen morning check-in. Morphs the Ada ice-cube
/// blob across the 5-step MOODS scale, logs the chosen mood, then jumps to the
/// Timeline home ("Start day").
class MoodMorningScreen extends ConsumerStatefulWidget {
  const MoodMorningScreen({super.key});

  @override
  ConsumerState<MoodMorningScreen> createState() => _MoodMorningScreenState();
}

class _MoodMorningScreenState extends ConsumerState<MoodMorningScreen> {
  /// MOODS ramp colors (idx 0→4): Rough → Great (v11 `MOODS`).
  static const List<Color> _moodColors = MoodScale.colors;

  int _selectedMood = 3;

  /// The save is a network call; a second tap while it is in flight would log
  /// the morning twice.
  bool _saving = false;

  /// Tier 3 — and one of the two exceptions where a haptic belongs to a widget
  /// rather than a controller, because the detent *is* the interaction
  /// (spec §6.3).
  ///
  /// Fires on an actual move, never on re-tapping the position already
  /// selected, and passes the index so the tick can follow the melt ramp:
  /// softer at "Rough", sharper at "Great" (§5.1).
  void _selectMood(int idx) {
    if (idx != _selectedMood) ref.read(hapticsProvider).moodRampStep(idx);
    setState(() => _selectedMood = idx);
  }

  Future<void> _setIntention() async {
    if (_saving) return;
    _saving = true;
    try {
      await ref.read(moodRepositoryProvider).log(
            date: AppDate.today(),
            phase: MoodPhase.morning,
            mood: _selectedMood,
          );
    } on Object {
      _saving = false;
      if (!mounted) return;
      ref.read(hapticsProvider).saveFailed();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save. Try again.")),
      );
      return;
    }
    if (!mounted) return;
    // On commit, distinct from the ramp detents that preceded it.
    ref.read(hapticsProvider).moodLogged();
    ref.invalidate(moodWeekProvider);
    context.go(Routes.plan);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final moodColor = _moodColors[_selectedMood];

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        // Scrolls only when it has to (a 320×568 phone, or large text);
        // otherwise the Spacer still pins the button to the bottom as drawn.
        // The padding sits inside the scroll view so Skip's overhang into the
        // corner stays on screen and tappable.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                  child: Column(
                    children: [
                      // Skip: 15/600 in a 44 target, its padding hanging into the corner.
                      Align(
                        alignment: Alignment.centerRight,
                        child: Transform.translate(
                          offset: const Offset(10, 0),
                          child: _SkipButton(onTap: () => context.go(Routes.plan)),
                        ),
                      ),
                      Text(
                        'Morning\ncheck-in',
                        textAlign: TextAlign.center,
                        style: AppText.sans(
                          size: 34,
                          weight: FontWeight.w800,
                          height: 1.2,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How are you feeling today?',
                        textAlign: TextAlign.center,
                        style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
                      ),
                      const SizedBox(height: 14),
                      MoodBlob(idx: _selectedMood, size: 84),
                      const SizedBox(height: 6),
                      Text(
                        MoodScale.labels[_selectedMood],
                        style: AppText.sans(
                          size: 17,
                          weight: FontWeight.w800,
                          color: moodColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MoodSlider(
                        selectedMood: _selectedMood,
                        moodColors: _moodColors,
                        onSelect: _selectMood,
                      ),
                      const SizedBox(height: 6),
                      const _AdaTipCard(),
                      const SizedBox(height: 14),
                      const Spacer(),
                      PrimaryButton(
                        label: "Set today's intention →",
                        onPressed: () => unawaited(_setIntention()),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 5-step mood slider (v11 `MOOD_CHECKIN`): dot nodes connected by bars.
/// Bars at/left of the selected node take its colour at 45%; the selected node
/// is enlarged and ringed. Every node is laid out the same height, so the bars
/// meet the circles at their centres whichever node is chosen.
class _MoodSlider extends StatelessWidget {
  const _MoodSlider({
    required this.selectedMood,
    required this.moodColors,
    required this.onSelect,
  });

  final int selectedMood;
  final List<Color> moodColors;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: (_MoodNode.track - 4) / 2),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= selectedMood ? moodColors[selectedMood].withAlpha(115) : colors.bg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            _MoodNode(
              idx: i,
              selected: i == selectedMood,
              color: moodColors[i],
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single mood node: the outer ring + inner dot, and its 12/700 label
/// centred beneath (free to be wider than the node).
class _MoodNode extends StatelessWidget {
  const _MoodNode({
    required this.idx,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  /// The height every node's circle is centred in — the selected node's 34.
  static const double track = 34;

  final int idx;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outer = selected ? 34.0 : 24.0;
    final inner = selected ? 13.0 : 8.0;

    return Semantics(
      button: true,
      selected: selected,
      label: MoodScale.labels[idx],
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: outer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: track,
                child: Center(
                  child: Container(
                    width: outer,
                    height: outer,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? color.withAlpha(0x22) : colors.surface,
                      border: Border.all(
                        color: selected ? color : colors.border,
                        width: selected ? 2.5 : 2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withAlpha(0x40),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Container(
                        width: inner,
                        height: inner,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withAlpha(selected ? 0xFF : 115),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: 16,
                child: OverflowBox(
                  maxWidth: 80,
                  child: Text(
                    MoodScale.labels[idx],
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      height: 1.2,
                      color: selected ? color : colors.textDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ada's encouraging tip card (accent-soft fill, no shadow): mascot + a line of
/// copy tied to the pre-selected "Good" day.
class _AdaTipCard extends StatelessWidget {
  const _AdaTipCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdaMascot(size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nice! On "Good" days you average 2.4 hrs of deep focus. '
              "I've scheduled your hardest task for 2 PM.",
              style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.6, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Skip" — 15/600 dim, in a 44-high target.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              child: Text('Skip', style: AppText.sans(size: 15, color: context.colors.textDim)),
            ),
          ),
        ),
      ),
    );
  }
}
