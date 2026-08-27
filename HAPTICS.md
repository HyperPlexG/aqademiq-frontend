# Haptics

Implementation of **Aqademiq · Haptic feedback specification · v1 ("The Melt
Ramp")** and its companion guide, [`docs/HAPTICS_IMPLEMENTATION.md`](docs/HAPTICS_IMPLEMENTATION.md).

The spec says *what* and *why*; the guide says *where*. This file says **what
was actually built**, which stage each file belongs to, and the six places the
two documents disagreed or ran out of road. Read the guide first — nothing here
repeats its reasoning either.

---

## 1. The four pieces

```
widget / controller
    │   asks semantically:  haptics.taskCompleted()
    ▼
HapticsService  (interface)                lib/services/haptics/haptics_service.dart
    │
    ├── RealHapticsService ──► HapticGovernor ──► playHapticEvent
    │                          haptic_governor.dart   haptic_patterns.dart
    └── NoopHapticsService     suppression,           semantic → physical
        (web, setting=off)     rate limit,            in ONE file
                               coalescing
```

| File | Role |
|---|---|
| `lib/services/haptics/haptic_patterns.dart` | The 23 events, their tiers, and the **only** place a physical haptic is named. |
| `lib/services/haptics/haptic_governor.dart` | The five rules. A plain class taking setting / focus status / reduce-motion as inputs. |
| `lib/services/haptics/haptics_service.dart` | The interface, the no-op, the real one, and `hapticsProvider`. |
| `lib/services/haptics/haptic_settings_service.dart` | SharedPreferences, mirroring `sound_settings_service.dart`. |
| `lib/features/settings/providers/haptic_settings_provider.dart` | Off / Essential / Full as a Riverpod notifier. |
| `lib/features/stats/providers/streak_milestone_provider.dart` | The controller the guide said would be needed for the streak. |

**The rule for adding a haptic:** name the tier and the specific state change it
confirms (§8.1). If you cannot, it does not ship. There is no `HapticFeedback`
import anywhere outside `haptic_patterns.dart`, and there should never be one.

---

## 2. Stage map

The guide asks for six PRs, one stage each. Everything below is in the working
tree; this is how to cut it apart.

### Stage 1 — the long-press tick (Finding 04, ships alone)
- `lib/features/plan/presentation/plan_screen.dart` — `_overflow`

Standalone version, if you want to land this before any infrastructure:
```dart
// at the top of _overflow, with `package:flutter/services.dart` imported
HapticFeedback.selectionClick();
```

### Stage 2 — service, vocabulary, governor, setting (no events)
- all six files in the table above
- `lib/main.dart` — `HapticSettingsService.instance.init()`
- `lib/features/settings/presentation/settings_sounds_screen.dart` — the
  `GroupLabel('Haptics')` group and its picker sheet
- `test/haptics_governor_test.dart`

### Stage 3 — Tier 1 + Tier 2 (15 events)
- `lib/features/plan/providers/plan_providers.dart` — completed, rescheduled
- `lib/features/plan/presentation/add_task_screen.dart` — created
- `lib/features/plan/presentation/plan_screen.dart` — quick-add created, mood logged
- `lib/data/repositories/focus_repository.dart` — started, frozen, resumed, ended, completed
- `lib/features/focus/presentation/timer_screen.dart` — comment only (the §4.1 guard)
- `lib/features/mood/presentation/mood_*_screen.dart` — logged
- `lib/features/stats/presentation/stats_screen.dart` — logged
- `lib/data/repositories/subjects_repository.dart` — subject / semester created
- `lib/features/feedback/providers/feedback_providers.dart` — posted, voted
- `lib/features/auth/controllers/auth_controller.dart` — guest upgraded
- `lib/features/onboarding/providers/onboarding_controller.dart` — finished
- `lib/features/stats/providers/streak_milestone_provider.dart` + `lib/app.dart`
- `lib/features/ada/presentation/ada_screen.dart` — plan applied
- `test/haptics_focus_once_test.dart`

### Stage 4 — Tier 3 detents (wheels first)
- `lib/features/plan/presentation/pickers/time_picker.dart` — wheel
- `lib/features/plan/presentation/sheets/month_picker_sheet.dart` — wheel
- `lib/features/plan/presentation/pickers/duration_picker.dart` — slider
- `lib/features/focus/presentation/sheets/focus_duration_dialog.dart` — slider
- `lib/features/settings/presentation/settings_sounds_screen.dart` — volume sliders
- `lib/features/shell/presentation/app_shell.dart` — tab change
- `lib/features/mood/presentation/mood_*_screen.dart`,
  `lib/features/plan/presentation/sheets/log_mood_sheet.dart` — ramp steps
- `lib/features/plan/presentation/plan_screen.dart` — upgrade Stage 1's raw call
  to `haptics.longPressTick()`

### Stage 5 — the melt ramp
Contained entirely in `haptic_patterns.dart` (`_moodRamp`, `sessionFrozen`
stepping above the light single, `sessionEndedEarly` staying soft).

### Stage 6 — Tier 4 warnings
- `lib/features/plan/providers/plan_providers.dart` — delete, rollbacks
- `lib/features/plan/presentation/add_task_screen.dart` — save failed
- `lib/features/auth/controllers/auth_controller.dart` — `_run` failure
- `lib/data/repositories/subjects_repository.dart` — deletes
- `lib/features/settings/presentation/settings_home_screen.dart` — delete account
- `lib/features/feedback/presentation/sheets/create_account_prompt.dart` — guest wall

---

## 3. Per-screen budgets (spec §7)

Copy into the PR description. Exceeding a budget means **removing** something.

| Screen | Budget | Permitted | Explicitly zero |
|---|---|---|---|
| Focus | 4 | started · frozen · resumed · ended/completed | everything during the run |
| Plan | 4 | completed · created · rescheduled · long-press detent | day nav, view switch, collapse, scroll |
| Mood | 2 | ramp detent · logged | sheet open/close, note typing |
| Onboarding | 2 | completion · consent confirm | all eleven step advances |
| Subjects | 2 | created · destructive confirm | master-detail nav, file attach, sort |
| Feedback | 2 | vote · posted | board scroll, filter, sort, open detail |
| Auth | 2 | guest upgrade · auth failure | per-digit OTP, SSO button taps |
| Settings | 2 | slider detent · destructive confirm | toggles, theme, panel nav |
| Pickers | 1 | wheel or slider detent | confirm / cancel |
| Stats / Profile | 1 | streak milestone crossed | everything else |
| Ada | 1 | "Plan my week" applied | send, arrival, streaming, history |
| Shell | 1 | tab change | re-tapping the active tab |

---

## 4. Decisions the documents left open

Six places where the spec and the guide disagreed, or stopped short. Each is
also commented at the code site.

1. **Reduce-motion (spec §6.5 vs guide §0.1).** The spec claims the app already
   respects `prefers-reduced-motion`; the audit proves it does not — zero
   references to `disableAnimations` anywhere. Resolved by **honouring it**: the
   governor takes `reducedMotion` and clamps Full down to Essential. Read from
   `PlatformDispatcher.instance.accessibilityFeatures` rather than a
   `MediaQuery`, because most events fire from controllers with no
   `BuildContext` — and because the platform dispatcher is the OS's answer,
   which is what "must sit **under** the OS setting" actually means.

2. **A 23rd event.** Spec §3 lists 22 and its Tier 3 table has four detents, but
   §7's Plan budget spends one of Plan's four on a "long-press overflow detent",
   and Finding 04 calls the long-press tick the highest-priority fix in the
   document. Added `HapticEvent.longPressTick` — physically the same uniform
   Tier 3 tick, named separately so the call site can say what happened rather
   than claim a segment changed.

3. **Composites.** Spec §3 draws ascending pairs for the streak and onboarding
   events and two even beats for a destructive confirm. Guide §1.2 says
   `focusCompleted` is the *only* multi-part pattern in the app. Followed the
   guide; spec §5 backs it — meaning must never depend on discriminating two
   similar patterns, so those collapse to single impulses and lose nothing that
   was carrying meaning.

4. **Optimistic rollback (guide §4.2).** The guide offers two coherent policies
   and demands consistency. Picked *fire after the repository succeeds*, applied
   to all three of `toggleDone` / `move` / `delete`, with Tier 4 `saveFailed` on
   the rollback. Never fire on entry and stay silent on rollback — that teaches
   the hand a lie.

5. **The guest wall.** Guide §3 points at `core/error/`. Nothing there maps a
   403: `failure.dart` only declares types, and `core/network/api_error.dart`
   collapses 401 and 403 into one `AuthFailure` for *every* failed request,
   background refetches included. Firing there would break §4.3, so it fires in
   `showCreateAccountPrompt` — reached only when a guest hits a wall on
   something they deliberately tried.

6. **The streak.** No controller existed, as the guide predicted. Built one with
   a persisted watermark (so a milestone fires once per install, not once per
   recompute) and a session baseline (so launching with an existing 30-day
   streak does not buzz on the splash screen — §4.5). The ladder — 3, 7, 14, 30,
   50, 100, 200, 365 — is chosen, not specified.

### Deliberately not done

- **SSO failures** stay silent. `_run` covers every email-based submission
  (sign-in, sign-up, verify, reset), which is Auth's budgeted "auth failure".
  The Apple/Google paths hand control to the platform's own sheet, §7 names
  "SSO button taps" as explicitly zero, and adding three call sites inside the
  method that fixed App Review 7d5244b9 is exactly the ride-along guide §4.3
  warns about.
- **The onboarding peak-time slider** gets no detent. The guide names three
  slider families (focus duration, task duration, Prism volumes) and Onboarding's
  budget of 2 is spent on completion and consent — §4.6 puts step-level feedback
  at zero.
- **170 → 17 `GestureDetector` → `InkWell` conversions.** A legitimate argument
  and a different PR (§4.3).
- **Sub-task ticks, day navigation, view switching, sheet open/close, typing,
  toasts, app launch, stat views.** All §4.

---

## 5. Testing

```sh
flutter test test/haptics_governor_test.dart
flutter test test/haptics_focus_once_test.dart
flutter test test/haptics_tab_change_test.dart
flutter analyze
```

Between them these cover every rule guide §5 lists.

`haptics_governor_test.dart` asserts the rules that fail *silently*: the setting
ladder, the reduce-motion clamp, focus-session suppression (including that
`focusStarted` is **not** exempt), the 40–60 ms floor, burst coalescing, and
fling suppression.

`haptics_focus_once_test.dart` is the integration check guide §5 asks for:
`FocusController.complete()` runs twice on the end-early path and not at all on
the natural one, so a fake `HapticsService` proves exactly one event per
session, never two and never none.

`haptics_tab_change_test.dart` covers the one §5 rule that is not a governor
rule — re-tapping the active tab is a real interaction that simply is not a
*change*, so the guard sits in `AppShell._onTap` and needs a widget test to
pin it.

Widget tests do not need an override — `playHapticEvent` swallows platform
errors, which covers a device with no motor, a desktop embedder, and a test with
nothing behind `flutter/platform` alike. Tests that want to *assert* on haptics
should override `hapticsProvider` with a recorder, as those two files do.

### Review protocol (spec §8.2, not optional)

1. **Screen dimmed, sound off.** If you cannot tell what happened from the
   haptic alone in context, it is noise you have grown used to.
2. **Then a cheap Android handset**, never only an iPhone. Flutter's constants
   collapse to near-identical output on weak motors — which is why nothing here
   depends on telling two similar patterns apart.
