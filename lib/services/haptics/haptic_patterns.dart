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
library;

import 'package:flutter/services.dart';

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
  /// settles which way to resolve that. Physically it is the same uniform Tier 3
  /// tick as its neighbours; it is named separately so the call site can say
  /// what actually happened instead of claiming a segment changed.
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

/// The physical primitives, in ascending sharpness. Private on purpose — the
/// rest of the app has no business knowing these exist.
enum _Impulse { tick, light, medium, heavy, buzz }

Future<void> _fire(_Impulse impulse) {
  switch (impulse) {
    case _Impulse.tick:
      return HapticFeedback.selectionClick();
    case _Impulse.light:
      return HapticFeedback.lightImpact();
    case _Impulse.medium:
      return HapticFeedback.mediumImpact();
    case _Impulse.heavy:
      return HapticFeedback.heavyImpact();
    case _Impulse.buzz:
      return HapticFeedback.vibrate();
  }
}

/// The melt ramp, expressed in the impulse strengths Flutter actually gives us
/// (spec §5.1).
///
/// Softer at "Rough" (0), sharper at "Great" (4) — gentler rather than
/// punishing, so the physical metaphor and the emotional read agree.
///
/// Five positions do not map onto three strengths, and are not supposed to.
/// Spec §8.2: iOS expresses the full ramp, Android "degrades to two levels on
/// weak motors — acceptable by design". Losing the ramp entirely still leaves a
/// correct system, because the ramp is richness, never meaning.
const List<_Impulse> _moodRamp = [
  _Impulse.tick, //   0 · Rough
  _Impulse.tick, //   1 · Tired
  _Impulse.light, //  2 · OK
  _Impulse.light, //  3 · Good
  _Impulse.medium, // 4 · Great
];

/// Gap between the two beats of the app's only composite. Long enough to read
/// as two events, short enough to read as one gesture.
const Duration _compositeGap = Duration(milliseconds: 90);

/// The impulse each event resolves to.
///
/// A switch *expression*, so adding a [HapticEvent] without giving it a feel is
/// a compile error rather than a silent no-op.
_Impulse _impulseFor(HapticEvent event, int? rampStep) => switch (event) {
      // ── Tier 1 ──────────────────────────────────────────────────────────
      // Crisp, single, like ice cracking.
      HapticEvent.taskCompleted => _Impulse.medium,
      // First beat of the composite; [playHapticEvent] adds the second.
      HapticEvent.focusCompleted => _Impulse.medium,
      HapticEvent.streakMilestone => _Impulse.heavy,
      // Crisp and reassuring.
      HapticEvent.guestUpgraded => _Impulse.medium,
      HapticEvent.onboardingFinished => _Impulse.heavy,

      // ── Tier 2 — a single light impact, except where the ramp applies ───
      HapticEvent.taskCreated ||
      HapticEvent.taskRescheduled ||
      HapticEvent.focusStarted ||
      HapticEvent.moodLogged ||
      HapticEvent.subjectCreated ||
      HapticEvent.suggestionPosted =>
        _Impulse.light,
      // §5.3 — Freeze is `Icons.ac_unit` and is asking for a sharp terminating
      // set/lock tick. The one Tier 2 event that steps above the light single.
      HapticEvent.sessionFrozen => _Impulse.medium,
      // The release of the freeze — softer than the lock that preceded it.
      HapticEvent.sessionResumed => _Impulse.light,
      // §5.2 — the melted end. Soft, and unmistakably not the composite a
      // completed session earns. The contrast carries it; the texture need not.
      HapticEvent.sessionEndedEarly => _Impulse.light,
      // A small commitment, so the lightest thing we have.
      HapticEvent.voteCast => _Impulse.tick,

      // ── Tier 3 — uniform ticks, except the ramp ─────────────────────────
      HapticEvent.moodRampStep =>
        _moodRamp[(rampStep ?? 0).clamp(0, _moodRamp.length - 1)],
      HapticEvent.wheelItem ||
      HapticEvent.sliderStop ||
      HapticEvent.segmentChange ||
      HapticEvent.longPressTick =>
        _Impulse.tick,

      // ── Tier 4 — distinct from everything above ─────────────────────────
      // Hard and unpleasant, on purpose.
      HapticEvent.destructiveConfirmed => _Impulse.heavy,
      // A dull error buzz rather than an impact, so it cannot be mistaken for a
      // confirmation on a device where the impacts collapse together.
      HapticEvent.saveFailed => _Impulse.buzz,
      // Soft, not sharp. The user hit a wall; do not also slap them.
      HapticEvent.guestWallHit => _Impulse.light,
    };

/// Play [event] — the single point where a semantic name becomes a vibration.
///
/// [rampStep] is the 0–4 melt position and is read only for
/// [HapticEvent.moodRampStep].
///
/// Only [HapticEvent.focusCompleted] is a composite (guide §1.2: "two beats,
/// second stronger. Nothing else in the app gets a multi-part pattern"). That
/// is deliberately stricter than the impulse glyphs drawn in spec §3, which
/// notate ascending pairs for the streak and onboarding events and two even
/// beats for a destructive confirm. Spec §5 settles it: meaning must never
/// depend on discriminating two *similar* patterns, so those collapse to single
/// impulses and lose nothing that was carrying meaning.
Future<void> playHapticEvent(HapticEvent event, {int? rampStep}) async {
  try {
    await _fire(_impulseFor(event, rampStep));
    if (event == HapticEvent.focusCompleted) {
      await Future<void>.delayed(_compositeGap);
      await _fire(_Impulse.heavy);
    }
  } on Object {
    // A device with no vibration motor, a desktop embedder that does not
    // implement `flutter/platform`, or a widget test with nothing behind the
    // channel. Guide §1.1 asks that tests never *depend* on a platform channel,
    // and this is what makes that true from the inside rather than by asking
    // every test to remember an override.
    //
    // Haptics is enrichment. Losing it must never surface an error, fail a
    // frame, or reach the global error handler.
  }
}
