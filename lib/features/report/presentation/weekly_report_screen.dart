import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/weekly_report.dart';
import '../../../data/repositories/weekly_report_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/share_sheet.dart';
import '../report_copy.dart';
import 'widgets/core_column.dart';

/// The weekly report — eight beats, story first and evidence second.
///
/// The order is the design. A dashboard opens with its numbers and asks the
/// reader to work out what they mean; this opens with one sentence about the
/// *shape* of the week, and only then shows a single count. Everything after
/// that is optional: a beat with nothing true to say is absent, never greyed
/// out and never shown as a zero, because a greyed card still tells you that
/// something was supposed to be there and you did not do it.
///
/// What deliberately does not exist here:
///
///  * No date picker and no back-browsing. Scrolling through past weeks is a
///    rumination affordance, and the provider has no way to name another week.
///  * No percentage, rate, change, or `x of y` anywhere. Every number on this
///    screen is a count of things that happened.
///  * No account prompt. A guest's week is a real week, and "sign up to see
///    your full week" monetises a student's curiosity about themselves.
class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(weeklyReportProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: async.when(
          loading: () => const _Freezing(),
          error: (_, _) => _Failed(onRetry: () => ref.invalidate(weeklyReportProvider)),
          data: (r) => _Report(report: r),
        ),
      ),
    );
  }
}

/// The core freezing in. Not a spinner: the same column the report opens with,
/// so the transition into the loaded state is continuous rather than a swap.
class _Freezing extends StatelessWidget {
  const _Freezing();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 74,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: colors.accent.withValues(alpha: 0.05),
                border: Border.all(color: colors.accent.withValues(alpha: 0.14)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(ReportCopy.drilling, style: AppText.sans(size: 11, color: colors.textMed)),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ReportCopy.loadFailed,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 14, height: 1.45, color: context.colors.text),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(ReportCopy.retry, style: AppText.sans(size: 12.5, weight: FontWeight.w700, color: colors.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final WeeklyReport report;

  static const _coreHeight = 296.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasGap = report.days.any((d) => !d.hasActivity);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      children: [
        _Header(report: report),
        const SizedBox(height: 26),

        // Beats 1-3 and 5: the core, the shape sentence, the one numeral.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreDayLabels(days: report.days, height: _coreHeight),
            const SizedBox(width: 10),
            CoreColumn(days: report.days, height: _coreHeight),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    ReportCopy.shape(report.shape),
                    style: AppText.sans(size: 17, weight: FontWeight.w700, height: 1.3, letterSpacing: -0.3, color: colors.text),
                  ),
                  const SizedBox(height: 22),
                  // Beat 5 — the one numeral. Playfair, alone, and a count of
                  // things that happened with nothing to divide it by.
                  Text('${report.daysOnBoard}', style: AppText.numeral(size: 52, color: colors.text)),
                  const SizedBox(height: 4),
                  Text(
                    ReportCopy.heroLabel,
                    style: AppText.sans(size: 8.5, weight: FontWeight.w800, letterSpacing: AppText.em(0.12, 8.5), color: colors.textDim),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasGap ? '${ReportCopy.coreCaption} ${ReportCopy.gapCaption}' : ReportCopy.coreCaption,
                    style: AppText.sans(size: 10.5, height: 1.5, color: colors.textMed),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),

        // Beat 4 — one concrete thing that happened.
        if (report.moment != null) ...[
          _MomentCard(moment: report.moment!),
          const SizedBox(height: 10),
        ],

        // Beat 6 — where attention went.
        if (report.subjects.isNotEmpty) ...[
          _AttentionCard(report: report),
          const SizedBox(height: 10),
        ],

        // Beat 7 — the recovery read. Present only when it points positive; the
        // server returns nothing rather than a number that points the other way.
        if (report.recovery != null) ...[
          _LineCard(label: ReportCopy.recoveryTitle, line: ReportCopy.recovery(report.recovery!)),
          const SizedBox(height: 10),
        ],

        if (report.longestSession != null) ...[
          _LineCard(label: ReportCopy.longestTitle, line: ReportCopy.longest(report.longestSession!)),
          const SizedBox(height: 10),
        ],

        if (report.heldMinutes > 0) ...[
          _LineCard(label: ReportCopy.heldTitle, line: ReportCopy.held(report.heldMinutes)),
          const SizedBox(height: 10),
        ],

        if (report.rhythmWeekdays.isNotEmpty) ...[
          _LineCard(label: ReportCopy.rhythmTitle, line: ReportCopy.rhythm(report.rhythmWeekdays)),
          const SizedBox(height: 10),
        ],

        if (report.prismMix.isNotEmpty) ...[
          _PrismCard(mix: report.prismMix),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 18),
        _Landing(report: report),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.report});
  final WeeklyReport report;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _range {
    final a = report.weekStart;
    final b = report.weekEnd;
    final left = '${_months[a.month - 1]} ${a.day}';
    final right = a.month == b.month ? '${b.day}' : '${_months[b.month - 1]} ${b.day}';
    return '$left – $right';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ReportCopy.coreTitle,
                style: AppText.sans(size: 9, weight: FontWeight.w800, letterSpacing: AppText.em(0.22, 9), color: colors.accent),
              ),
              const SizedBox(height: 6),
              Text(_range, style: AppText.sans(size: 20, weight: FontWeight.w800, letterSpacing: -0.4, color: colors.text)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});
  final ReportMoment moment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardLabel(ReportCopy.momentTitle),
          const SizedBox(height: 8),
          Text(
            ReportCopy.moment(moment),
            style: AppText.sans(size: 14.5, height: 1.4, color: colors.text),
          ),
        ],
      ),
    );
  }
}

/// Beat 6 — one cube per subject, melted by share.
///
/// A subject that got nothing this week is not in this list at all. It is never
/// named and never drawn as an empty row: a list of subjects you did not touch,
/// sitting under the heading "where attention went", is a list of things you
/// failed to do.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unattributed = report.unattributedShare;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardLabel(ReportCopy.attentionTitle),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.progress),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final s in report.subjects)
                    Expanded(
                      flex: (s.share * 1000).round().clamp(1, 1000),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: ColoredBox(color: _tint(s, colors)),
                      ),
                    ),
                  if (unattributed > 0.01)
                    Expanded(
                      flex: (unattributed * 1000).round().clamp(1, 1000),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.textDim.withValues(alpha: 0.6)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final s in report.subjects) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _tint(s, colors), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      // A subject deleted after the work happened keeps its
                      // share and loses its name — an unlabelled outline in the
                      // distribution, never invented copy.
                      s.name ?? ReportCopy.namelessSubject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 12.5, color: colors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    report.subjectBasis == SubjectBasis.focusMinutes
                        ? ReportCopy.minutes(s.focusMinutes)
                        : '${s.tasksCompleted}',
                    style: AppText.sans(size: 11.5, weight: FontWeight.w700, color: colors.textMed),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _tint(ReportSubject s, AppColors colors) {
    final hex = s.colorHex;
    if (hex == null || hex.isEmpty) return colors.accent;
    final cleaned = hex.replaceFirst('#', '');
    final v = int.tryParse(cleaned, radix: 16);
    if (v == null || cleaned.length != 6) return colors.accent;
    return Color(0xFF000000 | v);
  }
}

class _PrismCard extends StatelessWidget {
  const _PrismCard({required this.mix});
  final List<ReportPrismSlice> mix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardLabel(ReportCopy.prismTitle),
          const SizedBox(height: 12),
          // A thin ribbon — a taste, never a ranking and never tied to whether
          // the sessions under it finished.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.progress),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  for (var i = 0; i < mix.length; i++)
                    Expanded(
                      flex: (mix[i].share * 1000).round().clamp(1, 1000),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: ColoredBox(
                          color: colors.accent.withValues(alpha: 0.85 - i * 0.22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            mix.map((m) => m.name).join(' · '),
            style: AppText.sans(size: 11.5, color: colors.textMed),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.label, required this.line});
  final String label;
  final String line;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(label),
          const SizedBox(height: 7),
          Text(
            line,
            style: AppText.sans(size: 13.5, height: 1.4, color: context.colors.text),
          ),
        ],
      ),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.sans(
        size: 8.5,
        weight: FontWeight.w800,
        letterSpacing: AppText.em(0.14, 8.5),
        color: context.colors.textDim,
      ),
    );
  }
}

/// Beat 8 — the landing, and sharing beside it rather than as the finale.
class _Landing extends StatelessWidget {
  const _Landing({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.isEmpty ? ReportCopy.closingEmpty : ReportCopy.closing,
          style: AppText.sans(size: 13.5, height: 1.55, color: colors.textMed),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            GestureDetector(
              onTap: () => unawaited(showShareSheet(context)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: colors.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ios_share, size: 14, color: colors.text),
                    const SizedBox(width: 7),
                    Text(
                      ReportCopy.shareLabel,
                      style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Said plainly, because a student cannot check what the share card
        // contains and has to be able to take our word for it.
        Text(ReportCopy.shareNote, style: AppText.sans(size: 10.5, color: colors.textDim)),
      ],
    );
  }
}
