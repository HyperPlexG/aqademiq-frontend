import 'package:flutter/widgets.dart';

/// The shipped mood ramp — five steps, low to high.
///
/// These exact five colors were already duplicated verbatim in four screens
/// (morning check-in, evening check-in, onboarding, and the log-mood sheet).
/// The weekly report would have been the fifth copy, and the report is the one
/// place where the ramp drifting from the check-in screens would be actively
/// misleading: the whole core is read by comparing a band's tint to the colour
/// the student remembers tapping.
abstract final class AppMood {
  /// Index 0 (lowest) to 4 (highest), matching the 0-4 wire `mood_index`.
  static const List<Color> ramp = [
    Color(0xFFA79FC4),
    Color(0xFF9286D2),
    Color(0xFF7D70D9),
    Color(0xFF6A5CE4),
    Color(0xFF5A44F1),
  ];

  /// The tint for a logged mood, or null when there is nothing to tint with.
  ///
  /// Null is the important return. A day with no mood is drawn as an *empty*
  /// band, never as the low end of the ramp — the difference between "nothing
  /// logged" and "a bad day" is the single easiest thing for a weekly report to
  /// get wrong about someone.
  static Color? tint(int? moodIndex) {
    if (moodIndex == null) return null;
    if (moodIndex < 0 || moodIndex >= ramp.length) return null;
    return ramp[moodIndex];
  }
}
