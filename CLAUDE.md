# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Aqademiq** is a student-planning Flutter app built around **Ada** (an AI planner
mascot drawn as a melting ice-cube, `lib/shared/mascot/`) and **Prism** (a
focus-audio companion, `lib/sound_engine/`). V1 ships with **Guest Mode** — core
features work before account creation; onboarding/account is prompted
contextually. Scope is 88 frames / 11 sections tracked in `FRAMES.md`.

The prototypes in `prototypes/*.html` are the **visual source of truth** (design
reference only — never transliterate their web markup into Dart). Deep references:
`README.md` (the full handoff brief), `docs/ARCHITECTURE.md` (module-by-module
map), `docs/DESIGN_SYSTEM.md`, and the per-section specs in `docs/specs/`.

## Commands

```sh
flutter pub get                 # install deps
flutter run                     # runs on mocks by default (Env.useMocks=true)
flutter analyze                 # must be clean (very_good_analysis ruleset)
dart format .
flutter test                    # all tests
flutter test test/adapters_test.dart              # a single file
flutter test --plain-name "maps FeedbackPostDto"  # a single test by name

# Codegen — REQUIRED after editing any freezed / json_serializable model or DTO
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # continuous

# Run against the live backend instead of mocks:
flutter run --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=http://localhost:8080/v1 \
  --dart-define=SOCKET_URL=http://localhost:8080

# Release builds MUST pass the defines, or config silently goes missing:
flutter build ipa --dart-define-from-file=dart_defines.json
```

`dart_defines.json` is **gitignored**, so it does not travel with a clone or a
merge — every machine that builds a release needs its own copy, including the
Mac you archive from. `dart_defines.example.json` (tracked) lists every required
key and what breaks without it. A missing key never fails the build, it just
changes behaviour: an absent `GOOGLE_IOS_CLIENT_ID` left the Google button
visible but unable to present its sheet, which wedged the sign-in screen and got
the app rejected (App Review 7d5244b9).

`*.freezed.dart` / `*.g.dart` are generated (git-tracked). If analyze/build
complains about missing generated members, re-run build_runner before editing.

## Architecture — the four seams

Feature-first, layered. The whole app runs on **mock data** by default; the live
backend is swapped in per-repository via a compile-time flag. Everything hinges
on four seams (README §7) — respect them when adding features:

1. **Provider boundary** — widgets in `features/*/presentation/` read state only
   via `ref.watch(...)` providers returning `AsyncValue`. They **never** import
   Dio, a DTO, or a source. Handle loading/empty/error with `AsyncValue.when`.
2. **Adapter layer** — `data/adapters/` maps DTO ⇄ UI model (`.toModel()` /
   `.toDto()`). Schema drift is a one-file fix here, not a change across screens.
3. **Mock == real** — each `data/sources/XxxSource` is an `abstract interface`
   with a `MockXxxSource` (delayed fixtures from `data/fixtures/`, can throw) and
   an `ApiXxxSource` (Dio). `data/repositories/XxxRepository` picks one via
   `Env.useMocks` in its provider. Both behave identically (filtering/sorting/
   paging live in the mock too), so loading/error UI is real today.
4. **Auth behind the interceptor** — `core/network/dio_client.dart` builds the
   shared Dio; `AuthInterceptor` attaches the Bearer token from `TokenStore`
   (`core/auth/`, secure storage), adds an `Idempotency-Key` on mutations, and
   does a single-flight refresh-and-retry once on 401. Tokens/RLS are
   server-side; the client only carries the token.

Data flow: **widget → provider (`features/*/providers`) → repository → source
(mock | Dio) → adapter → model → provider → widget.** Mutations may go through
`features/*/controllers`. Routing is a go_router 5-tab `StatefulShellRoute` in
`core/router/app_router.dart`. Design tokens live in `core/theme/`; shared design-
system widgets in `shared/widgets/`.

### Conventions

- **JSON is snake_case in both directions** — no case transform in Dio; DTOs map
  fields explicitly. The live API is under a `/v1` prefix baked into the base URL.
- Errors: sources map non-2xx to typed `Failure` subtypes (`core/error/`),
  surfaced to the UI (e.g. 403 → prompt account, 409 → locked, 429 → rate limit).
- Prefer `const`; scope `ref.watch`/use `select` to avoid rebuilds; lists are
  lazy. Relative imports within `lib/` (not package imports) — matches the lints.
- New feature = folder under `lib/features/<name>/` with `presentation/`,
  `providers/`, and (if it mutates) `controllers/`; its data goes through a new
  `data/sources` + `data/repositories` pair with both mock and API impls.

## Notifications: two paths, one plugin

Reminders can arrive two ways, and both render through the **single**
`FlutterLocalNotificationsPlugin` owned by `services/local_notifications.dart`.
`initialize()` is global state, so never construct a second instance — whichever
initialised last silently wins.

- **Server push** (`services/push_service.dart`) — FCM token → `POST /devices`;
  the backend's `pg_cron` sweep sends. It only ever implemented `before_task`
  and has not been delivering reliably.
- **Client-side schedule** (`services/reminder_scheduler.dart`) — the default,
  gated by `Env.localReminders` (`--dart-define=LOCAL_REMINDERS=false` disables
  it once server push is verified, so the two can't double-notify). Covers all
  seven channels the Notifications screen offers, needs no account, and works in
  Guest Mode.

The scheduler **reconciles**; it does not fire-and-forget. Every trigger
(sign-in, app resume, a task mutation, a revision bump, a notification-settings
change) re-derives the whole desired schedule from current state and diffs it
against `pendingNotificationRequests()`. Things to preserve when touching it:

- `planTaskReminders` / `planCheckIns` are pure and are the tested surface
  (`test/reminder_scheduler_test.dart`) — keep IO out of them.
- Notification ids must stay deterministic (`reminderIdFor`), so re-scheduling an
  unchanged task replaces its pending entry rather than duplicating it.
- Never `cancelAll()` — it also clears notifications already on screen. Cancel
  only pending ids that are no longer wanted.
- A failed task/prefs load aborts the pass rather than applying an empty
  schedule; otherwise opening the app offline would wipe the week.
- iOS drops pending local notifications past 64, hence `maxTaskReminders` and
  the repeating (not materialised) check-ins.
- `reminderLead` mirrors `REMINDER_LEAD_MS` in the backend's `tasks.service.ts`.

Android needs `RECEIVE_BOOT_COMPLETED` plus the two
`flutter_local_notifications` receivers in `AndroidManifest.xml` or the schedule
dies on reboot. Scheduling is deliberately **inexact** — exact alarms need
`SCHEDULE_EXACT_ALARM`, which triggers a Play Store policy review.

## Ambient surfaces: one state object, four renderers

A focus session is the one thing the app keeps doing while it is closed, so the
lock screen, the Dynamic Island, the home-screen widgets and the Android
notification are not marketing surfaces — they are the session, drawn somewhere
else. `services/ambient/` owns that, and the rules below are load-bearing.

- **The clock is free; only Ada costs.** Both platforms render a countdown from
  an absolute `endsAt` with the app asleep (Android `setUsesChronometer` +
  `setChronometerCountDown`, iOS `Text(timerInterval:)`). Never push a
  per-second update. `AmbientSession.differsMateriallyFrom` encodes the budget:
  a melt stage, a freeze, or a change of task earns a redraw; a second passing
  does not. `test/ambient_service_test.dart` walks all 1500 seconds of a
  25-minute session and asserts at most six pushes.
- **Freeze is a material change.** `FocusSession.frozenAt` separates held time
  from spent time, and resume pushes `endsAt` forward by the whole hold. A
  system countdown cannot be paused, so every frozen surface swaps the live
  timer for static `remaining` text — unhandled, a frozen session keeps counting
  down on a lock screen, which is worse than not shipping the surface.
- **The Island is for a running session and nothing else.** Never a due task,
  never a streak. No session, no activity.
- **One Ada, three renderers.** She is a Flutter `CustomPainter`, and Flutter
  cannot render in a WidgetKit extension, so `ios/AmbientWidgets/AdaShape.swift`
  repeats the same interpolation with the coefficients quoted in its header.
  Change one and change both.
- **What crosses the boundary** is one small flat object (`ambient_state.dart`
  ⇄ `AmbientState.swift`), through an App Group on iOS and shared prefs on
  Android. No models, no network, no images — the extension is never asked to
  think.
- **Never guilt.** No decaying streak, no "you haven't studied today", no red. A
  missed day is an empty outline, never a puddle: absence is not depletion. The
  Live Activity is ambient and never alerts.

iOS specifics: the extension target is created by `ios/add_widget_target.rb`,
which is idempotent and checked in because a lost target still builds — it just
silently stops shipping the lock screen. It also keeps "Embed Foundation
Extensions" ahead of Flutter's "Thin Binary" phase, without which the build
fails with "Cycle inside Runner". The app's deployment target stays where it is;
only the extension is modern (16.1) and everything inside is availability gated.

Android specifics: `AmbientSessionService` is the single `mediaPlayback`
foreground service. It both holds the process up through a screen-off session
(what `FocusKeepaliveService` used to do, now a no-op seam) and owns the session
card — Android makes every foreground service post a notification, so two
services would mean two entries in the shade for one session.

Widgets deep-link through `aqademiq://` and speak in intent (`focus`, `plan`,
`stats`), not route strings, so renaming a route cannot break a widget already
installed on someone's home screen.

## Backend integration status

Wired end-to-end behind the seams (mock + `ApiXxxSource`): tasks, subjects, tags,
focus, mood, ada, profile, onboarding, **feedback**. The live contract lives in
`backend_contract/` (`openapi.json`, `FRONTEND_INTEGRATION_CONTRACT.md`).
Per-feature wiring notes: `FEEDBACK_BOARD_INTEGRATION.md`,
`ONBOARDING_CONSENT_AGE_INTEGRATION.md`, `INTEGRATION.md`. `socket_io_client`
(focus ticks/presence via `data/realtime/`) is reserved but not yet wired.
