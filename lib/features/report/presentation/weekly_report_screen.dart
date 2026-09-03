import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/weekly_report.dart';
import '../../../data/repositories/weekly_report_repository.dart';
import '../report_copy.dart';
import 'share_shape_sheet.dart';
import 'widgets/report_beats.dart';

/// The weekly report — eight beats, story first and evidence second.
///
/// A pager rather than a scroll, and that is the design rather than a
/// preference. A dashboard puts everything on screen at once and asks the
/// reader to work out what it means; a sequence decides what they read first.
/// This one opens on one sentence about the *shape* of the week and shows a
/// single count only after it, which is the difference between a report that
/// describes a week and a report that grades one.
///
/// Everything after beat 3 is conditional: a beat with nothing true to say is
/// absent, and the page dots shrink with it. Nothing is greyed out and nothing
/// renders as a zero, because a greyed card still tells you that something was
/// supposed to be there and you did not do it.
///
/// What deliberately does not exist here:
///
///  * No date picker and no back-browsing. Scrolling through past weeks is a
///    rumination affordance, and the provider has no way to name another week.
///  * No percentage, rate, change, or `x of y` anywhere. Every number on this
///    screen is a count of things that happened.
///  * No account prompt. A guest's week is a real week, and "sign up to see
///    your full week" monetises a student's curiosity about themselves.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  final _pager = PageController();
  int _page = 0;
  bool _supportDismissed = false;

  /// The drilling beat holds for at least this long even if the request comes
  /// back sooner, so the core is seen forming rather than flashing.
  static const _minDrill = Duration(milliseconds: 1450);

  late final Future<void> _drilled = Future<void>.delayed(_minDrill);

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final async = ref.watch(weeklyReportProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: async.when(
          loading: () => _Shell(
            pageCount: 8,
            page: 0,
            onClose: () => _close(context),
            child: const BeatDrilling(),
          ),
          error: (_, _) => _Shell(
            pageCount: 1,
            page: 0,
            onClose: () => _close(context),
            child: _Failed(onRetry: () => ref.invalidate(weeklyReportProvider)),
          ),
          data: (report) => FutureBuilder<void>(
            future: _drilled,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return _Shell(
                  pageCount: 8,
                  page: 0,
                  onClose: () => _close(context),
                  child: BeatDrilling(days: report.days),
                );
              }
              return _story(context, report);
            },
          ),
        ),
      ),
    );
  }

  Widget _story(BuildContext context, WeeklyReport report) {
    final beats = _beatsFor(report);
    return _Shell(
      pageCount: beats.length,
      page: _page.clamp(0, beats.length - 1),
      onClose: () => _close(context),
      banner: _showSupport(report) && !_supportDismissed
          ? SupportBanner(
              onView: () => _close(context),
              onDismiss: () => setState(() => _supportDismissed = true),
            )
          : null,
      child: PageView(
        controller: _pager,
        onPageChanged: (i) => setState(() => _page = i),
        children: beats,
      ),
    );
  }

  /// Only the beats this week can honestly fill.
  List<Widget> _beatsFor(WeeklyReport r) {
    final subjectsById = {for (final s in r.subjects) s.id: s};
    final momentSubject = r.moment?.subjectId == null ? null : subjectsById[r.moment!.subjectId];

    final texture = <(String, String)>[
      if (r.longestSession != null) (ReportCopy.longestTitle, ReportCopy.longest(r.longestSession!)),
      if (r.heldMinutes > 0) (ReportCopy.heldTitle, ReportCopy.held(r.heldMinutes)),
      if (r.rhythmWeekdays.isNotEmpty) (ReportCopy.rhythmTitle, ReportCopy.rhythm(r.rhythmWeekdays)),
      if (r.prismMix.isNotEmpty)
        (ReportCopy.prismTitle, r.prismMix.map((m) => m.name).join(' · ')),
    ];

    return [
      BeatShape(shape: r.shape),
      BeatCore(report: r),
      if (r.moment != null)
        BeatMoment(
          moment: r.moment!,
          subjectName: momentSubject?.name,
          subjectColor: momentSubject?.colorHex,
        ),
      BeatNumeral(value: r.daysOnBoard),
      if (r.subjects.isNotEmpty) BeatAttention(report: r),
      if (r.recovery != null) BeatRecovery(recovery: r.recovery!),
      if (texture.isNotEmpty) BeatTexture(rows: texture),
      BeatLanding(
        isEmptyWeek: r.isEmpty,
        onKeep: () => _close(context),
        onShare: () => unawaited(showShareShapeSheet(context, r)),
        onDismiss: () => _close(context),
      ),
    ];
  }

  /// A run of empty weeks is a bad season, not a bad week. The banner is the
  /// only response: no escalation, no advice, and Ada stays out of it.
  ///
  /// Approximated from the current week alone for now — a week with nothing at
  /// all and no lifetime history behind it. The real rule needs several
  /// consecutive weeks, which needs history the report deliberately does not
  /// fetch, so this errs towards showing it rarely rather than often.
  bool _showSupport(WeeklyReport r) => r.isEmpty && r.daysOnBoard > 0;

  void _close(BuildContext context) => Navigator.of(context).maybePop();
}

/// Chrome shared by every state: the close affordance and the page dots.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.child,
    required this.pageCount,
    required this.page,
    required this.onClose,
    this.banner,
  });

  final Widget child;
  final int pageCount;
  final int page;
  final VoidCallback onClose;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
          child: Row(
            children: [
              // Leaving is one tap and always in the same place. A story you
              // have to finish is a story that can corner someone.
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, size: 24, color: colors.textMed),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
              Expanded(child: _Dots(count: pageCount, active: page)),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(child: child),
        ?banner,
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? colors.accent : colors.textDim.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
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
              style: AppText.sans(size: 14.5, height: 1.45, color: colors.text),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                ReportCopy.retry,
                style: AppText.sans(size: 13, weight: FontWeight.w700, color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
