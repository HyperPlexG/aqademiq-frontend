# Haptics

This is the implementation of the **Aqademiq haptic architecture** (v2, November 2026,
built on the Full Flow v11 frames).

Aqademiq's material is ice. Every vibration in the app is something ice does:

- it sets (crystallise)
- it softens (melt)
- it holds (knock)
- it breaks (crack)
- it rings (bloom)

One rule limits all of it: the sanctuary is quiet.

This replaces v1, "The Melt Ramp". `docs/HAPTICS_IMPLEMENTATION.md` and
`docs/HAPTICS_TESTING.md` describe v1 and are kept for history only.

## 1. The pieces

```
screen / controller
    │  names the moment:   ref.read(hapticsProvider).play(HapticMoment.taskChecked)
    ▼
HapticsService ─────────► HapticGovernor ─────────► HapticDriver ──► native
haptics_service.dart      haptic_governor.dart      haptic_driver.dart
    │                     the §3 budget rules
    ▼
haptic_moments.dart  ── spec §4: moment → feel + tier
haptic_lexicon.dart  ── spec §2: the 22 patterns, each rendered three ways
```

| File | What it is |
|---|---|
| `lib/services/haptics/haptic_lexicon.dart` | The 22 patterns (`Aq.tick` … `Aq.bloom`, the five Prism modes, `Aq.success`, `Aq.error`). Each pattern has a Core Haptics timeline, an Android rendering (primitives, a feedback constant, a waveform) and a fallback preset. This is the only file that says what a vibration physically is. |
| `lib/services/haptics/haptic_moments.dart` | `HapticMoment`: one value per §4 touchpoint, with its tier (Essential, Full or preview). `specFor` maps each moment to its feel. Compare this file with the PDF's §4 tables. |
| `lib/services/haptics/haptic_governor.dart` | The §3 budget rules, as a plain class with an injected clock. Also holds `HapticSetting` (Off / Essential / Full). |
| `lib/services/haptics/haptics_service.dart` | `hapticsProvider`, plus `play`, `hold` and `watchFaceDown`. |
| `lib/services/haptics/haptic_driver.dart` | The method channel, and the Flutter fallback used when native isn't there. |
| `ios/Runner/HapticsPlugin.swift` | Core Haptics: transients, plus continuous events shaped by intensity curves. Uses the system generators for success, error and fallback. Also reports face-down, Low Power and thermal state. |
| `android/.../HapticsBridge.kt` | The Android rendering ladder (§2 below), face-down, power-save and thermal state. |
| `lib/shared/widgets/hold_to_confirm.dart` | The hold-to-confirm pill, used for Thaw everything (1.2 s) and Delete account (2 s). |

### The rule for adding a haptic

1. Find the row in the spec.
2. Call `play` with its `HapticMoment`, in the same place the visual change happens.

If no row fits, the answer is a spec change. Don't add a `HapticFeedback` call or a
new pattern at a call site. Nothing outside `lib/services/haptics/` imports
`HapticFeedback`.

## 2. How a pattern reaches the motor

**iOS**

- Transients play on one player.
- Each continuous event plays on its own player, started against the same engine
  clock. A Core Haptics parameter curve applies to everything in its pattern and
  holds its last value afterwards, so with a single player, melt's swell would
  silence the two drips that follow it.
- The engine stays running while the app is in the foreground and restarts as the
  app comes back to the foreground. This keeps the first play free of start-up
  delay (principle 5).
- `aq.success` and `aq.error` use `UINotificationFeedbackGenerator`; the spec says
  they are never restyled.
- A phone without Core Haptics plays the pattern's fallback preset.

**Android** uses the first rung that works on the phone:

1. The amplitude **waveform**, for patterns that are a shape over time (the breath,
   the drill's rumble, wind-down), on motors with amplitude control.
2. **Composition primitives**, if `areAllPrimitivesSupported` holds for every
   primitive the pattern uses. A primitive the spec gives a stand-in for (e.g.
   "LOW_TICK if THUD unsupported") is swapped first.
3. The pattern's **`performHapticFeedback` constant** or predefined effect:
   `SEGMENT_TICK`, `TOGGLE_ON`/`TOGGLE_OFF`, `DRAG_START`, `CONFIRM`/`REJECT`, the
   gesture thresholds, or `EFFECT_HEAVY_CLICK`. These are tuned by the phone maker,
   and on a budget phone with no primitives they feel better than a waveform.
4. The waveform on any motor with amplitude control. If the pattern has no explicit
   waveform, one is derived from the iOS timeline: transients become pulses of
   30–60 ms (long enough for an LRA to spin up) and curves are sampled every 25 ms.
5. A plain on/off rhythm. Patterns marked waveform-only, such as the breath, play
   nothing here instead.

Every vibration is tagged `USAGE_TOUCH`, so the phone's own touch-vibration setting
applies.

## 3. The budget rules (spec §3)

All of these live in `HapticGovernor` and are tested in
`test/haptics_governor_test.dart`.

| Rule | How |
|---|---|
| **Off / Essential / Full** | **Essential is the default** for anyone who never picked a level; an explicit Full or Off is kept. Essential admits only the moments marked `HapticTier.essential`, which a test pins to exactly §3's list. |
| **Device state** | Low Power Mode, a phone running hot (iOS `.serious`+, Android `THERMAL_STATUS_SEVERE`+) or the OS reduce-motion switch drops Full to Essential, never lower. The device state is checked at most every 30 s and the check is never awaited. |
| **Running session** | While a session runs, moments marked `ambient` (the student didn't trigger them) are dropped: Ada's proposals arriving, a refreeze, a plan finishing. What the student does, such as pausing or ending, still gets a response. |
| **Wheels** | Stream moments (wheels, dials, typing) are limited to one tick per 40 ms and play at half strength when the steps are under 40 ms apart (over 25 a second). `play(..., landed: true)` plays the settled value at full strength. |
| **One frame, one haptic** | Moments offered in the same microtask coalesce: an Essential moment beats a Full one, and on a tie the later one wins. |
| **Signatures** | Crystallise, melt, bloom, drill and crack are kept 2 s apart. If two collide, the earlier one is stopped and the later one plays. |
| **Repetition** | The same pattern within 10 minutes plays at 85% of its last strength, never below 50%. The count is per pattern name, so a toggle and a task check-off are both latches. Ten idle minutes reset it. Streams, previews and the system success and error are exempt. |
| **Continuous vibration** | No longer than 1.4 s, except the breath (10 s, up to 3 in a row). The patterns are written that way, and a test enforces it. |
| **Face down** | Bloom carries a desk-safe version (S ≤ .2, I × .7). The native side plays it if gravity says the phone is face down. The timer screen turns this watching on and off. |
| **Background** | Nothing plays while Aqademiq isn't the app on screen ("we never vibrate inside another app"). The notification carries the moment instead. |

## 4. Where the spec and Flutter part ways

- **`haptics.json`.** The spec's engineering notes ask for a JSON registry consumed
  by web code through Capacitor. Aqademiq is Flutter, so the registry is
  `haptic_lexicon.dart`. It keeps the same "one name, three renderings" shape, but
  the compiler catches a misspelt name or a missing platform.
- **Rive events.** The app doesn't use Rive. "Touch and picture land together" is
  kept by firing in the same `setState` or controller call that changes the screen.
  For optimistic updates (checking a task off), the feel lands with the tick on
  screen, and a rollback plays the system error.
- **Prism on the audio clock.** The session start plays the thud, then the Prism
  pattern 120 ms later, as one pattern on one clock. It is not yet scheduled
  against Prism's audio clock.
- **Patterns loaded per screen.** Instead, the engine is kept warm. A pattern is
  built at play time, which takes well under a millisecond; the delay the spec
  worries about is the engine starting.

## 5. Removed with v1

These had haptics in v1 and have none in the spec:

- streak milestones (and `streakMilestoneProvider`)
- subject and semester create and delete
- task delete and move-to-another-day, which now feel only through the gesture
  that did them: a swipe, a drop, or the reschedule review
- the Prism volume sliders
- the guest-upgrade "relief" pattern (the one-time code now ends on the system
  success)

## 6. Testing

```sh
flutter test test/haptic_lexicon_test.dart test/haptics_governor_test.dart \
  test/haptics_focus_once_test.dart test/haptics_tab_change_test.dart
```

- `haptic_lexicon_test.dart` checks the patterns against the PDF's numbers.
- `haptics_governor_test.dart` checks every §3 rule.
- `haptics_focus_once_test.dart` checks that a session ends with exactly one feel.
- `haptics_tab_change_test.dart` checks the tab bar.

To test on a device, use the spec's own list:

- a recent iPhone
- a Pixel (full Android support)
- a budget Samsung (no advanced Android vibration)
- an Apple Watch
- each platform with system haptics turned off

Try each with the screen dimmed and the sound off. If you can't tell what happened
from the feel alone, it is noise.
