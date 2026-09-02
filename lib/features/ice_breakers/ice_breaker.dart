import 'package:meta/meta.dart';

/// One tutorial in the Ice Breakers series.
///
/// The series answers the question a brand-new student is actually asking when
/// they land on an empty planner: *what am I supposed to do here?* Six videos,
/// in an order that walks from blank page to finished task — the sequence
/// matters more than any individual one.
@immutable
class IceBreaker {
  const IceBreaker({
    required this.id,
    required this.number,
    required this.title,
    required this.where,
    required this.seconds,
    required this.blurb,
    required this.asset,
  });

  /// Stable slug, used in the route (`/ice-breakers/:id`) and as the key the
  /// watched state is stored under. Never renumber these: a watched flag is
  /// keyed on the id, so changing one silently marks a video unwatched.
  final String id;

  /// `01`–`06`, shown before the title. Display only.
  final String number;

  final String title;

  /// Where in the app it happens — `Plan`, `Focus`, `Plan → Focus`. Shown small
  /// under the title so the student knows which surface they are about to see.
  final String where;

  /// Runtime badge, in seconds — the real length of the file, rounded.
  ///
  /// The design frames carried rounder guesses (45s, 40s) that overstated
  /// three of the six by roughly double. A runtime does more to earn a tap
  /// than any thumbnail could, which is exactly why it has to be true: a
  /// student who is already avoiding work and gets told 40s for a 17s clip
  /// learns not to believe the next number.
  ///
  /// Still a written constant rather than something read from the asset. The
  /// player would only know the duration after loading the video, and the
  /// label has to be on screen before anyone taps. Re-measure with ffprobe and
  /// update here whenever a video is recut.
  final int seconds;

  /// The one line naming the pain, in the student's own words.
  final String blurb;

  final String asset;

  String get runtime => '${seconds}s';
}

/// The shipped series, in teaching order.
///
/// Six is a curriculum; sixty is a library and reads as homework. The wider
/// curriculum exists, but only these six ship — and the whole point of the
/// feature is to fight the overwhelm an empty planner creates, so it must never
/// recreate that overwhelm in a new place.
const List<IceBreaker> kIceBreakers = [
  IceBreaker(
    id: 'add-one-small-thing',
    number: '01',
    title: 'Add One Small Thing',
    where: 'Plan',
    seconds: 25,
    blurb: 'The empty planner is the exact moment you close the tab. '
        'One task, and the white space breaks.',
    asset: 'assets/ice_breakers/01-add-one-small-thing.mp4',
  ),
  IceBreaker(
    id: 'too-big-break-it-down',
    number: '02',
    title: 'Too Big? Break It Down',
    where: 'Task',
    seconds: 23,
    blurb: '"Study for midterm" is not a task, it is a wall. '
        'Microtasks are the door through it.',
    asset: 'assets/ice_breakers/02-too-big-break-it-down.mp4',
  ),
  IceBreaker(
    id: 'five-minutes-not-twenty-five',
    number: '03',
    title: 'Five Minutes, Not Twenty-Five',
    where: 'Focus',
    seconds: 20,
    blurb: "Twenty-five minutes is a promise you'll break. "
        "Five isn't. Set the timer low on purpose.",
    asset: 'assets/ice_breakers/03-five-minutes-not-twenty-five.mp4',
  ),
  IceBreaker(
    id: 'freeze-dont-quit',
    number: '04',
    title: "Freeze, Don't Quit",
    where: 'Focus',
    seconds: 25,
    blurb: 'One interruption normally ends the session, and ending the '
        'session ends the day. Frost it instead.',
    asset: 'assets/ice_breakers/04-freeze-dont-quit.mp4',
  ),
  IceBreaker(
    id: 'push-it-to-tomorrow',
    number: '05',
    title: 'Push It To Tomorrow',
    where: 'Plan · reschedule',
    seconds: 21,
    blurb: "One task left undone shouldn't be enough to abandon the "
        'whole planner.',
    asset: 'assets/ice_breakers/05-push-it-to-tomorrow.mp4',
  ),
  IceBreaker(
    id: 'start-a-session-from-a-task',
    number: '06',
    title: 'Start A Session From A Task',
    where: 'Plan → Focus',
    seconds: 17,
    blurb: 'The gap between having a plan and actually starting is where '
        'the day dies.',
    asset: 'assets/ice_breakers/06-start-a-session-from-a-task.mp4',
  ),
];

/// Lookup by route id. Null for an unknown id — the router has no
/// `errorBuilder`, so the screen handles a bad deep link itself.
IceBreaker? iceBreakerById(String id) {
  for (final breaker in kIceBreakers) {
    if (breaker.id == id) return breaker;
  }
  return null;
}
