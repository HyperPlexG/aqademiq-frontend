import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../adapters/adapters.dart';
import '../models/weekly_report.dart';
import '../sources/weekly_report_source.dart';

class WeeklyReportRepository {
  WeeklyReportRepository(this._source);

  final WeeklyReportSource _source;

  Future<WeeklyReport> report({DateTime? inWeek}) async =>
      (await _source.report(inWeek: inWeek)).toModel();
}

final weeklyReportRepositoryProvider = Provider<WeeklyReportRepository>((ref) {
  final source = Env.useMocks
      ? MockWeeklyReportSource()
      : ApiWeeklyReportSource(ref.watch(dioProvider));
  return WeeklyReportRepository(source);
});

/// The current week's report.
///
/// Not family-keyed by week on purpose. §6 of the design forbids browsing back
/// through past weeks — scrolling through your worst weeks is a rumination
/// affordance, and for someone who has just climbed out of one it is worse than
/// that. A provider that cannot be asked for an arbitrary week is the cheapest
/// place to make that true, because a screen cannot request what it has no way
/// to name.
final weeklyReportProvider = FutureProvider<WeeklyReport>(
  (ref) => ref.watch(weeklyReportRepositoryProvider).report(),
);
