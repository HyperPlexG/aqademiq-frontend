/// The semantic → physical layer. **The only file in the app allowed to name a
/// physical haptic.**
///
/// Spec §6.2 / guide §1.2: widgets and controllers say `taskCompleted()`, never
/// `HapticFeedback.mediumImpact()`. The whole mapping lives here so retuning the
/// app's entire feel is a one-file diff and platform divergence resolves in one
/// place. This is the adapter-layer principle (README §7, seam 2) applied to
/// touch — the same reason DTOs never leak into widgets.
///
/// If you find yourself importing `package:flutter/services.dart` elsewhere to
/// fire a haptic, the answer is a new [HapticEvent], not a new call site.
///
/// ## Why this file no longer speaks in `HapticFeedback`
///
/// It used to resolve all 23 events onto Flutter's five fixed effects, which
/// take no parameters at all — no intensity, no duration, no pattern. Nine
/// events were the same `lightImpact`; five were the same `selectionClick`.
/// Every piece of design intent in the comments below ("ice cracking", "a lock
/// engaging", "the melted end") existed only as prose, because the API could
/// not express it.
///
/// Events are now described in intensity, sharpness and time, and
/// `haptic_driver.dart` renders that on Core Haptics (iOS) or a vibration
/// waveform (Android), falling back to the old five effects where neither
/// exists. Nothing above this file changed.
library;

import 'package:flutter/foundation.dart';

import 'haptic_driver.dart';

/// Which tier an event belongs to (spec §3).
///
/// The tier decides two things and nothing else:
///
///  * what the governor admits — "Essential" keeps only [earned] and [warning]
///    (spec §6.5);
///  * who wins a burst — declaration order **is** priority order, so a lower
///    [Enum.index] wins (guide §1.3 rule 5).
///
/// Priority follows the spec's own numbering, where Tier 1 is the highest tier.
/// That reads odd for [warning] until you notice a warning is mutually
/// exclusive with the success events it could collide with — a save either
/// succeeded or it did not — and that a detent fires on touch while a failure
/// arrives a network round trip later, never inside the same coalescing frame.
/// Do not promote [warning] without a failing case to point at.
enum HapticTier {
  /// Tier 1 — earned moments. Five, app-wide.
  earned,

  /// Tier 2 — state confirmations. The workhorse.
  confirmation,

  /// Tier 3 — selection detents. Continuous input, rate-limited hard (§4.4).
  detent,

  /// Tier 4 — warnings. Genuinely rare; if these fire often, something
  /// upstream is wrong.
  warning,
}

/// Every haptic the app is allowed to produce — spec §3, and no others without
/// review under §7.
///
/// Twenty-two. The count is the point: the repo has 170 `GestureDetector`s and
/// exactly these 22 interactions earned a haptic (spec §4.1). Adding a value
/// here is a spec change, not an implementation detail — §8.1 requires every
/// new event to name its tier *and* the specific state change it confirms.
enum HapticEvent {
  // ── Tier 1 — earned moments (5) ────────────────────────────────────────
  /// The signature moment of the product. Never fires for *un*-completing.
  taskCompleted(HapticTier.earned),

  /// Reached its end naturally — not ended early. The one true composite.
  focusCompleted(HapticTier.earned),

  /// Fires at the crossing, never on display (spec §4.5).
  streakMilestone(HapticTier.earned),

  /// The moment a guest's anxiety about losing their data resolves.
  guestUpgraded(HapticTier.earned),

  /// End of the 11-step wizard. The individual steps fire nothing (§4.6).
  onboardingFinished(HapticTier.earned),

  // ── Tier 2 — state confirmations (10) ──────────────────────────────────
  taskCreated(HapticTier.confirmation),

  /// Pushed to another day. Must never feel like a penalty.
  taskRescheduled(HapticTier.confirmation),

  /// Light single, then total silence until the session resolves (§4.2).
  focusStarted(HapticTier.confirmation),

  /// The product's most characteristic interaction — a lock engaging (§5.3).
  sessionFrozen(HapticTier.confirmation),

  /// The release of the freeze.
  sessionResumed(HapticTier.confirmation),

  /// The melted end (§5.2). Not punishing; simply not a reward.
  sessionEndedEarly(HapticTier.confirmation),

  /// On commit, distinct from the ramp detents that preceded it.
  moodLogged(HapticTier.confirmation),

  subjectCreated(HapticTier.confirmation),

  suggestionPosted(HapticTier.confirmation),

  /// Lighter still — it is a small commitment.
  voteCast(HapticTier.confirmation),

  // ── Tier 3 — selection detents (4) ─────────────────────────────────────
  /// Each of the five melt positions. Sharpens 0→4 (§5.1).
  moodRampStep(HapticTier.detent),

  /// Time picker, month picker. Restores the iOS expectation from Finding 03.
  wheelItem(HapticTier.detent),

  /// Focus duration, task duration, Prism volumes. On detent, never per pixel.
  sliderStop(HapticTier.detent),

  /// Faintest tick in the system. On change, never on re-tap of the active one.
  segmentChange(HapticTier.detent),

  /// The task-card long-press — spec Finding 04, and the one event here that is
  /// about **function** rather than feel: the tick is how a user learns the
  /// gesture exists and that it fired.
  ///
  /// The twenty-third value, and the one place this vocabulary knowingly
  /// departs from spec §3's "twenty-two events". §3's Tier 3 table lists four
  /// detents and does not include this, but §7's Plan budget spends one of
  /// Plan's four on a "long-press overflow detent" — so the spec counts it as a
  /// distinct type in one section and omits it from the other. Finding 04
  /// settles which way to resolve that. It is no longer physically identical to
  /// its neighbours: a sustained press needs a longer, duller pulse than a
  /// scroll tick to register at all (see [longPressPulse]).
  longPressTick(HapticTier.detent),

  // ── Tier 4 — warnings (3) ──────────────────────────────────────────────
  /// Delete task, subject, semester, account. Deliberately unpleasant.
  destructiveConfirmed(HapticTier.warning),

  /// Only what the user explicitly submitted. Never a background refetch.
  saveFailed(HapticTier.warning),

  /// 403 → prompt account. Soft: the user hit a wall, do not also slap them.
  guestWallHit(HapticTier.warning);

  const HapticEvent(this.tier);

  final HapticTier tier;
}

// ─── pulse floors ──────────────────────────────────────────────────────────
//
// These exist because a tap has no duration on iOS and very much does on
// Android, and getting that wrong is what made the old detents imperceptible.

/// How long a [HapticBeat.tap] lasts on Android.
///
/// Not a free parameter and not a stylistic choice. An LRA has to spin up
/// before anything is felt, so a ~20 ms one-shot is imperceptible on most
/// Android phones however high its amplitude — which is exactly why the old
/// `selectionClick` detents read as "nothing happened" on device. 50 ms is
/// where a tick becomes reliably felt.
///
/// It is bounded from above by `HapticGovernor.flingGap` (80 ms): during a
/// deliberate scroll, detents arrive roughly that far apart, so a pulse longer
/// than the gap would overlap the next one and smear a row of distinct ticks
/// into one continuous buzz. 50 ms leaves margin inside that bound.
///
/// Ignored on iOS, where Core Haptics transients have no duration at all and
/// perceived strength comes from intensity instead.
const Duration detentPulse = Duration(milliseconds: 50);

/// The long-press tick, which can afford to be longer than [detentPulse].
///
/// Nothing follows a long-press inside the fling window — it is a one-off
/// gesture, not a stream — so the smearing that caps a scroll detent does not
/// apply. A sustained press also needs more to register through it than a
/// fingertip brushing a wheel does.
const Duration longPressPulse = Duration(milliseconds: 90);

/// Confirmations are never rapid-fire, so they sit above the detent floor.
const Duration confirmPulse = Duration(milliseconds: 60);

/// Tier 1 beats, which want presence over crispness.
const Duration earnedPulse = Duration(milliseconds: 70);

// ─── the vocabulary ────────────────────────────────────────────────────────

/// Whether a beat is an impulse or a sustained buzz.
enum HapticShape {
  /// A single strike. On iOS a Core Haptics transient (no duration); on Android
  /// a pulse of [HapticBeat.androidPulse].
  tap,

  /// A held vibration of [HapticBeat.duration] — swells, decays, error buzzes.
  hold,
}

/// One beat of a pattern.
///
/// [intensity] is how hard (0–1) and [sharpness] is how crisp (0–1): low
/// sharpness is a dull thud, high is a click. Sharpness maps directly to Core
/// Haptics; Android has no equivalent, so it survives there only as the choice
/// between a short pulse and a long one.
@immutable
class HapticBeat {
  const HapticBeat.tap({
    required this.intensity,
    required this.sharpness,
    this.at = Duration.zero,
    this.androidPulse = detentPulse,
  })  : shape = HapticShape.tap,
        duration = Duration.zero;

  const HapticBeat.hold({
    required this.duration,
    required this.intensity,
    required this.sharpness,
    this.at = Duration.zero,
  })  : shape = HapticShape.hold,
        androidPulse = Duration.zero;

  final HapticShape shape;

  /// Offset from the start of the pattern.
  final Duration at;

  /// Length of a [HapticShape.hold]. Zero for a tap.
  final Duration duration;

  final double intensity;
  final double sharpness;

  /// What a [HapticShape.tap] becomes on a motor that can only be asked to
  /// vibrate for a length of time. See [detentPulse].
  final Duration androidPulse;

  /// When this beat is over, taking the Android pulse as the worst case so the
  /// governor's quiet window covers every platform.
  Duration get end =>
      at + (shape == HapticShape.hold ? duration : androidPulse);

  Map<String, Object> toWire() => {
        'shape': shape.name,
        'at': at.inMilliseconds,
        'ms': (shape == HapticShape.hold ? duration : androidPulse)
            .inMilliseconds,
        'intensity': intensity,
        'sharpness': sharpness,
      };
}

/// An ordered set of beats — what one [HapticEvent] feels like.
@immutable
class HapticPattern {
  const HapticPattern(this.beats);

  final List<HapticBeat> beats;

  /// How long the whole thing takes. The governor uses this to stay quiet until
  /// a pattern has finished, so a scroll tick cannot land inside a celebration.
  Duration get span {
    var longest = Duration.zero;
    for (final beat in beats) {
      if (beat.end > longest) longest = beat.end;
    }
    return longest;
  }

  List<Map<String, Object>> toWire() => [for (final b in beats) b.toWire()];
}

/// The melt ramp — five genuinely distinct steps (spec §5.1).
///
/// Softer and duller at "Rough" (0), stronger and crisper at "Great" (4), so
/// the physical metaphor and the emotional read agree. The old ramp collapsed
/// onto three impulse strengths and positions 0/1 and 2/3 were literally the
/// same vibration; this is the richness §5.1 asked for and the API could not
/// previously express.
///
/// The bottom of the ramp is 0.45 rather than something daintier because a
/// detent nobody can feel is not a gentler detent, it is a missing one.
const List<(double, double)> _moodRamp = [
  (0.45, 0.30), // 0 · Rough
  (0.52, 0.45), // 1 · Tired
  (0.60, 0.60), // 2 · OK
  (0.68, 0.78), // 3 · Good
  (0.78, 0.95), // 4 · Great
];

/// What [event] feels like.
///
/// A switch *expression*, so adding a [HapticEvent] without giving it a feel is
/// a compile error rather than a silent no-op.
///
/// [rampStep] is the 0–4 melt position and is read only for
/// [HapticEvent.moodRampStep].
HapticPattern patternFor(HapticEvent event, {int? rampStep}) =>
    switch (event) {
      // ── Tier 1 — earned ────────────────────────────────────────────────
      //
      // A genuine crack rather than a thud: the micro-tick 35 ms ahead of the
      // strike is what makes ice break instead of something merely landing.
      HapticEvent.taskCompleted => const HapticPattern([
          HapticBeat.tap(intensity: 0.30, sharpness: 1),
          HapticBeat.tap(
            at: Duration(milliseconds: 35),
            intensity: 0.85,
            sharpness: 0.9,
            androidPulse: earnedPulse,
          ),
        ]),
      // Three beats rising into warmth. The biggest moment in the app is the
      // only thing that feels like this, which is most of how it reads as big.
      HapticEvent.focusCompleted => const HapticPattern([
          HapticBeat.tap(intensity: 0.5, sharpness: 0.4, androidPulse: confirmPulse),
          HapticBeat.tap(
            at: Duration(milliseconds: 120),
            intensity: 0.7,
            sharpness: 0.6,
            androidPulse: confirmPulse,
          ),
          HapticBeat.hold(
            at: Duration(milliseconds: 240),
            duration: Duration(milliseconds: 180),
            intensity: 0.9,
            sharpness: 0.3,
          ),
        ]),
      // The only event with an anticipation phase: a swell, then arrival.
      HapticEvent.streakMilestone => const HapticPattern([
          HapticBeat.hold(
            duration: Duration(milliseconds: 250),
            intensity: 0.55,
            sharpness: 0.3,
          ),
          HapticBeat.tap(
            at: Duration(milliseconds: 260),
            intensity: 1,
            sharpness: 0.9,
            androidPulse: earnedPulse,
          ),
          HapticBeat.tap(
            at: Duration(milliseconds: 380),
            intensity: 1,
            sharpness: 0.9,
            androidPulse: earnedPulse,
          ),
        ]),
      // Relief, not triumph — a soft swell that settles rather than announces.
      HapticEvent.guestUpgraded => const HapticPattern([
          HapticBeat.hold(
            duration: Duration(milliseconds: 200),
            intensity: 0.5,
            sharpness: 0.2,
          ),
          HapticBeat.tap(
            at: Duration(milliseconds: 200),
            intensity: 0.7,
            sharpness: 0.5,
            androidPulse: earnedPulse,
          ),
        ]),
      // "Done, done, done" — the only payoff for eleven deliberately silent
      // wizard steps (§4.6), so it ascends instead of simply landing.
      HapticEvent.onboardingFinished => const HapticPattern([
          HapticBeat.tap(intensity: 0.4, sharpness: 0.3, androidPulse: confirmPulse),
          HapticBeat.tap(
            at: Duration(milliseconds: 110),
            intensity: 0.6,
            sharpness: 0.55,
            androidPulse: confirmPulse,
          ),
          HapticBeat.tap(
            at: Duration(milliseconds: 220),
            intensity: 0.9,
            sharpness: 0.8,
            androidPulse: earnedPulse,
          ),
        ]),

      // ── Tier 2 — confirmations ─────────────────────────────────────────
      //
      // §5.3 — the product's most characteristic interaction. A sharp click
      // falling straight into a short hold is a bolt sliding home; it was
      // previously a `mediumImpact`, i.e. indistinguishable from completing a
      // task.
      HapticEvent.sessionFrozen => const HapticPattern([
          HapticBeat.tap(intensity: 0.8, sharpness: 1, androidPulse: confirmPulse),
          HapticBeat.hold(
            at: Duration(milliseconds: 60),
            duration: Duration(milliseconds: 60),
            intensity: 0.25,
            sharpness: 0.1,
          ),
        ]),
      // The exact inverse of the freeze: the hold releases into the click.
      HapticEvent.sessionResumed => const HapticPattern([
          HapticBeat.hold(
            duration: Duration(milliseconds: 60),
            intensity: 0.25,
            sharpness: 0.1,
          ),
          HapticBeat.tap(
            at: Duration(milliseconds: 60),
            intensity: 0.6,
            sharpness: 0.7,
            androidPulse: confirmPulse,
          ),
        ]),
      // §5.2 — the melted end. A decay with no click anywhere in it. Not
      // punishing; it simply never resolves the way a finished session does,
      // and the contrast is the whole message.
      HapticEvent.sessionEndedEarly => const HapticPattern([
          HapticBeat.hold(
            duration: Duration(milliseconds: 140),
            intensity: 0.45,
            sharpness: 0.1,
          ),
        ]),
      // Two equal soft beats read as "moved", never as a penalty.
      HapticEvent.taskRescheduled => const HapticPattern([
          HapticBeat.tap(intensity: 0.4, sharpness: 0.35, androidPulse: confirmPulse),
          HapticBeat.tap(
            at: Duration(milliseconds: 70),
            intensity: 0.4,
            sharpness: 0.35,
            androidPulse: confirmPulse,
          ),
        ]),
      // Settling in, then the deliberate silence §4.2 requires.
      HapticEvent.focusStarted => const HapticPattern([
          HapticBeat.tap(intensity: 0.45, sharpness: 0.3, androidPulse: confirmPulse),
          HapticBeat.hold(
            at: Duration(milliseconds: 40),
            duration: Duration(milliseconds: 40),
            intensity: 0.2,
            sharpness: 0.1,
          ),
        ]),
      // An echo, so a commit is never mistaken for one more ramp detent.
      HapticEvent.moodLogged => const HapticPattern([
          HapticBeat.tap(intensity: 0.5, sharpness: 0.5, androidPulse: confirmPulse),
          HapticBeat.tap(
            at: Duration(milliseconds: 80),
            intensity: 0.25,
            sharpness: 0.4,
          ),
        ]),
      // Deliberately identical. These three can never be felt in sequence, so
      // differentiating them would buy nothing and spend vocabulary.
      HapticEvent.taskCreated ||
      HapticEvent.subjectCreated ||
      HapticEvent.suggestionPosted =>
        const HapticPattern([
          HapticBeat.tap(
            intensity: 0.55,
            sharpness: 0.65,
            androidPulse: confirmPulse,
          ),
        ]),
      // The smallest commitment in the app gets the smallest thing we have.
      HapticEvent.voteCast => const HapticPattern([
          HapticBeat.tap(intensity: 0.35, sharpness: 0.8),
        ]),

      // ── Tier 3 — detents ───────────────────────────────────────────────
      HapticEvent.moodRampStep => HapticPattern([
          HapticBeat.tap(
            intensity:
                _moodRamp[(rampStep ?? 0).clamp(0, _moodRamp.length - 1)].$1,
            sharpness:
                _moodRamp[(rampStep ?? 0).clamp(0, _moodRamp.length - 1)].$2,
          ),
        ]),
      // Stronger and duller than a scroll tick, and longer: it has to be felt
      // *through* a sustained press rather than under a brushing fingertip.
      HapticEvent.longPressTick => const HapticPattern([
          HapticBeat.tap(
            intensity: 0.8,
            sharpness: 0.6,
            androidPulse: longPressPulse,
          ),
        ]),
      HapticEvent.sliderStop => const HapticPattern([
          HapticBeat.tap(intensity: 0.65, sharpness: 0.85),
        ]),
      HapticEvent.wheelItem => const HapticPattern([
          HapticBeat.tap(intensity: 0.6, sharpness: 0.9),
        ]),
      // Faintest in the system — it fires on every tab change — but still well
      // clear of the perceptibility floor.
      HapticEvent.segmentChange => const HapticPattern([
          HapticBeat.tap(intensity: 0.55, sharpness: 0.95),
        ]),

      // ── Tier 4 — warnings ──────────────────────────────────────────────
      // Two hard evenly-spaced hits, and the only double-heavy in the app.
      HapticEvent.destructiveConfirmed => const HapticPattern([
          HapticBeat.tap(intensity: 1, sharpness: 0.95, androidPulse: earnedPulse),
          HapticBeat.tap(
            at: Duration(milliseconds: 130),
            intensity: 1,
            sharpness: 0.95,
            androidPulse: earnedPulse,
          ),
        ]),
      // Dull rather than sharp, so it cannot be read as a confirmation even on
      // a weak motor where the impacts would otherwise collapse together.
      HapticEvent.saveFailed => const HapticPattern([
          HapticBeat.hold(
            duration: Duration(milliseconds: 250),
            intensity: 0.7,
            sharpness: 0.05,
          ),
        ]),
      // A wall, not a slap.
      HapticEvent.guestWallHit => const HapticPattern([
          HapticBeat.hold(
            duration: Duration(milliseconds: 120),
            intensity: 0.35,
            sharpness: 0.15,
          ),
        ]),
    };

/// How long [event] occupies the motor — read by the governor.
Duration hapticSpanOf(HapticEvent event, int? rampStep) =>
    patternFor(event, rampStep: rampStep).span;

/// Play [event] — the single point where a semantic name becomes a vibration.
///
/// Never throws. A device with no motor, a desktop embedder with no
/// `flutter/platform`, or a widget test with nothing behind the channel all
/// resolve to silence: haptics is enrichment, and losing it must never surface
/// an error, fail a frame, or reach the global error handler.
Future<void> playHapticEvent(HapticEvent event, {int? rampStep}) =>
    hapticDriver.play(patternFor(event, rampStep: rampStep));
