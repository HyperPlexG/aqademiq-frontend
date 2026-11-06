import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../freeze/domain/freeze_engine.dart';
import '../../freeze/presentation/sheets/frost_sheets.dart';
import '../../freeze/presentation/widgets/fz_widgets.dart';
import '../../freeze/providers/freeze_controller.dart';
import '../providers/onboarding_controller.dart';
import 'ob_source_screen.dart';
import 'widgets/onboarding_scaffold.dart';

/// ob-hours (and -custom, -all) — "When are your study hours?" Classes,
/// lectures or set study time. App freeze freezes distractions then, and the
/// days left over get Wellness time, frozen 9 AM to noon.
class ObHoursScreen extends ConsumerStatefulWidget {
  const ObHoursScreen({super.key});

  @override
  ConsumerState<ObHoursScreen> createState() => _ObHoursScreenState();
}

class _ObHoursScreenState extends ConsumerState<ObHoursScreen> {
  late Set<int> _days = ref.read(onboardingProvider).studyDays;
  late int _from = ref.read(onboardingProvider).studyFromMin;
  late int _until = ref.read(onboardingProvider).studyUntilMin;

  Future<void> _pick({required bool start}) async {
    final picked = await showFrostTimeDialog(
      context,
      title: start ? 'Starts at' : 'Ends at',
      sub: start ? 'Study hours freeze from here' : 'Study hours thaw here',
      minute: start ? _from : _until % 1440,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _from = picked;
      } else {
        // 12:00 AM as an end is the end of the day.
        _until = picked == 0 ? 1440 : picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rest = {1, 2, 3, 4, 5, 6, 7}.difference(_days);
    final weekdays = _days.length == 5 && _days.containsAll({1, 2, 3, 4, 5});
    final dayLabel = rest.isEmpty ? 'Every day' : (weekdays ? 'Weekdays' : FreezeText.days(_days));
    final wellness = rest.isEmpty
        ? 'Every day is a study day, so no Wellness time.'
        : '${FreezeText.daysProse(rest)} ${rest.length > 1 ? 'get' : 'gets'} Wellness time, frozen 9 AM to noon.';
    final valid = _days.isNotEmpty && _from != _until % 1440;

    return OnboardingScaffold(
      activeStep: 7,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('When are your\nstudy hours?', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 4),
          Text(
            "Classes, lectures or set study time. We'll freeze distractions then.",
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.6, color: colors.textMed),
          ),
          const SizedBox(height: 18),
          FzDayPicker(days: _days, label: dayLabel, onChanged: (d) => setState(() => _days = d)),
          const SizedBox(height: 8),
          FzWell(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Column(
              children: [
                FzTimeRow(label: 'From', first: true, value: FreezeText.time(_from), onTap: () => unawaited(_pick(start: true))),
                FzTimeRow(label: 'Until', value: FreezeText.time(_until), onTap: () => unawaited(_pick(start: false))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdaMascot(size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'App freeze blocks distracting apps during these hours. Thawing unblocks one when you really need it. $wellness',
                    style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.6, color: colors.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Continue →',
            enabled: valid,
            onPressed: () {
              ref.read(onboardingProvider.notifier).setStudyHours(days: _days, fromMin: _from, untilMin: _until);
              unawaited(context.push(Routes.obFreeze));
            },
          ),
          ObLink(
            label: "I don't have set hours",
            onTap: () {
              // No hours, no frosts to offer: App freeze can still be set up
              // later from Focus, so the freeze steps are skipped.
              ref.read(onboardingProvider.notifier).skipStudyHours();
              // Back here after the apps step: the frosts it made go too.
              ref.read(freezeControllerProvider.notifier).dropOnboardingFrosts();
              unawaited(context.push(Routes.obPrism));
            },
          ),
        ],
      ),
    );
  }
}
