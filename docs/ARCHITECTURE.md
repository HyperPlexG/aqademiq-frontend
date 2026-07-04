# Aqademiq — Architecture & Reference

> Auto-generated codebase reference. High-level architecture plus low-level
> module details for onboarding and future work. Grounded in the code under
> `lib/`; file paths are clickable so this doubles as a navigation map.

## 1. Overview

- **Purpose:** Aqademiq is a student-planning Flutter app built around **Ada**
  (an AI planner mascot rendered as a melting ice-cube) and **Prism** (a
  focus-audio companion). Students plan their week, run timed focus sessions,
  track subjects, chat with Ada, and log mood. **V1 ships with Guest Mode** —
  core features work before account creation; onboarding/account is prompted
  contextually. Scope is 88 frames across 11 sections (see `FRAMES.md`).
- **Tech stack:** Flutter + Dart (SDK `^3.11.0`, null-safe), with:
  - **flutter_riverpod ^3.3.2** — state management (`AsyncValue`, `Notifier`,
    `AsyncNotifier`).
  - **freezed ^3.2.5 + json_serializable** — immutable models & DTOs via codegen.
  - **dio ^5.9.2** — HTTP client (wired to the live backend in a later pass).
  - **go_router ^17.3.0** — routing + the 5-tab `StatefulShellRoute` shell.
  - **socket_io_client ^3.1.6** — reserved for focus ticks / presence (§8, not
    yet wired).
  - **google_fonts** (Plus Jakarta Sans / Playfair Display), **flutter_slidable**
    (swipe actions), **share_plus**, **url_launcher**.
  - **very_good_analysis ^10.2.0** — lint ruleset (see `analysis_options.yaml`).
- **Current build state:** The app runs **entirely on in-memory mock data**
  (`Env.useMocks` defaults to `true`). All UI, navigation, and state flows are
  built and functional; the real Google Cloud backend (NestJS/Cloud Run, Cloud
  SQL, Redis, Vertex AI) is stubbed behind interfaces and wired later. See §8 of
  the root `README.md` for the integration plan.
- **Repository layout (top level):**
  - `lib/` — all app code (see §4).
  - `test/` — unit + widget tests (`adapters_test.dart`, `widget_test.dart`).
  - `docs/` — this file, `DESIGN_SYSTEM.md`, `BUGS.md`, `BUG_FIX_PLAN.md`, and
    `docs/specs/` (per-section behavior specs + `flow-map.md`).
  - `prototypes/` — hi-fi HTML design references (the visual source of truth;
    not shipped code).
  - `backend_contract/` — drop-zone for the NestJS `openapi.json` (§8).
  - `assets/images/` — bundled images (e.g. `logo.png`).
  - `android/`, `ios/`, `macos/` — platform runners.
  - Root docs: `README.md` (the build handoff), `FRAMES.md` (88-frame
    checklist), `INTEGRATION.md` (screen→endpoint map, stubbed),
    `PROTOTYPE_SPECS.md`.

## 2. Getting Started

Prerequisites: the Flutter SDK (Dart `^3.11.0`).

```sh
flutter pub get

# Codegen for freezed / json_serializable (regenerate after model/DTO edits):
dart run build_runner build --delete-conflicting-outputs

# Run on mocks (default — no backend required):
flutter run

# Static analysis (very_good_analysis) + tests:
flutter analyze
flutter test
```

**Live backend (later, §8 pass)** — flip mocks off via compile-time defines:

```sh
flutter run --dart-define=USE_MOCKS=false \
  --dart-define=API_BASE_URL=https://api.aqademiq.app \
  --dart-define=SOCKET_URL=https://rt.aqademiq.app \
  --dart-define=GCS_BUCKET=<bucket>
```

Config is read in `lib/core/env/env.dart` (`Env.useMocks`, `Env.apiBaseUrl`,
`Env.socketUrl`, `Env.gcsBucket`). No secrets live in the app; only an auth ID
token will travel with requests once auth is wired.

## 3. High-Level Architecture

**Style:** feature-first, layered Flutter app with a strict **provider →
repository → source** data flow and four deliberate "seams" that isolate the UI
from backend churn (documented in `README.md` §7). The UI is fully
presentational and never touches Dio or DTOs.

### The four seams

1. **Provider boundary** — widgets read only `ref.watch(xProvider)`; they never
   import Dio or a DTO. (`lib/features/*/providers`, `lib/features/*/controllers`)
2. **Adapter layer** — DTO→UI-model (and reverse) mapping lives in one file,
   `lib/data/adapters/adapters.dart`. Schema drift is a one-file fix.
3. **Mock sources behave like real ones** — `MockXxxSource` returns fixtures
   after a real delay (`lib/data/sources/mock_latency.dart`) so loading/error UI
   is exercised now. `Env.useMocks` (a `--dart-define`) flips the whole app to
   the `ApiXxxSource` implementations.
4. **Auth behind an interface** — `AuthRepository` with a mock impl
   (`lib/data/auth/auth_repository.dart`); guest/OTP/link swap to Identity
   Platform later without touching consumers.

### Layer / data-flow diagram

```mermaid
flowchart TD
  W["Widgets / Screens<br/>(features/*/presentation)"] -->|ref.watch| P["Providers & Controllers<br/>(features/*/providers, controllers)"]
  P -->|calls| R["Repositories<br/>(data/repositories, data/auth)"]
  R -->|chooses via Env.useMocks| S["Sources<br/>(data/sources)"]
  S -->|Mock| F["Fixtures (in-memory)<br/>(data/fixtures)"]
  S -.->|Api (later)| D["Dio → NestJS/Cloud Run<br/>(core/network)"]
  R -->|DTO↔Model| A["Adapters<br/>(data/adapters)"]
  A --> M["UI Models (freezed)<br/>(data/models)"]
  P -->|exposes AsyncValue<Model>| W
```

**Runtime flow (mock mode, today):** a screen watches a provider → the provider
asks a repository for UI models → the repository asks its `Source` (mock) →
the mock returns fixture DTOs after a delay → the repository maps DTO→model via
adapters → the provider surfaces `AsyncValue<Model>` → the widget renders
loading/data/error via `AsyncValue.when`.

**External integrations (planned, not yet wired — see `README.md` §8 and
`INTEGRATION.md`):** NestJS REST on Cloud Run (Dio), Identity Platform auth
(`firebase_auth`), Cloud SQL Postgres (RLS + pgvector), Memorystore Redis +
Socket.IO (focus ticks/presence), GCS signed-URL uploads, Cloud
Tasks/Eventarc/Pub/Sub (async), Ada via Vertex AI (Claude) behind a server
endpoint.

## 4. Module Reference

### `lib/` (entry)

- **Responsibility:** app bootstrap.
- **Key files:**
  - `main.dart` — `runApp(ProviderScope(child: AqademiqApp()))`.
  - `app.dart` — `AqademiqApp` (`ConsumerWidget`) builds `MaterialApp.router`,
    wiring `routerProvider`, light/dark themes (rebuilt on accent change), and
    `themeMode`.

### `lib/core`

- **Responsibility:** cross-cutting infrastructure with no feature knowledge.
- **Key files:**
  - `core/env/env.dart` — `Env`: compile-time `--dart-define` config
    (`useMocks`, `apiBaseUrl`, `socketUrl`, `gcsBucket`, `hasLiveConfig`). The
    master mock/live switch.
  - `core/router/app_router.dart` — `Routes` (all path constants) and
    `routerProvider` (`GoRouter`). Full-screen routes (auth, onboarding, guest
    prompts, add-task, focus-end, settings, mood) plus a
    `StatefulShellRoute.indexedStack` with 5 branches.
  - `core/network/dio_client.dart` — `dioProvider` (base `Dio`). Interceptors
    (auth token, retry, Cloud Trace) are TODO for the §8 pass.
  - `core/error/failure.dart` — sealed `Failure` hierarchy: `NetworkFailure`,
    `ServerFailure`, `AuthFailure`, `SerializationFailure`, `NotFoundFailure`,
    `UnknownFailure`. The single typed error surface.
  - `core/theme/` — design tokens as a theme:
    - `app_colors.dart` — `AppColors` theme extension (light/dark palettes,
      `AppAccent` enum), read via `context.colors`.
    - `app_theme.dart` — `buildAppTheme(brightness, accent)` → `ThemeData` with
      Plus Jakarta Sans text theme + `AppColors` extension.
    - `theme_controller.dart` — `themeModeProvider` (Light/Dark/System) and
      `accentProvider` (violet/pink/green). In-memory today.
    - `app_text.dart`, `app_spacing.dart`, `app_radius.dart` — type, spacing,
      radius scales.
  - `core/utils/` — `hex_color.dart`, `date_format.dart`,
    `launch_external.dart`.

### `lib/data`

- **Responsibility:** the entire data layer — models, DTOs, mapping, sources,
  repositories, auth, fixtures.
- **Sub-modules:**
  - `data/models/` — freezed **UI models** widgets consume: `Task`
    (+`Subtask`, `RepeatRule`), `Subject` (+`Semester`, `SubjectTarget`),
    `FocusSession`, `MoodLog`, `AdaMessage`, `AppUser`, `UserProfile`,
    `UserStats`, `Tag`. Plain shared enums live in `enums.dart` (`DayPart`,
    `RepeatFrequency`, `SubjectTargetKind`, `FocusStatus`, `MoodPhase`,
    `AdaRole`) — kept codegen-free so anything can import them.
  - `data/dtos/` — freezed **API DTOs** (`*_dto.dart` + `.freezed.dart` +
    `.g.dart`) mirroring the wire shape. Generated from the OpenAPI spec later.
  - `data/adapters/adapters.dart` — **seam 2.** Extension methods
    (`TaskDtoX.toModel`, `TaskX.toDto`, …) mapping every DTO↔model, with a
    tolerant `_enumByName` fallback so unknown wire values don't crash.
  - `data/sources/` — **seam 3.** Per-domain `abstract interface class XxxSource`
    with a `MockXxxSource` (in-memory, delayed via `mock_latency.dart`) and an
    `ApiXxxSource` (Dio-backed, currently throws `UnimplementedError`). Domains:
    tasks, subjects, focus, mood, ada, profile, tags.
  - `data/repositories/` — repositories that pick the source via `Env.useMocks`,
    map through adapters, and expose UI models: `tasks_repository.dart`,
    `subjects_repository.dart`, `focus_repository.dart`, `mood_repository.dart`,
    `ada_repository.dart`, `profile_repository.dart`, `tags_repository.dart`.
    Each ends with a Riverpod `Provider<XxxRepository>`.
  - `data/auth/auth_repository.dart` — **seam 4.** `AuthRepository` interface +
    `MockAuthRepository` (starts as a guest). Exposes `authRepositoryProvider`,
    `authStateProvider` (`StreamProvider<AppUser?>`), and `isGuestProvider`.
  - `data/fixtures/fixtures.dart` — `Fixtures`: demo `today`, seed tasks,
    subjects, etc., feeding the mock sources.

### `lib/shared`

- **Responsibility:** the reusable design system (widgets + custom-painted
  mascot/timer) that every frame composes.
- **Key files:**
  - `shared/widgets/` — `AppScaffold`, `BottomNav` (+ `NavTab` indices),
    `AppCard`, `PrimaryButton`, `SettingsRow`, `AppToggle`, `TagChip`,
    `AppBottomSheet`, `AppDialog`, `SectionPill`, `MoodBlob`, `AppTextField`,
    `CalendarGrid`, `GuestBadge`, `GuestNudgeCard`, `ComingSoon`,
    `OnboardingDots`, `ShareSheet`, `CircleBackButton`, `DismissKeyboard`.
  - `shared/mascot/` — `ada_mascot.dart` (the `CustomPainter` ice-cube + nav
    face), `focus_timer.dart`, `ice_timer.dart` (timer ring/cube visuals).

### `lib/features/<feature>`

Every feature follows the same shape: `presentation/` (screens + `widgets/` +
`sheets/`), `providers/` (Riverpod state), and sometimes `controllers/`
(user-intent → repository mutations). Features:

| Feature | Responsibility | Notable state |
|---|---|---|
| `features/shell` | The 5-tab `AppShell` (indexed stack + floating `BottomNav`, guest gating on tap). | reads `isGuestProvider` |
| `features/auth` | Splash, Welcome, Sign in/up, OTP, guest gating prompts (Ada/Stats/Save). | `auth_controller.dart` |
| `features/onboarding` | 8-step onboarding (referral → name → study → mood → syllabus → peak → prism → building). | `onboarding_controller.dart` |
| `features/plan` | Day timeline, add-task, pickers (time/date/duration/repeat), sheets (reschedule, quick-add, menus). | `plan_providers.dart`, `plan_ui_providers.dart` |
| `features/focus` | Timer screen, duration/prism/link-task sheets, focus-end summary. | `focus_repository.dart` controller, `linked_task_provider.dart` |
| `features/subjects` | Subjects list, detail, form/menu/semester/file sheets. | `subjects_ui_providers.dart` |
| `features/stats` | Weekly stats screen. | reads task/mood/stats providers |
| `features/ada` | Ada chat screen + history sheet. | `adaChatProvider` (in `ada_repository.dart`) |
| `features/mood` | Morning/evening mood check-ins. | `mood_repository.dart` |
| `features/settings` | Settings hub, profile, notifications, sounds/prism, email + many edit sheets. | `profile_controller.dart`, `prism_settings_provider.dart` |

## 5. Entry Points & Flows

- **Bootstrap:** `main.dart` → `ProviderScope` → `AqademiqApp`
  (`app.dart`) → `MaterialApp.router` with `routerProvider`.
- **Routing:** `core/router/app_router.dart`. Initial location `/` = Splash.
  Full-screen routes sit outside the shell; the tab shell is a
  `StatefulShellRoute.indexedStack` with branches, in **branch order**:
  `0` Subjects (`/subjects`, child `/subjects/detail/:id`), `1` Planner
  (`/plan`), `2` Timer (`/timer`), `3` Stats (`/stats`), `4` Ada (`/ada`).
  - **Important ordering gotcha:** the `NavTab` semantic indices
    (`shared/widgets/bottom_nav.dart`: subjects 0, planner 1, timer 2, stats 3,
    **ada 4**) must match the shell branch order in the router. The bottom bar
    renders Ada **visually centered** (L→R: Subjects · Planner · Ada · Timer ·
    Stats) even though Ada carries index 4.
- **Guest gating:** `AppShell._onTap` intercepts taps on Ada (4) and Stats (3)
  while `isGuestProvider` is true and pushes `/unlock/ada` or `/unlock/stats`
  instead of switching branches.

### Representative traces

**Toggle a task done (optimistic):** `PlanScreen` → `DayTasksController.toggleDone`
(`features/plan/providers/plan_providers.dart`) optimistically writes
`AsyncData` → calls `tasksRepositoryProvider.update` → `TasksRepository.update`
→ `MockTasksSource.update` (delayed) → on failure rolls back to the previous
list; on success invalidates `weeklyCompletedProvider` so Stats updates.

**Run a focus session:** `TimerScreen` → `FocusController.start`
(`data/repositories/focus_repository.dart`) → `FocusRepository.start` →
`MockFocusSource.start` → status flips to `running`; a local `Timer.periodic`
ticks `elapsedSec` each second until it reaches the duration, then `completed`.
`complete()` records mood and (when a real session id exists) calls the
repository. In the §8 pass the local timer is replaced by Redis-backed
`focus:tick` events over Socket.IO.

## 6. Cross-Cutting Concerns

- **Configuration:** compile-time via `Env` / `--dart-define`. `Env.useMocks`
  gates every repository's source selection.
- **State management:** Riverpod throughout. Read-only server state via
  `AsyncNotifierProvider`/`FutureProvider` exposing `AsyncValue`; local UI state
  via `NotifierProvider`. Optimistic updates + rollback are the norm for
  mutations (see `DayTasksController`). No `setState` for server state.
- **Auth/session:** `AuthRepository` (mock starts as guest);
  `authStateProvider` and `isGuestProvider` drive gating.
- **Error handling:** typed sealed `Failure` (`core/error/failure.dart`);
  sources map backend errors into a `Failure`; presentation renders via
  `AsyncValue.when(error: …)`.
- **Theming:** `AppColors` theme extension + `context.colors`; Light/Dark/System
  + accent are Riverpod providers; `buildAppTheme` rebuilds on change.
- **Persistence:** none yet — all state is in-memory for the session. The §8
  pass adds `shared_preferences`/secure storage/offline cache.
- **Testing:** `test/adapters_test.dart` (seam-2 adapter round-trips),
  `test/widget_test.dart`. Lints via `very_good_analysis`.

## 7. Conventions & Gotchas

- **UI is backend-blind:** widgets must never import Dio or a DTO — only
  providers and models. Keep this invariant when adding features.
- **All DTO↔model mapping goes through `data/adapters/adapters.dart`.** Add new
  fields there, not in widgets.
- **New data domain checklist:** add model(s) in `data/models`, DTO(s) in
  `data/dtos` (+ run codegen), adapter extensions in `adapters.dart`, a
  `Source` interface with mock + api impls in `data/sources`, a repository +
  provider in `data/repositories`, then feature providers/controllers.
- **Codegen:** after editing any `@freezed`/`json_serializable` file, run
  `dart run build_runner build --delete-conflicting-outputs`. The `.freezed.dart`
  / `.g.dart` files are generated — don't hand-edit.
- **Nav index/branch order must stay in lockstep** between `NavTab`
  (`bottom_nav.dart`) and the router's shell branches; Ada is index 4 but
  visually centered.
- **Mock sources should mimic real latency and failure** (via `mock_latency.dart`)
  so loading/error states stay honest before the backend exists.
- **`ApiXxxSource` methods currently throw `UnimplementedError`** — they are
  intentional stubs filled during the §8 integration pass.
- **Design fidelity:** visual specs come from `prototypes/` and `docs/specs/`;
  lift values (colors/spacing/copy), never the prototype's HTML structure.

## 8. Open Questions

- **Live backend not wired.** All `ApiXxxSource` implementations, Dio
  interceptors (auth token/refresh, retry, Cloud Trace), the Identity Platform
  `AuthRepository`, GCS signed-URL uploads, and the Socket.IO `RealtimeRepository`
  are pending the §8 pass and depend on the NestJS `openapi.json` being dropped
  into `backend_contract/`.
- **Ada streaming:** `AdaRepository.reply` returns a single message today; the
  design calls for streamed/typed replies (SSE or Socket.IO) — transport TBD.
- **Persistence:** appearance/accent, focus elapsed (cold-start resume), and the
  Guest-Mode offline task cache are in-memory only; the storage mechanism
  (`shared_preferences` / `drift`/`hive`) is planned but not implemented.
- **`INTEGRATION.md`** (screen→endpoint map) is still a stub to be completed
  during wiring.
