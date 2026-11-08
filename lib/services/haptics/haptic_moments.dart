/// The touchpoints — spec §4, one row per moment, in the spec's order.
///
/// Screens never name a pattern. They name the moment that just happened
/// (`HapticMoment.taskChecked`) and this table says how it feels and in which
/// tier it plays, so the whole of §4 can be checked against the PDF in one
/// file and retuned without touching a screen.
///
/// Rows the spec marks **None** (splash, the age gate, a running session, Ada
/// thinking, the profile numbers, the Core's hero beat) are deliberate
/// silences and have no moment here: there is nothing to call. Rows marked
/// **System** are drawn by the OS (lock screen, Island, widgets, the
/// background session-complete notification) and are not ours either.
library;

import 'haptic_lexicon.dart';

/// Which setting a moment plays under (§3).
enum HapticTier {
  /// Session start, pause, resume, end and completion; freezing, the thaw
  /// breath and its release; deep freeze holding; system success and error.
  /// About ten moments a day.
  essential,

  /// Everything else: ticks, toggles, wheels, swipes, Ada, the Core, Prism
  /// previews.
  full,

  /// The haptics sheet's own preview of the level just picked. Plays whatever
  /// the setting was, because it is how the user chooses by feel.
  preview,
}

/// Every moment in the app that has a feel.
enum HapticMoment {
  // ── Across the app ─────────────────────────────────────────────────────
  /// Tab bar: switch tab → tick.
  tabSwitch(HapticTier.full),

  /// Tab bar: the centre Ada tab → clink. Ada is a cube.
  tabAda(HapticTier.full),

  /// Tab bar (guest): a locked Stats or Ada → knock at 60%. Also any guest
  /// wall the student deliberately walked into.
  tabLocked(HapticTier.full),

  /// A sheet snaps to a resting height → tick.
  sheetSnap(HapticTier.full),

  /// A sheet dragged past its dismiss point → tick.
  sheetDismissArm(HapticTier.full),

  /// …and back above it → unlatch.
  sheetDismissDisarm(HapticTier.full),

  /// Wheel pickers (month + year, time, duration, age): tick per step, under
  /// the wheel rules. Call with `landed: true` when the wheel settles.
  wheelStep(HapticTier.full, stream: true),

  /// Toggle on → latch.
  toggleOn(HapticTier.full),

  /// Toggle off → unlatch.
  toggleOff(HapticTier.full),

  /// Chips and segmented controls → tick.
  chipSelect(HapticTier.full),

  /// Copy to clipboard (referral code, @tryaqademiq tag) → latch.
  copied(HapticTier.full),

  /// A real failure — wrong code, failed save, offline → system error.
  failure(HapticTier.essential),

  // ── 00 Entry · 01 Onboarding ───────────────────────────────────────────
  /// One-time code: each digit → tick.
  otpDigit(HapticTier.full, stream: true),

  /// One-time code verified → system success.
  otpVerified(HapticTier.full),

  /// Consent: agree → latch. Declining is not marked.
  consentAgree(HapticTier.full),

  /// Referral code: tick per character, firmer on the 4th (I .5). `step` is
  /// the character's 0-based position.
  referralChar(HapticTier.full, stream: true),

  /// Referral code valid → two latches 120 ms apart, one per half.
  referralValid(HapticTier.full),

  /// Referral code not found → knock. A miss feels solid, not wrong.
  referralNotFound(HapticTier.full),

  /// Feelings per subject: pick a melt cube → texture[step].
  feelingPick(HapticTier.full, stream: true),

  /// Study hours: a day chip on → latch.
  studyDayOn(HapticTier.full),

  /// …off → unlatch.
  studyDayOff(HapticTier.full),

  /// Study hours: dragging a time handle, per 30 minutes → tick.
  studyHoursDrag(HapticTier.full, stream: true),

  /// App freeze permission granted → latch, after the system dialog closes.
  /// Nothing on decline.
  freezePermissionGranted(HapticTier.full),

  /// Pick apps (Android): a row ticked → latch.
  pickAppOn(HapticTier.full),

  /// …unticked → unlatch.
  pickAppOff(HapticTier.full),

  /// Meet Prism: tap a mode card → that mode's Prism pattern (`mode`).
  meetPrism(HapticTier.full),

  /// Ada loading: the plan is ready → thud at 60%. The loader stays silent.
  adaPlanReady(HapticTier.full, ambient: true),

  // ── 02 Plan · 03 Subjects · 09 Swipe actions ───────────────────────────
  /// Task checked off → latch. The most satisfying click in the app.
  taskChecked(HapticTier.full),

  /// Task unchecked → unlatch.
  taskUnchecked(HapticTier.full),

  /// Microtask checked off → tick. Lighter, so the hierarchy is felt.
  microtaskChecked(HapticTier.full),

  /// The last task of the day checked off → crystallise at 60%. The day sets.
  lastTaskOfDay(HapticTier.full),

  /// Swipe: crossing the reveal point → tick.
  swipeArm(HapticTier.full),

  /// Swipe: full swipe commits → latch.
  swipeCommit(HapticTier.full),

  /// Swipe: pulled back below the reveal point → unlatch.
  swipeBack(HapticTier.full),

  /// Long-press a task: the card lifts → rigid tap.
  taskLift(HapticTier.full),

  /// Drag on the timeline: per 15-minute slot → tick.
  timelineSlot(HapticTier.full, stream: true),

  /// Drag on the timeline: drop → latch.
  timelineDrop(HapticTier.full),

  /// Reschedule remaining: one tick per moved task (up to 5, `count`), 50 ms
  /// apart, then latch.
  rescheduleRemaining(HapticTier.full),

  /// Quick add / add task opened → tap.
  quickAddOpen(HapticTier.full),

  /// Quick add / add task saved → latch.
  quickAddSave(HapticTier.full),

  /// Reorder semesters or subjects: lift → rigid tap.
  reorderLift(HapticTier.full),

  /// …passing a slot → tick.
  reorderPass(HapticTier.full, stream: true),

  /// …drop → latch.
  reorderDrop(HapticTier.full),

  /// Target as GPA or %: each step → tick.
  targetStep(HapticTier.full, stream: true),

  // ── 04 Focus ───────────────────────────────────────────────────────────
  /// Set time: tap the 25:00 → tap.
  setTimeOpen(HapticTier.full),

  /// Set time: pick a length → tick.
  setTimeStep(HapticTier.full, stream: true),

  /// Prism picker: highlight a mode → that mode's pattern (`mode`).
  prismPicked(HapticTier.full),

  /// Start session → thud, then 120 ms later the Prism pattern (`mode`). The
  /// last vibration until the session ends.
  sessionStart(HapticTier.essential),

  /// Pause: the timer freezes → crystallise.
  sessionPause(HapticTier.essential),

  /// Resume: the melt continues → melt.
  sessionResume(HapticTier.essential),

  /// End early (confirm) → melt at 60%. Nothing breaks, nothing is judged.
  sessionEndEarly(HapticTier.essential),

  /// Session complete with the app open → bloom (desk-safe when face down).
  sessionComplete(HapticTier.essential),

  /// Trim-the-set offer accepted → latch.
  trimOfferAccept(HapticTier.full),

  // ── 04-A App freeze ────────────────────────────────────────────────────
  /// Freeze now (confirm) → crystallise.
  freezeNow(HapticTier.essential),

  /// Keep only these (confirm) → crystallise, extended to 8 grains.
  keepOnlyThese(HapticTier.essential),

  /// Choose apps · groups: tick a row / add to a list → latch.
  chooseAppOn(HapticTier.full),

  /// …untick → unlatch.
  chooseAppOff(HapticTier.full),

  /// Thaw · a breath first: the 10-second wait → breath. Start with
  /// [HapticsService.hold]; leaving the wait fades it out over 150 ms.
  thawBreath(HapticTier.essential),

  /// Thaw · increasing resistance: the 30-second wait → three breaths at
  /// 100%, 80% and 60%.
  thawBreathLong(HapticTier.essential),

  /// Thaw · how long: stepping 2–15 minutes → friction (`step` = minutes).
  thawLength(HapticTier.full, stream: true),

  /// Thaw confirmed: the app opens → melt.
  thawConfirmed(HapticTier.essential),

  /// Refreeze: thaw time ends with Aqademiq open → crystallise at 60%.
  /// Nothing if the student is in another app (we never vibrate inside one).
  refreeze(HapticTier.full, ambient: true),

  /// Deep freeze holds: Thaw tapped during deep freeze → knock.
  deepFreezeHolds(HapticTier.essential),

  /// Frost editor: a day on → latch.
  frostDayOn(HapticTier.full),

  /// …a day off → unlatch.
  frostDayOff(HapticTier.full),

  /// …start time stepped → tick.
  frostTimeStep(HapticTier.full, stream: true),

  /// …saved → crystallise at 50%. A frost is a freeze for later.
  frostSaved(HapticTier.full),

  /// Running frost · end early (confirm) → melt.
  frostEndEarly(HapticTier.essential),

  /// Thaw everything: the 1.2-second hold → ratchet. Start with
  /// [HapticsService.hold].
  thawEverythingHold(HapticTier.essential),

  /// Thaw everything: the hold completes → crack, then melt.
  thawEverythingDone(HapticTier.essential),

  // ── 05 Ada ─────────────────────────────────────────────────────────────
  /// Send: the message leaves → tap.
  adaSend(HapticTier.full),

  /// Voice: start listening → latch.
  voiceStart(HapticTier.full),

  /// Voice: stop listening → unlatch.
  voiceStop(HapticTier.full),

  /// Stop generating → unlatch.
  stopGenerating(HapticTier.full),

  /// Proposals arrive: the tray appears → one tick.
  proposalsArrived(HapticTier.full, ambient: true),

  /// Approve one → latch.
  approveOne(HapticTier.full),

  /// Approve all → one latch per proposal (`count`) 70 ms apart, then thud at
  /// 40%.
  approveAll(HapticTier.full),

  /// Decline → unlatch.
  decline(HapticTier.full),

  /// Undo → unlatch, then tick.
  undo(HapticTier.full),

  // ── 06 Profile · 07 Mood · 12 Feedback · 14 Ice Breakers ───────────────
  /// Mood check-in: moving across moods → texture[step].
  moodMove(HapticTier.full, stream: true),

  /// Mood check-in saved → thud at 50%. Logged; calm, not celebratory.
  moodSave(HapticTier.full),

  /// Feedback: upvote → latch.
  feedbackUpvote(HapticTier.full),

  /// Feedback: remove vote → unlatch.
  feedbackUnvote(HapticTier.full),

  /// Feedback: submit → latch.
  feedbackSubmit(HapticTier.full),

  /// Ice Breakers: open a video → tap. Nothing while it plays.
  iceBreakerOpen(HapticTier.full),

  /// Ice Breakers: the watched pile collapses → tick.
  iceBreakerCollapse(HapticTier.full),

  // ── 08 The Core ────────────────────────────────────────────────────────
  /// Beat 01: the core freezes in as the report opens → drill, ending in a
  /// latch when the core locks.
  coreFreezesIn(HapticTier.full),

  /// Advance a beat → tick. A page turn.
  coreAdvance(HapticTier.full),

  /// Beat 05: the one numeral lands → thud.
  coreNumeral(HapticTier.full),

  /// Beat 07: cracked cubes appear → crack at 35% per cube (`count`), 120 ms
  /// apart.
  coreThawedCubes(HapticTier.full),

  /// Beat 09: one small thing accepted → latch.
  coreAccept(HapticTier.full),

  // ── 13 Settings ────────────────────────────────────────────────────────
  /// Haptics sheet: Off picked → one last unlatch, then silence.
  previewOff(HapticTier.preview),

  /// Haptics sheet: Essential picked → thud plus the Prism pattern (`mode`):
  /// the session start.
  previewEssential(HapticTier.preview),

  /// Haptics sheet: Full picked → tick, tick, latch.
  previewFull(HapticTier.preview),

  /// Resistance sheet: pick a wait length → tick.
  resistancePick(HapticTier.full),

  /// Rate Aqademiq: each star → tick.
  rateStar(HapticTier.full, stream: true),

  /// Rate Aqademiq: submit → latch.
  rateSubmit(HapticTier.full),

  /// Delete account: the 2-second hold → ratchet. Start with
  /// [HapticsService.hold].
  deleteAccountHold(HapticTier.essential),

  /// Delete account: the hold completes → knock. The only action that cannot
  /// be undone gets the most friction.
  deleteAccountDone(HapticTier.essential);

  const HapticMoment(this.tier, {this.stream = false, this.ambient = false});

  final HapticTier tier;

  /// Continuous input — a wheel, a dial, typing. Rate-limited by the wheel
  /// rules and exempt from the repetition rule (it is one gesture, not a
  /// repeat).
  final bool stream;

  /// Not something the student just did: Ada's proposals arriving, a refreeze,
  /// a plan finishing. Silent while a focus session runs (§3, "Running
  /// session").
  final bool ambient;
}

/// The hold-to-confirm lengths the spec gives.
const thawEverythingHoldTime = Duration(milliseconds: 1200);
const deleteAccountHoldTime = Duration(seconds: 2);

/// What [moment] feels like. [step], [count] and [mode] are read only by the
/// moments that document them.
///
/// A switch expression, so a moment without a feel is a compile error.
HapticSpec specFor(HapticMoment moment, {int step = 0, int count = 1, String? mode}) => switch (moment) {
      HapticMoment.tabSwitch => Aq.tick,
      HapticMoment.tabAda => Aq.clink,
      HapticMoment.tabLocked => Aq.knock.scaled(0.6),
      HapticMoment.sheetSnap => Aq.tick,
      HapticMoment.sheetDismissArm => Aq.tick.withAndroidConstant('fb:GESTURE_THRESHOLD_ACTIVATE'),
      HapticMoment.sheetDismissDisarm => Aq.unlatch.withAndroidConstant('fb:GESTURE_THRESHOLD_DEACTIVATE'),
      HapticMoment.wheelStep => Aq.tick,
      HapticMoment.toggleOn => Aq.latch,
      HapticMoment.toggleOff => Aq.unlatch,
      HapticMoment.chipSelect => Aq.tick,
      HapticMoment.copied => Aq.latch,
      HapticMoment.failure => Aq.error,
      HapticMoment.otpDigit => Aq.tick,
      HapticMoment.otpVerified => Aq.success,
      HapticMoment.consentAgree => Aq.latch,
      HapticMoment.referralChar => step == 3 ? _firmTick : Aq.tick,
      HapticMoment.referralValid => Aq.latch.repeated(2, const Duration(milliseconds: 120)),
      HapticMoment.referralNotFound => Aq.knock,
      HapticMoment.feelingPick => Aq.texture(step),
      HapticMoment.studyDayOn => Aq.latch,
      HapticMoment.studyDayOff => Aq.unlatch,
      HapticMoment.studyHoursDrag => Aq.tick,
      HapticMoment.freezePermissionGranted => Aq.latch,
      HapticMoment.pickAppOn => Aq.latch,
      HapticMoment.pickAppOff => Aq.unlatch,
      HapticMoment.meetPrism => Aq.prism(mode ?? ''),
      HapticMoment.adaPlanReady => Aq.thud.scaled(0.6),
      HapticMoment.taskChecked => Aq.latch,
      HapticMoment.taskUnchecked => Aq.unlatch,
      HapticMoment.microtaskChecked => Aq.tick,
      HapticMoment.lastTaskOfDay => Aq.crystallise().scaled(0.6),
      HapticMoment.swipeArm => Aq.tick,
      HapticMoment.swipeCommit => Aq.latch,
      HapticMoment.swipeBack => Aq.unlatch,
      HapticMoment.taskLift => Aq.tapRigid,
      HapticMoment.timelineSlot => Aq.tick,
      HapticMoment.timelineDrop => Aq.latch,
      HapticMoment.rescheduleRemaining =>
        Aq.tick.repeated(count.clamp(1, 5), const Duration(milliseconds: 50)).then(Aq.latch, gap: const Duration(milliseconds: 50)),
      HapticMoment.quickAddOpen => Aq.tap,
      HapticMoment.quickAddSave => Aq.latch,
      HapticMoment.reorderLift => Aq.tapRigid,
      HapticMoment.reorderPass => Aq.tick,
      HapticMoment.reorderDrop => Aq.latch,
      HapticMoment.targetStep => Aq.tick,
      HapticMoment.setTimeOpen => Aq.tap,
      HapticMoment.setTimeStep => Aq.tick,
      HapticMoment.prismPicked => Aq.prism(mode ?? ''),
      HapticMoment.sessionStart => sessionStartSpec(mode),
      HapticMoment.sessionPause => Aq.crystallise(),
      HapticMoment.sessionResume => Aq.melt,
      HapticMoment.sessionEndEarly => Aq.melt.scaled(0.6),
      HapticMoment.sessionComplete => Aq.bloom,
      HapticMoment.trimOfferAccept => Aq.latch,
      HapticMoment.freezeNow => Aq.crystallise(),
      HapticMoment.keepOnlyThese => Aq.crystallise(grains: 8),
      HapticMoment.chooseAppOn => Aq.latch,
      HapticMoment.chooseAppOff => Aq.unlatch,
      HapticMoment.thawBreath => Aq.breath,
      HapticMoment.thawBreathLong => Aq.breathLong,
      HapticMoment.thawLength => Aq.friction(step),
      HapticMoment.thawConfirmed => Aq.melt,
      HapticMoment.refreeze => Aq.crystallise().scaled(0.6),
      HapticMoment.deepFreezeHolds => Aq.knock,
      HapticMoment.frostDayOn => Aq.latch,
      HapticMoment.frostDayOff => Aq.unlatch,
      HapticMoment.frostTimeStep => Aq.tick,
      HapticMoment.frostSaved => Aq.crystallise().scaled(0.5),
      HapticMoment.frostEndEarly => Aq.melt,
      HapticMoment.thawEverythingHold => Aq.ratchet(thawEverythingHoldTime),
      HapticMoment.thawEverythingDone => Aq.crack.then(Aq.melt, gap: const Duration(milliseconds: 40)),
      HapticMoment.adaSend => Aq.tap,
      HapticMoment.voiceStart => Aq.latch,
      HapticMoment.voiceStop => Aq.unlatch,
      HapticMoment.stopGenerating => Aq.unlatch,
      HapticMoment.proposalsArrived => Aq.tick,
      HapticMoment.approveOne => Aq.latch,
      HapticMoment.approveAll =>
        Aq.latch.repeated(count.clamp(1, 12), const Duration(milliseconds: 70)).then(Aq.thud.scaled(0.4), gap: const Duration(milliseconds: 70)),
      HapticMoment.decline => Aq.unlatch,
      HapticMoment.undo => Aq.unlatch.then(Aq.tick, gap: const Duration(milliseconds: 60)),
      HapticMoment.moodMove => Aq.texture(step),
      HapticMoment.moodSave => Aq.thud.scaled(0.5),
      HapticMoment.feedbackUpvote => Aq.latch,
      HapticMoment.feedbackUnvote => Aq.unlatch,
      HapticMoment.feedbackSubmit => Aq.latch,
      HapticMoment.iceBreakerOpen => Aq.tap,
      HapticMoment.iceBreakerCollapse => Aq.tick,
      HapticMoment.coreFreezesIn => Aq.drill,
      HapticMoment.coreAdvance => Aq.tick,
      HapticMoment.coreNumeral => Aq.thud,
      HapticMoment.coreThawedCubes => Aq.crack.scaled(0.35).repeated(count.clamp(1, 12), const Duration(milliseconds: 120)),
      HapticMoment.coreAccept => Aq.latch,
      HapticMoment.previewOff => Aq.unlatch,
      HapticMoment.previewEssential => sessionStartSpec(mode),
      HapticMoment.previewFull => Aq.tick.repeated(2, const Duration(milliseconds: 110)).then(Aq.latch, gap: const Duration(milliseconds: 110)),
      HapticMoment.resistancePick => Aq.tick,
      HapticMoment.rateStar => Aq.tick,
      HapticMoment.rateSubmit => Aq.latch,
      HapticMoment.deleteAccountHold => Aq.ratchet(deleteAccountHoldTime),
      HapticMoment.deleteAccountDone => Aq.knock,
    };

/// Thud, then 120 ms later the Prism pattern, landing on the audio's first
/// beat. Used by the session start and by the Essential preview, which is the
/// session start felt on its own.
HapticSpec sessionStartSpec(String? mode) {
  final prism = Aq.prism(mode ?? '');
  // The thud's own span is 150 ms; the Prism pattern starts 120 ms after the
  // thud's strike, so it overlaps the thud's tail rather than queueing after.
  return HapticSpec(
    name: 'aq.thud',
    ios: [
      ...Aq.thud.ios,
      for (final e in prism.ios) shiftEvent(e, const Duration(milliseconds: 120)),
    ],
    android: [
      ...Aq.thud.android,
      for (final (i, p) in prism.android.indexed)
        i == 0 ? APrim(p.prim, p.scale, delay: const Duration(milliseconds: 100), alt: p.alt) : p,
    ],
    androidConstant: Aq.thud.androidConstant,
    preferWave: prism.preferWave,
    fallback: Aq.thud.fallback,
  );
}

/// The referral code's 4th character: the midpoint of the 4 + 4 split is felt
/// (I .5 rather than .35).
const _firmTick = HapticSpec(
  name: 'aq.tick',
  ios: [IosTap(intensity: 0.5, sharpness: 0.6)],
  android: [APrim(Prim.tick, 0.7)],
  androidConstant: 'fb:SEGMENT_TICK',
  fallback: Fallback.selection,
);
