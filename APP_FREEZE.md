# App freeze (v2 · design §04-A)

Freeze the apps that pull a student away — now, or with a **frost** (a rule:
a schedule, or a session started by hand). Thawing takes a breath (10 seconds,
or longer on Increasing resistance) and then opens the app for 2–15 minutes; it
refreezes by itself. Three groups sit beside the frosts: **Always open** (the
floor, never frozen), **Never open** (frozen all the time; thawing doesn't
reach these) and **Distracting** (the group never freezes them; Ada checks in
when one is opened).

Everything is device-local. iOS gives the app opaque tokens, never names, and
Android's package names never leave the phone either. There is no backend for
App freeze — the design promises "We never see your picks".

| Layer | Where |
|---|---|
| Model + rules (the spec) | `lib/features/freeze/domain/` — `freeze_models.dart`, `freeze_engine.dart` |
| Persistence | `lib/features/freeze/data/freeze_store.dart` (SharedPreferences `freeze.v1`) |
| Native bridge (Dart) | `lib/features/freeze/data/app_freeze_channel.dart` |
| State | `lib/features/freeze/providers/freeze_controller.dart` |
| Screens | `lib/features/freeze/presentation/` |
| iOS | `ios/Runner/AppFreezePlugin.swift`, `ios/FreezeShared/`, extensions `FreezeMonitor`, `FreezeShield`, `FreezeShieldAction`, created by `ios/add_freeze_targets.rb` |
| Android | `android/app/src/main/kotlin/com/aqademiq/aqademiq/freeze/` |
| Tests | `test/freeze_engine_test.dart` |

## 1. Channel `aqademiq/app_freeze`

One `MethodChannel`, the same calls on both platforms. Every call is
best-effort on the Dart side: `MissingPluginException` means "unsupported".

| Method | Args | Returns | iOS | Android |
|---|---|---|---|---|
| `status` | – | map, §1.1 | ✓ | ✓ |
| `requestAuthorization` | – | `bool` | FamilyControls `.individual` prompt | returns `status.authorized` |
| `openSettings` | `{target: usage\|overlay\|battery\|app}` | – | `app` → app-settings | the matching Settings page |
| `pickApps` | `{selection_id, title?}` | `{count}` or `null` (cancelled) | presents `FamilyActivityPicker`, saves the selection | `null` |
| `deleteSelection` | `{selection_id}` | – | removes it from the App Group | no-op |
| `installedApps` | – | `[{package, label}]` sorted by label | `[]` | launcher apps minus Aqademiq |
| `appIcon` | `{package, size}` | PNG `Uint8List` or `null` | `null` | the launcher icon |
| `floorApps` | – | `{phone, messages, maps, wallet}` → package | `{}` | default dialer, SMS app, a `geo:` handler, a wallet if installed |
| `applyPolicy` | `{policy: <JSON string>}` | – | store, re-shield now, reschedule | store, (re)start or stop the monitor |
| `takeEvents` | – | `[{type, at, target?, label?}]` | reads + clears the App Group queue | reads + clears prefs queue |

Native → Dart: `eventsWaiting` (no args) when an event is queued while the
engine is attached. Dart then calls `takeEvents`.

### 1.1 `status`

```json
{ "supported": true, "authorized": true,
  "usage_access": true, "overlay": true,
  "battery_restricted": false, "notifications": true }
```

* iOS: `supported` = iOS 16+. `authorized` = `AuthorizationCenter.shared.authorizationStatus == .approved`.
  `usage_access`/`overlay` mirror `authorized`; `battery_restricted` is false.
* Android: `authorized` = usage access **and** overlay. `battery_restricted` =
  `!PowerManager.isIgnoringBatteryOptimizations(packageName)`.

### 1.2 Events

| `type` | When | Fields |
|---|---|---|
| `thaw_request` | the shield's **Thaw** was pressed | `target` (Android package / iOS token id), `label` (Android only), `at` (ms) |

On Android the shield also opens the app straight away
(`aqademiq://freeze/thaw?target=<pkg>`), so the event and the link land
together; Dart de-duplicates by `target` within 30 s. On iOS the ShieldAction
extension cannot open an app, so it queues the event and posts a local
notification — "Tap to thaw" — whose tap opens Aqademiq.

## 2. The rules

`FreezeEngine` in `freeze_engine.dart` is the specification. Both native sides
implement the same functions over the policy in §3 — `FreezeRules.kt` and
`FreezeRules.swift` — and must stay in step with it.

Times are the phone's local time. Weekdays are ISO: 1 = Monday … 7 = Sunday.
Minutes are after local midnight; `end <= start` runs overnight, `0 → 1440` is
all day.

```
windowAt(frost, t):
  session:  started = session_started_at; none → null
            end = started + session_minutes (null minutes → no end)
            t in [started, end) → (started, end)
  schedule, not overnight (end > start, or all day):
            weekday(t) in days and date(t) in [from_day, until_day]
            and start <= minute(t) < end → (today+start, today+end)
  schedule, overnight:
            weekday(t) in days, date ok, minute(t) >= start → (today+start, tomorrow+end)
            weekday(t-1d) in days, date(t-1d) ok, minute(t) < end → (yesterday+start, today+end)

standingDown(t) = standdown and since <= t and (until is null or t < until)

active(t) = for each frost:
              enabled, not (skip_until and t < skip_until), w = windowAt(frost, t) not null,
              and if standingDown: holds[frost.id] exists and t < holds[frost.id]
            plus "now" (Freeze now) when started_at <= t and (ends_at null or t < ends_at),
              and if standingDown: holds["now"] exists and t < holds["now"]

covers(source, app) = source.apps.mode == keepOnly ? app not in apps : app in apps

isFrozen(app, t):
  1. app in groups.never_open        → true     (even standing down, even thawed)
  2. app in groups.always_open       → false
  3. covering = active(t) where covers(source, app); empty → false
  4. any covering is deep            → true     (no thawing in Deep freeze)
  5. a grant with t < until and target == "*" or target == app → false
  6.                                   true
```

Android also never freezes its **floor**, whatever the policy says: Aqademiq
itself, every launcher (home app), Settings, System UI, the dialer, the
default SMS app and emergency apps. iOS needs no floor — Phone and emergency
calls are never shieldable.

### Thaw breath

`thaw.resistance == standard` → 10 s. `increasing` → `10 + 10 × thaws_today`,
at most 60. A thaw day starts at **4 AM** local. The policy carries
`thaws_today` and `thaws_counted_at` (§3); the native side uses `thaws_today`
only if `thaws_counted_at` is in the current thaw day, otherwise 0.

## 3. The policy

`applyPolicy` gets `FreezeData.toJson()` without `thaw_log`, plus three keys.
Unknown keys must be ignored (forward-compatible).

```json
{
  "v": 1,
  "generated_at": 1767000000000,
  "set_up": true,
  "frosts": [
    { "id": "f1", "name": "Lecture hours", "kind": "schedule",
      "days": [1,2,3,4,5], "start": 540, "end": 780,
      "from_day": "2026-11-09", "until_day": "2026-11-15",
      "session_minutes": 120, "session_started_at": 1767000000000,
      "deep": false, "enabled": true, "skip_until": 1767000000000,
      "apps": { "packages": ["com.instagram.android"], "ios_selection": "sel-f1",
                "ios_count": 6, "mode": "freezeThese" } }
  ],
  "groups": {
    "always_open": { "packages": [], "ios_selection": "sel-always", "ios_count": 0, "mode": "freezeThese" },
    "never_open":  { ... }, "distracting": { ... },
    "adult_sites": false
  },
  "thaw": { "resistance": "standard", "minutes": 2 },
  "now": { "started_at": 0, "ends_at": 0, "deep": false, "with_focus": true, "apps": { ... } },
  "grants": [ { "target": "*", "until": 0, "started_at": 0, "label": "Instagram" } ],
  "standdown": { "since": 0, "until": 0, "holds": { "f1": 0, "now": 0 } },
  "recent_apps": { ... },
  "thaws_today": 2,
  "thaws_counted_at": 1767000000000,
  "focus_label": "LL(1) parsing notes"
}
```

Optional keys (`from_day`, `until_day`, `session_started_at`, `skip_until`,
`ios_selection`, `now`, `standdown`, `ends_at`, `until`, `label`,
`focus_label`) are **absent** when unset, never `null`. `mode` is
`freezeThese` or `keepOnly`. On iOS an app set's identity is its
`ios_selection` (the App Group key of a saved `FamilyActivitySelection`); on
Android it is `packages`.

## 4. The shield

Shown when a frozen app is opened. Copy by how many times today (thaw day,
4 AM) the shield has covered **that app**, capped at 3:

| Stage | Title | Line |
|---|---|---|
| 1 | Ada's sitting on this one. | Yours again at 3:42 |
| 2 | Still on ice. | 3:42 |
| 3 | Frozen. | 3:42 |

The time is when the app really unfreezes: the **latest** end among the
freezes covering it (h:mm, no AM/PM) — two freezes on one app hold it until
the last one ends. Any of them with no end (Until I stop) → "Until you stop". A
Never open app → title "Never open.", line "This one stays frozen."

Buttons: **Back to focus** (Android: home screen; iOS: `.close`), and
**Thaw · 10s** with the current breath (§2). The thaw button is absent for a
Never open app and replaced by "Deep freeze until 1:00 PM" text in a Deep
freeze. Colours: ground `#F8F6FF → #EBE5FC → #DDD4F8` (170°), ink `#1A1320`,
line `#584F70`, primary button `#111111`/white, secondary `rgba(255,255,255,.88)`
with ink text, the thaw glyph in `#6B5CF0`.

## 5. iOS

* Entitlement `com.apple.developer.family-controls` on the app and all three
  extensions; App Group `group.com.r13.aqademiq.shared` (already used by the
  widgets). Team `R6YW5K2YSP`.
* **Distribution needs Apple's approval** of the Family Controls entitlement
  for each bundle id (request at developer.apple.com/contact/request/family-controls-distribution).
  Development builds work without it.
* Targets, created idempotently by `ios/add_freeze_targets.rb` (same pattern
  as `add_widget_target.rb`): `FreezeMonitor` (`com.r13.aqademiq.freeze-monitor`,
  DeviceActivityMonitor), `FreezeShield` (`com.r13.aqademiq.freeze-shield`,
  ShieldConfiguration), `FreezeShieldAction` (`com.r13.aqademiq.freeze-action`,
  ShieldAction). Deployment target 16.0. `ios/FreezeShared/*.swift` is
  compiled into all four.
* Scheduling: one repeating `DeviceActivitySchedule` per schedule frost
  (`fz.frost.<id>`, daily, start/end hour+minute); the monitor checks the
  weekday and dates on `intervalDidStart` and re-evaluates. Non-repeating
  activities for Freeze now (`fz.now`), each thaw grant (`fz.grant.<n>`), the
  stand-down (`fz.standdown`) and session frosts end at their end time; an
  interval shorter than 15 minutes starts in the past so that it is legal.
  Every callback re-evaluates §2 and rewrites the one `ManagedSettingsStore`.
* Distracting: a daily activity `fz.distracting` with an event at 10 minutes
  of use; `eventDidReachThreshold` posts Ada's check-in notification.
* Never open + `adult_sites` → `webContent.blockedByFilter = .auto()`.

## 6. Android

* Grants: Usage access (`PACKAGE_USAGE_STATS`) and Display over other apps
  (`SYSTEM_ALERT_WINDOW`). No accessibility service — "We never read your
  screen."
* `FreezeMonitorService`, a `specialUse` foreground service, runs while the
  policy can freeze anything. While the screen is on it reads the foreground
  app from `UsageStatsManager` events about once a second and starts
  `ShieldActivity` over a frozen one; with the screen off it sleeps. Its
  ongoing notification: "9 apps on ice" / "Back at 3:42. Phone and Messages
  stay open." while something is frozen, "App freeze is on" / "Frosts run on
  their schedule." otherwise.
* `FreezeBootReceiver` restarts the service after a reboot or an app update.
* Distracting: the first open of one in 30 minutes posts Ada's check-in.
* Ada's check-in copy (both platforms): title "Ada", body "Quick check-in — is
  this what you meant to open?". Never a count, never guilt.

### 6.1 Android notes (as built)

* **The thaw link loses its query on the ambient channel.** `MainActivity`
  hands every `aqademiq://` link to `AmbientBridge.routeFrom`, which sends
  `host + path` only — `freeze/thaw` — on `aqademiq/ambient` (unchanged, so
  `join?ref=` and the widget routes keep working). The package arrives with
  the `thaw_request` event (`target`, `label`), and in full through
  `app_links`. Today `_handleRoute` ignores unknown routes, so both
  `freeze/thaw` and `freeze` (below) need a case there.
* Both notifications — the ongoing one and Ada's check-in — open
  `aqademiq://freeze` (route `freeze`).
* The monitor runs while the policy can freeze something now or later **and**
  Usage access is granted: Never open or Distracting non-empty; a running
  Freeze now; an enabled session frost that is running; an enabled schedule
  frost with days whose `until_day` is not before yesterday. A frost whose set
  names no Android package ("Freeze these", empty `packages`) does not count.
  `applyPolicy` re-syncs it, and so does `status`, so a grant given in
  Settings starts it the next time the app looks.
* Notification copy beyond §6: a Keep only freeze reads "Everything but N
  apps on ice" (N = the kept apps), or "Everything on ice"; a freeze with no
  end reads "Until you stop. Phone and Messages stay open."; with every
  covered app thawed (or Thaw all) it falls back to the idle pair.
* The shield's stage counts per package per thaw day; a shield re-shown for
  the same open (it did not take the screen within 3 s) is not counted again.
* Ada's check-in fires on opening a Distracting app (a change of foreground
  app), not for staying in it. Its channel, "Ada's check-ins", is high
  importance with no sound or vibration, so it shows as a silent banner; it
  times out after 10 minutes.
* The floor, beyond the launcher(s), dialer and SMS app: `android`, System
  UI, Settings (and whatever answers `ACTION_SETTINGS`), `com.android.phone`,
  Telecom, in-call UI (AOSP and Samsung), emergency / safety / cell broadcast
  apps, and the permission controller and package installer.

## 7. iOS notes (as built)

* **Token ids.** A `thaw_request` `target` is `app_<hex>` (or `cat_<hex>` /
  `web_<hex>`): a hash of the token's encoding, with the token kept under
  `fz.tok.<id>` in the App Group. A grant naming that id thaws exactly that
  token. When a *category* shields an app, ShieldAction only gets the
  category token; FreezeShield notes the app it drew the shield for
  (`fz.lastShield`, 10 min) so the target is still the app. If that note is
  missing the target is `cat_…`, and the grant thaws the whole category.
* **Where iOS is coarser than §2** (tokens are opaque; ManagedSettings can only
  except *apps* from a category policy): Keep only is `.all(except: kept apps
  ∪ Always open apps)` — categories in a Keep only pick, and Always open
  *categories*, cannot be excepted from it. A `cat_…` grant under a running
  non-deep Keep only source drops that source for the grant. A thawed app is
  excepted from every category policy, Never open categories included. At
  most 50 app tokens are shielded (Never open first). Keep only does not
  shield websites; Safari freezes as an app.
* **Thaw** responds `.close` (not `.defer`, which redraws the shield and would
  count as another cover). The "Thaw in Aqademiq" notification (time-
  sensitive, id `fz.thaw`, `userInfo.aqademiq = freeze`) is not a
  flutter_local_notifications one, so its tap is not routed to Dart: Dart
  learns of the request through `eventsWaiting` / `takeEvents`.
* **Every foreground** re-applies the shield and reschedules (heals anything the
  monitor missed), then sends `eventsWaiting` if the queue is non-empty. On a
  cold launch that arrives before Dart listens, so Dart must also call
  `takeEvents` once at start-up. The queue is only cleared by `takeEvents`.
* **Activities** (≤ 18 of iOS's 20): `fz.now`, `fz.standdown`, up to three
  `fz.session.<id>` and three `fz.grant.<n>` (soonest ends), `fz.distracting`,
  then `fz.frost.<id>` for the rest (running first, then by next start). The
  monitor reschedules at every interval end, so what the cut left out is
  picked up as earlier ones finish. Ends are rounded up to the minute. An
  all-day frost is 0:00–23:59, an end of 24:00 is 0:00 (crosses midnight), a
  frost under 15 minutes is stretched to 15 with a warning at its real end.
* **Distracting** posts Ada's check-in once a day, at 10 minutes' use of the
  group (a DeviceActivity threshold) — not on open as on Android.
* **Shield copy**: the ground is the flat `#EBE5FC` (a shield cannot draw a
  gradient), the icon an SF Symbol snowflake in `#6B5CF0`. Deep freeze: the
  stage title, subtitle "Deep freeze until 1:00 PM" (or "until you stop"), no
  thaw. A shield that nothing in the policy covers (stale) still offers Thaw:
  opening Aqademiq re-applies.
* **Build**: Runner stays at iOS 13; FamilyControls, ManagedSettings and
  DeviceActivity are weak-linked (`OTHER_LDFLAGS`). `status.notifications` is
  notification permission `authorized` or `provisional`.
* **Turning it on is one decision**: the checked-in Runner.entitlements does
  **not** carry `com.apple.developer.family-controls`, because until Apple
  approves Family Controls distribution for `com.r13.aqademiq`,
  `.freeze-monitor`, `.freeze-shield` and `.freeze-action`, a TestFlight /
  App Store export with the key fails to sign. `ruby ios/add_freeze_targets.rb`
  adds the key along with the three extensions — run it once Apple has
  approved (development builds work before that). Without it the app ships
  as before: `status` reports App freeze as not authorized and the screens say
  it is off.
