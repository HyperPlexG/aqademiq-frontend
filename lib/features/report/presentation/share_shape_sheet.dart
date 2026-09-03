import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/weekly_report.dart';
import '../report_copy.dart';
import 'widgets/core_column.dart';

/// "Share the shape" — the activity shape of the week, and nothing else.
///
/// **Mood never leaves in a picture.** Mood is health data. Nothing exported
/// here may encode a mood value, tint, word, or anything derived from one,
/// including an archetype computed from mood. So the preview is built from a
/// copy of the week with every `moodIndex` stripped to null: the bands keep
/// their filled-or-open state — which is activity — and lose their colour.
///
/// Stripping the data rather than the drawing is deliberate. A share card that
/// merely *chose* not to paint the tint would still be one styling change away
/// from leaking it; one built from data that no longer contains a mood cannot
/// leak what it does not have.
Future<void> showShareShapeSheet(BuildContext context, WeeklyReport report) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => _ShareShapeScreen(report: report)),
  );
}

/// The week with mood removed. Activity shape survives; feeling does not.
WeeklyReport shapeOnly(WeeklyReport r) => WeeklyReport(
      weekStart: r.weekStart,
      weekEnd: r.weekEnd,
      shape: r.shape,
      activeDays: r.activeDays,
      elapsedDays: r.elapsedDays,
      daysOnBoard: r.daysOnBoard,
      days: [
        for (final d in r.days)
          ReportDay(
            date: d.date,
            weekday: d.weekday,
            hasActivity: d.hasActivity,
            // Preserved: a day that has not happened must not become an open
            // band on a card someone sends to their friends.
            isFuture: d.isFuture,
            tasksCompleted: d.tasksCompleted,
            focusMinutes: d.focusMinutes,
            focusSessions: d.focusSessions,
          ),
      ],
    );

class _ShareShapeScreen extends StatelessWidget {
  const _ShareShapeScreen({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stripped = shapeOnly(report);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.text),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ReportCopy.shareLabel,
                    style: AppText.sans(size: 21, weight: FontWeight.w800, letterSpacing: -0.4, color: colors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The card as it will be sent.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                      decoration: BoxDecoration(
                        color: colors.hilite,
                        borderRadius: BorderRadius.circular(AppRadius.group),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CoreColumn(days: stripped.days, height: 250, width: 96, animate: false),
                          const SizedBox(width: 26),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${report.activeDays}',
                                style: AppText.numeral(size: 62, weight: FontWeight.w500, color: colors.text),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ReportCopy.heroLabel,
                                style: AppText.sans(
                                  size: 9,
                                  weight: FontWeight.w800,
                                  height: 1.4,
                                  letterSpacing: AppText.em(0.14, 9),
                                  color: colors.textMed,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                ReportCopy.shareBrand,
                                style: AppText.sans(size: 13, weight: FontWeight.w800, color: colors.accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: colors.textMed),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ReportCopy.sharePrivacy,
                            style: AppText.sans(size: 12.5, height: 1.45, color: colors.textMed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.ink,
                          foregroundColor: colors.bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                        ),
                        onPressed: () => unawaited(_share(context, report)),
                        child: Text(
                          ReportCopy.shareAction,
                          style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.bg),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Text-only for now, and the text is held to the same rule as the image:
  /// a count of days and nothing about how the week felt.
  Future<void> _share(BuildContext context, WeeklyReport r) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: '${r.activeDays} days on the board. — ${ReportCopy.shareBrand}',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}
