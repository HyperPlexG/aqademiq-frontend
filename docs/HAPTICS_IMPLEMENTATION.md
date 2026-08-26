# Haptics — implementation guide

Companion to **Aqademiq · Haptic feedback specification · v1** ("The Melt Ramp").
The spec says *what* and *why*; this says *where in this repo* and *in what
order*. Read the spec first — nothing here repeats its reasoning.

Written for someone working with Claude Code. Every path below was verified
against `main` on 2026-08-21; the counts are from the real tree, not the spec.

---

## 0. Read this before you start

### 0.1 The spec's findings check out — with two exceptions

| Spec claim | Reality on `main` | |
|---|---|---|
| Zero `HapticFeedback` calls | **0** | ✅ |
| `enableFeedback` never set | **0** | ✅ |
| 166 `GestureDetector` vs 17 `InkWell` | **170** vs **17** | ✅ (grown slightly) |
| Exactly one `onLongPress` | **1** | ✅ |
| Two `ListWheelScrollView`, no `CupertinoPicker` | **2** / **0** | ✅ |
| §6.5: "prefers-reduced-motion, which the app already respects" | **Nothing. Zero references** to `disableAnimations`, `accessibleNavigation`, or any reduced-motion check | ❌ **wrong** |
| §3/§6.3: fires from "plan controller", "focus controller", "mood controller", … | Only **one** `features/*/controllers/` directory exists (`auth`). Everything else lives in `features/*/providers/` or `data/repositories/` | ❌ **misleading** |

**Do not go looking for a reduced-motion setting to hang haptics off.** It does
not exist. Either add it (`MediaQuery.of(context).disableAnimations`) as a
separate, clearly-scoped change, or drop that clause from §6.5. Do not silently
skip it and leave the spec claiming a contract the app does not honour.

**"Controller" in the spec means "the thing that owns the state transition."**
In this codebase that is usually a Riverpod `Notifier` under
`features/*/providers/`. §6.3's *principle* is right (fire from state
transitions, not widgets); its *file names* are not. Use the map in §3 below.

### 0.2 The one thing that makes this succeed or fail

Read **§4 of the spec — "What must not fire"** twice. This task is 20%
adding haptics and 80% not adding them. The repo has **170 `GestureDetector`s**
and exactly **22** of the interactions behind them deserve a haptic. The
temptation to "just add a light tap to this one too" is the failure mode, and it
is unrecoverable — once users switch haptics off at the OS level, the two
moments that earned it are gone forever.

If you are unsure whether something qualifies, apply §8.1: **name the tier and
the specific state change it confirms.** If you cannot, it does not ship.

---

## 1. Architecture

Four pieces. Build them in this order; each is useless without the one before.

```
widget / controller
    │   asks semantically:  haptics.taskCompleted()
    ▼
HapticsService  (interface)          lib/services/haptics/haptics_service.dart
    │
    ├── RealHapticsService  ─────►  HapticGovernor  ─────►  HapticPattern
    │                                 (§1.3)                 (§1.2)
    └── NoopHapticsService           suppression,           semantic → physical
        (web, tests, setting=off)    rate limit,            in ONE file
                                     coalescing
```

### 1.1 The service — follow seam 4

`lib/services/haptics/haptics_service.dart`

An `abstract interface class HapticsService` with **two** implementations,
mirroring the existing `MockXxxSource` / `ApiXxxSource` pairing the repo uses
everywhere (`README §7, seam 3`). Provided by a Riverpod provider that picks
the implementation, exactly like `tasksRepositoryProvider` does.

`NoopHapticsService` covers three cases at once:

- **Web.** iOS Safari has no Vibration API. Ship silence, not an approximation.
  Gate on `kIsWeb`.
- **Tests.** Widget tests must never depend on platform channels.
- **Setting = Off.**

### 1.2 The semantic vocabulary — one file, no physical names anywhere else

`lib/services/haptics/haptic_patterns.dart`

Widgets and controllers say `taskCompleted()`, `sessionFrozen()`, `detent()`.
They **never** say `HapticFeedback.mediumImpact()`. The whole semantic → physical
mapping lives in this one file so that retuning the app's entire feel is a
one-file diff, and so platform divergence resolves in one place.

This is the existing adapter-layer principle (`README §7, seam 2`) applied to
touch: same reason DTOs never leak into widgets.

```dart
// Sketch — the shape matters more than the exact constants.
enum HapticEvent {
  // Tier 1 — earned (5)
  taskCompleted, focusCompleted, streakMilestone, guestUpgraded, onboardingDone,
  // Tier 2 — confirmations (10)
  taskCreated, taskRescheduled, focusStarted, sessionFrozen, sessionResumed,
  sessionEndedEarly, moodLogged, subjectCreated, suggestionPosted, voteCast,
  // Tier 3 — detents (4)
  moodRampStep, wheelItem, sliderStop, segmentChange,
  // Tier 4 — warnings (3)
  destructiveConfirmed, saveFailed, guestWallHit,
}
```

**Tier 1 `focusCompleted` is the only composite in the app** (two beats, second
stronger). Nothing else gets a multi-part pattern — see spec §3.

### 1.3 The governor — everything routes through it

`lib/services/haptics/haptic_governor.dart`

Without this, haptics rots: every new feature adds a buzz and nobody sees the
aggregate. It enforces, in order:

1. **User setting** — Off / Essential / Full. Essential keeps only Tiers 1 & 4.
2. **Focus-session suppression** — spec §4.2. While `FocusStatus.running`,
   drop everything except the three user-initiated transitions (freeze, resume,
   end). This is the strictest rule in the document, and it also keeps haptics
   out of Prism's way.
3. **Minimum interval** — 40–60 ms floor between any two fires (§4.4).
4. **Fling suppression** — during a fast scroll, detents convey nothing and blur
   into a rattle. Drop them.
5. **Burst coalescing** — if three events land in one frame, fire the
   highest-tier one only.

The governor should be a plain testable class taking the current focus status
and setting as inputs — **not** reaching into providers itself. That keeps it
unit-testable without a widget tree (see §5).

### 1.4 The setting

Add to **`lib/features/settings/presentation/settings_sounds_screen.dart`**
(class `PrismSettingsScreen`), under a new `GroupLabel('Haptics')` next to the
existing **"In-app sounds"** group at ~line 122. Persist like the Prism volumes
do — see `services/sound_settings_service.dart` for the established
`SharedPreferences` pattern.

**It must sit under the OS accessibility setting, never override it.**

---

## 2. Sequence of work

Follow spec §9. Each stage is a separate PR — do not merge them as one.

| # | Stage | Why this order |
|---|---|---|
| 1 | **Long-press tick** | Functional defect (Finding 04), not a feel improvement. Ships alone, before any infrastructure. |
| 2 | **Service + vocabulary + governor + setting** | Skeleton first, so nothing lands ungoverned. **No events yet.** |
| 3 | **Tier 1 + Tier 2** (15 events) | Where the perceived quality jump happens. |
| 4 | **Tier 3 detents** | Wheels first — closes the Finding 03 expectation gap. Then sliders, then segments. |
| 5 | **The melt ramp** (§5) | A refinement of a system that must already be correct without it. |
| 6 | **Tier 4 warnings** | Fold in wherever error handling is already being touched. |

### Stage 1 in detail — do this first, alone

The only `onLongPress` in the app:

**`lib/features/plan/presentation/plan_screen.dart:478`**
```dart
child: GestureDetector(onLongPress: onOverflow, child: child),
```

A long-press with no haptic is **functionally broken** — the tick is how a user
learns the gesture exists and that it fired. Add
`HapticFeedback.selectionClick()` (or the Tier 3 detent once stage 2 lands) at
the top of `onOverflow`.

Ship it on its own. It needs no service, no setting, no governor.

---

## 3. Where every event actually fires

**This table replaces the "Fires from" column in spec §3.** Paths verified on
`main`.

### Tier 1 — earned moments (5)

| Event | Fire site |
|---|---|
| Task completed | `DayTasksController.toggleDone` — `features/plan/providers/plan_providers.dart` |
| Focus session completed | `FocusController.complete` — `data/repositories/focus_repository.dart:116` — **only when it reached its end naturally**, see §4 below |
| Streak milestone crossed | Stats read path — fire on the **crossing**, never on display. There is no controller for this today; you will need one, or a comparison against a persisted "last celebrated" value. |
| Guest upgraded to account | `ApiAuthRepository.verifyOtp` (`OtpType.email` branch) — `data/auth/auth_repository.dart` |
| Onboarding finished | `features/onboarding/providers/onboarding_controller.dart:174` — after `onboardingRepository.complete(...)` succeeds |

### Tier 2 — state confirmations (10)

| Event | Fire site |
|---|---|
| Task created | `add_task_screen.dart` `_save()` — after `repo.create` returns. There is **no** plan controller for create; it goes straight through the repository. |
| Task rescheduled | `DayTasksController.move` — `features/plan/providers/plan_providers.dart` |
| Focus session started | `FocusController.start` — `data/repositories/focus_repository.dart:83` |
| Session frozen | `FocusController.pause` — `:93` |
| Session resumed | `FocusController.resume` — `:99` |
| Session ended early | `FocusController.complete` — `:116`, when elapsed < planned |
| Mood logged | `features/plan/presentation/sheets/log_mood_sheet.dart` + `features/mood/presentation/mood_*_screen.dart` on commit |
| Subject created | `features/subjects/` — creation goes through `subjectsRepository`; fire after it resolves |
| Suggestion posted | `features/feedback/providers/feedback_providers.dart` — `submit(...)` |
| Vote cast | same file — `toggleVote(...)` |

### Tier 3 — detents (4) — **widgets, not controllers**

Per spec §6.3 these are the sole exception: a detent *is* the interaction.

| Event | Fire site |
|---|---|
| Mood ramp step | `features/mood/presentation/mood_morning_screen.dart` — the `onSelect` at `:105` / `:134`. Also the evening screen and `log_mood_sheet.dart`. |
| Wheel picker item | `features/plan/presentation/pickers/time_picker.dart` and `features/plan/presentation/sheets/month_picker_sheet.dart` — both are `ListWheelScrollView`, which **does not self-haptic** (a `CupertinoPicker` would). Fire on `onSelectedItemChanged`. |
| Discrete slider stop | 9 `Slider(` call sites — focus duration, task duration, Prism volumes. Fire on **detent only**, never per pixel. |
| Segment / tab change | `features/shell/presentation/app_shell.dart` `_onTap` — **only on an actual change**, never on re-tap of the active tab. |

### Tier 4 — warnings (3)

| Event | Fire site |
|---|---|
| Destructive confirmed | Delete handlers: `DayTasksController.delete`, subjects/semesters delete, `showDeleteAccountDialog` |
| User-initiated save failed | Only where the user explicitly submitted. **Never** a background refetch. |
| Guest-locked wall hit | `core/error/` — where 403 maps to the account prompt |

---

## 4. The traps specific to this codebase

### 4.1 Focus completion already marks the task done — do not double-fire

Spec §4.3's sharpest case, and it is live here. `FocusController.complete` →
`POST /focus-sessions/:id/complete` → the **server** calls
`tasksService.setDone` (see `focus.service.ts`).

Today that is **already safe**: the server does it, so the client's
`toggleDone` — where the task-completed haptic will live — is never called.
**Do not break that.** If you ever add a client-side `toggleDone` call to the
focus completion path, you will get two haptics for one user action.

One user action, one haptic, even when it causes two state changes internally.

### 4.2 Optimistic controllers fire on the *outcome*, not the tap

`DayTasksController.toggleDone`, `.move` and `.delete` are **optimistic with
rollback** — they set state, call the repo, and revert on failure. Per spec
§2.1, the haptic confirms the outcome:

- Fire **after** the repository call succeeds, or
- fire optimistically **and** fire `saveFailed` (Tier 4) on the rollback.

Pick one and apply it consistently. Do not fire on entry and stay silent on
rollback — that teaches the hand a lie.

### 4.3 Do not retrofit the 170 GestureDetectors

Spec §4.1. The 22 events above are the whole list. The other ~148 taps stay
inert forever.

Converting some `GestureDetector`s to `InkWell` for a visual ripple is a
legitimate argument — **but it is a different PR.** Do not let it ride along.

### 4.4 Web must be a real no-op

`kIsWeb` → `NoopHapticsService`. The app is run in Chrome for testing
(`flutter run -d chrome`), so this path is exercised constantly. iOS Safari has
no Vibration API — ship silence, not a degraded approximation.

---

## 5. Testing

The governor is the part worth testing, and it is testable precisely because
§1.3 keeps it free of providers.

`test/haptics_governor_test.dart` — assert the rules that fail *silently*:

- Nothing fires while `FocusStatus.running`, **except** freeze / resume / end.
- Two events 10 ms apart → one fires (40–60 ms floor).
- Setting = Essential → Tier 2 and Tier 3 are dropped, Tiers 1 and 4 survive.
- Setting = Off → nothing fires, ever.
- A burst in one frame → only the highest tier fires.
- Re-tapping the active tab → no `segmentChange`.

Then the two-line integration check that catches the classic regression:

- A fake `HapticsService` recording calls, driven through
  `FocusController.complete` → asserts **exactly one** event, not two (§4.1).

Existing conventions to copy: `test/breakdown_toggle_test.dart` shows the
recording-fake pattern (`_RecordingRepo`), and
`test/focus_end_submits_test.dart` shows driving a controller with an overridden
provider.

Run: `flutter test` · `flutter analyze` (must stay at its current 5 pre-existing
infos — do not add any).

---

## 6. Per-screen budgets

Copy spec §7 verbatim into the PR description. The budget is the artefact that
stops this rotting in eighteen months — a hard cap on **distinct event types
reachable from each screen**.

Exceeding a budget means **removing something**, not raising the number.

Highest-risk screens in this codebase:

- **Focus (budget 4)** — everything during the run is explicitly zero. No tick
  counts, no minute boundaries, no Prism mode changes.
- **Plan (budget 4)** — day navigation, view switching, collapse toggles and
  timeline scrolling are all zero, and Plan is the screen with the most
  `GestureDetector`s.
- **Ada (budget 1)** — message send, message arrival and streaming tokens are
  all zero. Only "Plan my week" applied to the plan fires.

---

## 7. Review protocol

Spec §8.2, and it is not optional:

1. **Screen dimmed, sound off.** If you cannot tell what happened from the
   haptic alone in context, it is noise you have grown used to.
2. **Then a cheap Android handset** — never only an iPhone. Flutter's constants
   collapse to near-identical output on weak motors.

The hardware constraint that keeps the design honest: **meaning must never
depend on discriminating two similar patterns.** Context carries the meaning;
the ramp adds richness only where the hardware can express it. Design so that
losing the ramp entirely still leaves a correct, legible system.

---

## 8. Working with Claude Code on this

- **Give it the spec and this file together.** The spec carries the reasoning,
  this one carries the paths. With only one of them it will either invent file
  locations or lose the *why* behind §4.
- **One stage per session** (§2). Stage 2 in particular should land with *zero*
  events wired — ask it to resist adding "just one" to prove the skeleton.
- **Ask it to justify every call site against §8.1** — name the tier and the
  state change. That rule rejects decorative haptics at proposal time rather
  than after they are built.
- **Have it re-run the audit** before starting, since these counts will drift:
  ```sh
  grep -rn "HapticFeedback" --include=*.dart lib/ | wc -l   # expect 0 before stage 1
  grep -rno "GestureDetector(" --include=*.dart lib/ | wc -l
  grep -rn "onLongPress" --include=*.dart lib/
  ```
- **Do not let it convert GestureDetectors to InkWell** as part of this work
  (§4.3). It is a reasonable idea and the wrong PR.
