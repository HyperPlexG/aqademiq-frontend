# Testing the haptics

Companion to [`docs/HAPTICS_IMPLEMENTATION.md`](HAPTICS_IMPLEMENTATION.md) (the
*where*) and `HAPTICS.md` on the implementation branch (the *what was built*).
This file is the *how do I know it works*.

Read §0 before anything else. Most haptics "bugs" reported during review turn
out to be one of the three environments below, where the code is silent **by
design**.

---

## 0. Where the code lives, and where it will never fire

The implementation is **not on `main`**. It is `rithikh/haptics/melt-ramp` —
two commits, 36 files, on top of `40945f0`. Everything new lives under
`lib/services/haptics/`:

```
lib/services/haptics/
  haptics_service.dart          interface + NoopHapticsService + RealHapticsService + hapticsProvider
  haptic_governor.dart          the five suppression rules + the HapticSetting enum
  haptic_patterns.dart          the 23 events, their tiers, and the ONLY HapticFeedback calls
  haptic_settings_service.dart  SharedPreferences (haptics_level, haptics_streak_mark)
lib/features/settings/providers/haptic_settings_provider.dart
lib/features/stats/providers/streak_milestone_provider.dart
test/haptics_governor_test.dart · haptics_focus_once_test.dart · haptics_tab_change_test.dart
```

Get it:

```bash
git fetch rithikh && git checkout -b haptics rithikh/haptics/melt-ramp && flutter pub get
```

It merges into `main` cleanly.

### Three places haptics are silent by design

| Environment | Why | What you'd wrongly conclude |
|---|---|---|
| **Chrome / web** | `hapticsProvider` returns `NoopHapticsService` when `kIsWeb` — iOS Safari has no Vibration API, so the app ships silence rather than a degraded approximation. | "None of it works." |
| **iOS Simulator / Android emulator** | No vibration motor. `playHapticEvent` swallows the platform error on purpose, so you get no vibration *and* no log line. | "The events aren't firing." |
| **Any widget test** | Same swallow — tests must never depend on a platform channel. | "The tests don't prove anything." (They do; they assert on a fake service, not on the motor.) |

**Manual haptic testing requires a physical phone.** Nothing else counts.

### Device settings that will silently suppress everything

Check these first when a device feels dead:

- **iOS** — Settings → Sounds & Haptics → **System Haptics** must be **on**.
  **Low Power Mode disables haptics entirely** on iPhone.
- **Android** — Settings → Sound & vibration → Vibration & haptics →
  **Touch feedback** must be on and not at zero intensity.
- **Either** — the OS **reduce-motion** flag clamps the app's `Full` down to
  `Essential`, which kills every Tier 2 and Tier 3 event. That is intended
  behaviour (see §4 R2), and it is the most likely reason a working build feels
  half-broken.

---

## 1. Automated — 5 minutes, any machine, no device

```bash
flutter test test/haptics_governor_test.dart test/haptics_focus_once_test.dart test/haptics_tab_change_test.dart
```

Verified on `9da0751`: **26/26 pass**. Full suite (`flutter test`) —
**160/160 pass**.

What each file is actually protecting:

| File | Covers | Why it can't be tested by hand |
|---|---|---|
| `haptics_governor_test.dart` | the setting ladder, the reduce-motion clamp, focus suppression (incl. that `focusStarted` is *not* exempt), the 50 ms floor, burst coalescing, fling suppression, and that the tier counts still match the spec | all six rules fail **silently** — a broken one feels identical to a correct one until the aggregate is wrong |
| `haptics_focus_once_test.dart` | exactly one event per focus session — `FocusController.complete()` runs **twice** on the end-early path and **not at all** on the natural one | a double-fire 90 ms apart is indistinguishable from the intended composite by feel |
| `haptics_tab_change_test.dart` | tab change ticks once; re-tapping the active tab is silent | the difference is one absent tick |

```bash
flutter analyze
```

Expect **8 infos** on the branch vs **5** on its base — three new, all trivial:
`haptics_service.dart:2` (unnecessary `dart:ui` import),
`haptics_governor_test.dart:82` and `:109` (style). Zero warnings, zero errors.
Worth clearing before merge; not a blocker for testing.

---

## 2. Set up the device pass

1. A real iPhone **and** a cheap Android handset. Spec §8.2 is explicit that an
   iPhone-only review is not a review — Flutter's constants collapse to
   near-identical output on weak motors.
2. `flutter run` (debug) uses **mocks**, which is what you want for most of the
   matrix — fixtures give you tasks, moods and feedback posts with no network.
   Use `flutter run --dart-define-from-file=dart_defines.json` for the events
   that need a real account (guest upgrade, vote, suggestion posted).
3. Settings → **Prism** → **Haptics** group → confirm it reads **Full** (the
   default on a fresh install).

---

## 3. The 23-event walkthrough

Tier matters: at the **Essential** setting only Tier 1 and Tier 4 fire, so run
this pass at **Full**. "Expect" is the physical impulse the event resolves to.

### Tier 1 — earned moments (5)

| # | Event | Do this | Expect |
|---|---|---|---|
| 1 | `taskCompleted` | Plan → tick a task's checkbox | one medium impact, **after** the save resolves |
| 2 | `focusCompleted` | Focus → start a 1-minute session → let it run out | **two beats** ~90 ms apart, second stronger. The only composite in the app |
| 3 | `streakMilestone` | see §6 — needs a fresh install | one heavy impact at the crossing |
| 4 | `guestUpgraded` | as a guest, sign up and enter the OTP | one medium impact on successful verify |
| 5 | `onboardingFinished` | complete all 11 onboarding steps | one heavy impact at the end — and **nothing** on steps 1–11 |

### Tier 2 — state confirmations (10)

| # | Event | Do this | Expect |
|---|---|---|---|
| 6 | `taskCreated` | Add task → Save; also Plan's quick-add; also Ada → apply a plan | light |
| 7 | `taskRescheduled` | move a task to another day | light — must not feel like a penalty |
| 8 | `focusStarted` | Focus → Start | light, then **total silence** until the session resolves |
| 9 | `sessionFrozen` | during a session → Freeze | **medium** — sharper than everything else in Tier 2, a lock engaging |
| 10 | `sessionResumed` | → Resume | light, softer than the freeze that preceded it |
| 11 | `sessionEndedEarly` | → End before the timer runs out | light. Must be unmistakably **not** the completion composite |
| 12 | `moodLogged` | log a mood from Plan, Mood morning/evening, or the Stats day editor | light, on commit |
| 13 | `subjectCreated` | create a subject; also create a semester | light |
| 14 | `suggestionPosted` | Feedback → post a suggestion | light |
| 15 | `voteCast` | Feedback → vote on a post | **tick** — the lightest thing in the system |

### Tier 3 — selection detents (5)

| # | Event | Do this | Expect |
|---|---|---|---|
| 16 | `moodRampStep` | drag across the 5 mood positions | a tick **per position change**, softest at "Rough" and sharpening to medium at "Great" — the melt ramp |
| 17 | `wheelItem` | time-picker wheel; month-picker wheel | one tick per item — the iOS expectation these wheels never had |
| 18 | `sliderStop` | focus-duration slider, task-duration slider, Prism volume sliders | one tick **per detent**, never per pixel |
| 19 | `segmentChange` | switch bottom-nav tabs | faintest tick, **only on an actual change** |
| 20 | `longPressTick` | Plan → long-press a task card | tick **as the gesture is recognised**, before the sheet opens. This is the fix for spec Finding 04 — the tick *is* how you learn the gesture exists |

### Tier 4 — warnings (3)

| # | Event | Do this | Expect |
|---|---|---|---|
| 21 | `destructiveConfirmed` | delete a task / subject / semester / account | **heavy**, deliberately unpleasant |
| 22 | `saveFailed` | see §5.2 — turn off the network first | a dull **buzz**, not an impact |
| 23 | `guestWallHit` | as a guest, try to vote or post in Feedback | **light** and soft — the user hit a wall, don't also slap them |

---

## 4. The five governor rules

These are the rules that fail silently. The unit tests cover the logic; these
steps prove the wiring reaches a real device.

**R1 — the setting ladder.** Settings → Prism → Haptics → **Essential**. Now
ticking a task still fires (Tier 1) and deleting still fires (Tier 4), but the
wheels, the sliders, the tab bar and every Tier 2 confirmation go **silent**.
Set **Off** → nothing fires anywhere. Kill and relaunch: the choice persists
(`haptics_level` in SharedPreferences).

**R2 — reduce motion clamps Full to Essential.** Set the app back to **Full**,
then turn on iOS Settings → Accessibility → Motion → **Reduce Motion** (Android:
Accessibility → **Remove animations**). Repeat the wheel and tab-bar checks —
they must be silent, exactly as if the app were set to Essential. Turn it off
and they return. The app setting may be *stricter* than the OS, never looser.

**R3 — focus suppression, the strictest rule in the spec.** Start a session,
then during the run switch tabs, tick a task, open a picker, drag a slider.
**Nothing may fire.** Only Freeze, Resume and End are allowed through. This is
also how the haptic layer stays out of Prism's way.

**R4 — fling suppression.** Open the time picker. *Flick* the wheel hard: ticks
must stop after ~3 rapid detents and stay stopped while it spins. Now turn it
slowly, one stop at a time: every item ticks. A fling that decelerates starts
ticking again.

**R5 — the 50 ms floor and burst coalescing.** Not manually observable — this is
what `haptics_governor_test.dart` exists for. Two events in one frame fire only
the highest tier.

---

## 5. The cases most likely to be wrong

Each of these has a plausible failure that feels fine, so test them
deliberately.

1. **Un-ticking a task must be silent.** Tick a task (buzz), untick it
   (**nothing**). A correction is not an earned moment.
2. **Optimistic rollback fires the warning, not the reward.** Turn off wifi and
   mobile data, then tick a task. The row flips, the save fails, the row flips
   back — you must get the Tier 4 **buzz**, not the completion impact. Same for
   move and delete. The haptic confirms the *outcome*, never the tap.
3. **One haptic per session ending, never two.** End a session early: exactly
   **one** light impact. Let one run out: exactly **one** composite (two beats
   *is* one event).
4. **A completed session must not double-fire with its task.** Finishing a
   session marks the linked task done **server-side**, so the client's
   `toggleDone` never runs. You should feel the session's composite and nothing
   else.
5. **Password recovery must not fire `guestUpgraded`.** Reset a password and
   enter the recovery OTP — same code path, different event, earns nothing.
   Only the signup / link-guest branch buzzes.
6. **SSO failures stay silent.** Cancelling an Apple or Google sheet fires
   nothing. Only email-based submissions (sign-in, sign-up, verify, reset) get
   the failure buzz.

---

## 6. The streak milestone — read this before filing a bug

`streakMilestone` is the hardest event to test, because it is guarded twice and
both guards make it *look* broken:

- A **persisted watermark** (`haptics_streak_mark`) means a milestone fires once
  in the life of the install, not once per recompute.
- A **session baseline** means the first streak value seen after launch is
  recorded in silence, so opening the app with an existing 30-day streak does
  not buzz on the splash screen.

To actually see it: **uninstall or clear app data**, launch, then log moods
until you cross the next rung — **3, 7, 14, 30, 50, 100, 200, 365** — *within
the same app session*. The watermark falls as well as rises, so a broken streak
re-arms the ladder.

---

## 7. What must NOT vibrate

The point of the system is that ~148 of the app's 170 tap targets stay inert.
Walk these and confirm silence:

- day-navigation arrows, view switching, card collapse/expand, list scrolling
- **re-tapping the tab you are already on**
- onboarding steps 1–11, per-digit OTP entry, SSO button taps
- sheet open/close, note typing, toasts, app launch
- sub-task / micro-step ticks, file attach, sort and filter controls
- feedback board scroll, opening a post's detail
- Ada: sending a message, the reply arriving, streaming, history
- every stat view on Stats and Profile

Per-screen budgets are in `HAPTICS.md` §3. Exceeding a budget means **removing**
something, not raising the budget.

---

## 8. The review protocol (spec §8.2 — not optional)

1. **Screen dimmed, sound off.** Run the §3 matrix again. If you cannot tell
   what happened from the haptic alone *in context*, it is noise you have grown
   used to.
2. **Then the cheap Android handset.** Nothing in the design may depend on
   telling two similar patterns apart, because weak motors collapse them.

---

## 9. Sign-off checklist

- [ ] `flutter test` — 160/160
- [ ] `flutter analyze` — no new warnings or errors
- [ ] All 23 events felt on a real iPhone, at **Full**
- [ ] All 23 events felt on a real Android handset
- [ ] R1–R4 verified on device
- [ ] §5's six failure cases verified
- [ ] §7's silence list walked with nothing firing
- [ ] §8.1 dimmed-screen pass done on both handsets
