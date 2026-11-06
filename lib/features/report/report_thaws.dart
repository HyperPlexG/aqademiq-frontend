import '../../data/models/weekly_report.dart';
import '../freeze/domain/freeze_models.dart';

/// "When you thawed" — App freeze's thaws, laid on the report's own week.
///
/// The thaw history never leaves the phone (App freeze is device-local by
/// design), so this is the one beat the server cannot fill: the report's days
/// come from `GET /v1/weekly-report`, the thaws from `FreezeData.thawLog`, and
/// the two meet here, on the calendar day each thaw happened.
///
/// Pure, so the rule is tested rather than eyeballed:
///
///  * One count per [ReportDay], in the report's order (Monday first). The
///    week is the report's, not "the last seven days" — a Thursday report
///    counts Monday to Thursday, and Friday's slot is simply empty.
///  * A thaw is a record with `minutes > 0`. "Thaw everything" writes a
///    zero-minute record, and it is a stand-down, not a thaw.
///  * The log keeps about 15 days, which always covers the current week.
List<int> thawsByDay(List<ReportDay> days, List<ThawRecord> log) => [
      for (final d in days)
        log.where((r) => r.minutes > 0 && _sameDay(r.at.toLocal(), d.date)).length,
    ];

/// The beat renders only when App freeze is set up and the week holds at least
/// one thaw. Otherwise it is absent — never a row of empty days, which would
/// read as a count of zero.
bool showThawedBeat({required bool freezeSetUp, required List<int> thaws}) =>
    freezeSetUp && thaws.any((n) => n > 0);

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
