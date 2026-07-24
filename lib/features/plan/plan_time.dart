import '../../data/models/enums.dart';

/// Shared helpers for Plan time-of-day labels ("Anytime" / "Morning" / "2:30 PM").
///
/// The time picker returns display strings only; these helpers turn them into
/// [DayPart] + optional clock [DateTime] for create/update and draft handoff.
abstract final class PlanTime {
  PlanTime._();

  static String dayPartLabel(DayPart p) => switch (p) {
        DayPart.morning => 'Morning',
        DayPart.afternoon => 'Afternoon',
        DayPart.evening => 'Evening',
        DayPart.anytime => 'Anytime',
      };

  static DayPart dayPartForHour(int hour) {
    if (hour < 12) return DayPart.morning;
    if (hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }

  /// Parse a "Specific time" label like "2:30 PM" into a concrete [DateTime] on
  /// [date]. Returns null for named parts (Anytime / Morning / …).
  static DateTime? startTimeFromLabel(String label, DateTime date) {
    final m =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(label.trim());
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final isPm = m.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Resolve picker output into `(dayPart, startTime)`.
  ///
  /// Named buckets → `(DayPart, null)`. Clock strings → `(bucketFromHour, DateTime)`.
  static ({DayPart dayPart, DateTime? startTime}) resolve(
    String label,
    DateTime date,
  ) {
    final start = startTimeFromLabel(label, date);
    if (start != null) {
      return (dayPart: dayPartForHour(start.hour), startTime: start);
    }
    return (dayPart: DayPartX.fromWire(label.toLowerCase()), startTime: null);
  }
}
