# Releasing to Google Play

The Android side of 1.1.0 builds, bundles and passes Play's technical
requirements. What it cannot do on an arbitrary machine is **sign**, because the
upload key is a secret that deliberately does not live in this repository.

## The one thing that is not in the repo

`android/key.properties` is git-ignored (see `android/.gitignore`) and names the
upload keystore. The copy currently on the Mac points at:

    storeFile=D:/aqademiq-upload.jks

That is a Windows path — the keystore lives on the Windows machine the first
Android builds were made from. On the Mac the build fails at
`:app:validateSigningRelease` with

    Keystore file '…/android/app/D:/aqademiq-upload.jks' not found
    for signing config 'release'.

Note where it looked: Gradle's `file()` resolves a relative path against
`android/app/`, and `D:/…` is only absolute on Windows. Give it a full POSIX
path, not a drive letter.

The failure is loud and stops the build — it does **not** quietly fall back to
debug signing when `key.properties` exists but points nowhere. (The debug
fallback only applies when the file is missing entirely.)

**This is not a bug to fix in code.** It is the correct behaviour: the key is
supposed to be somewhere Gradle can find it and git cannot.

To build a Play-ready bundle you need, on the machine doing the build:

1. The keystore file itself (`aqademiq-upload.jks`), copied from wherever it is
   kept. Treat it like a password — it is the only thing that proves an upload
   is you.
2. `android/key.properties` pointing at that copy:

   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=…
   storeFile=/absolute/path/to/aqademiq-upload.jks
   ```

**Do not generate a new keystore.** Aqademiq is already published — Play
Console shows `22 (1.0.0)` live in production, full rollout, since 14 Aug 2026.
Play matches every upload against the key that signed that release, so a fresh
key is rejected outright and there is no flag to override it. The existing
`aqademiq-upload.jks` is the only one that works.

If it is genuinely lost, the recovery is Play Support: apps on Play App Signing
can have their **upload** key reset (the app signing key never changes, which is
why installs keep updating). That is a support request with their turnaround,
not something to do the evening of a release. Back the file up somewhere that
is not one laptop before that becomes the story.

## Build

```sh
flutter build appbundle --dart-define-from-file=dart_defines.json
```

The `--dart-define-from-file` is not optional. Without it the app ships in mock
mode with no API base URL and no OAuth client ids — it will start, look fine,
and talk to nothing. Same rule as the iOS build.

Output: `build/app/outputs/bundle/release/app-release.aab`, which is what you
upload — an `.aab`, never an `.apk`. Around 92 MB with all three ABIs in it;
Play splits it per device, so what anyone actually downloads is far smaller.

### Check what you built

The release type falls back to **debug signing** when `key.properties` is
missing, so that `flutter run --release` keeps working on a machine with no key.
That fallback prints a loud warning, but a warning is easy to scroll past, so
verify the artifact rather than the log:

```sh
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep Owner
```

`CN=Android Debug` means it is debug-signed and Play will reject it. Delete it
and fix `key.properties` rather than trying the upload.

## Version

`pubspec.yaml`'s `version:` drives both platforms — `1.1.0+29` becomes
versionName `1.1.0` and versionCode `29`.

Play's rule is different from App Store Connect's. ASC closes a *train* (which
is why 1.0.0 is dead on iOS and everything is now 1.1.0); Play only requires
that **versionCode strictly increases**, and it never reopens a number.

Play production is currently `22 (1.0.0)`, so `29` is a valid next upload — the
22→29 gap is the iOS builds that burned numbers along the way. That is expected:
the two stores share one counter, one build number per build, whichever store it
went to. Gaps on Play are not worth "fixing".

Note that 1.0.0 is still the *live* version on Play even though iOS has moved
on. Play never closed it; it simply has not been updated since August.

## What Play checks, and where this app stands

| Requirement | State |
| --- | --- |
| `targetSdk` ≥ 36 (from 31 Aug 2026) | ✅ 36, inherited from the Flutter SDK |
| App Bundle, not APK | ✅ `bundleRelease` |
| 64-bit native code | ✅ arm64-v8a shipped alongside armeabi-v7a and x86_64 |
| versionCode above the live release | ✅ 29 > 22 |
| Upload signed with the **existing** upload key | ❌ needs the keystore (above) |
| Data safety form, content rating, privacy policy | Console-side, already done for 1.0.0 |

One thing to check in the Console rather than assume: the production track is
live in **2 of 177 countries**. A new release inherits the track's country list,
so if that 2 was a soft launch rather than a decision, 1.1.0 ships to the same
two countries unless it is widened first.

Foreground-service use needs a declaration in the Console: the app holds
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` so Prism audio and the focus timer survive
the screen going off. Play asks what the service is for and, for `mediaPlayback`,
usually wants a short video showing it. There is deliberately **no**
`SCHEDULE_EXACT_ALARM` — the reminder scheduler uses inexact alarms precisely to
avoid that permission's policy review.

## Testing on an emulator

There is no AVD in this repo; create one once. The toolchain notes matter more
than the commands, because two of them cost an hour to find:

```sh
# Flutter overrides JAVA_HOME with its own setting, so fix that, not the shell.
flutter config --jdk-dir="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

sdkmanager --install "system-images;android-36;google_apis_playstore;arm64-v8a" emulator
avdmanager create avd -n aqademiq_test \
  -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_7

emulator -avd aqademiq_test -gpu host -memory 6144
```

**JDK 21, not the newest.** AGP 8.11 rejects JDK 26 with the unhelpful message
`* What went wrong:` followed by nothing but `26.0.1`. That is the whole error.

**`-gpu host`, and give it real memory.** The AVD default is 2 GB with a 228 MB
heap, and `-gpu swiftshader_indirect` renders every Flutter frame and every
video frame on the CPU. That combination produced repeatable ANRs — load
average 13 to 23, CPU stalled 68–84% of the time, `lowmemorykiller` culling
system processes — in an app that is completely responsive once the emulator
has the GPU. If you see "isn't responding", check `Load:` in the ANR record
before you go looking for a bug in the app.

Driving it without Android Studio:

```sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.r13.aqademiq/com.aqademiq.aqademiq.MainActivity
adb exec-out screencap -p > shot.png
```

Note the activity name. `.MainActivity` shorthand resolves against the
applicationId (`com.r13.aqademiq`) and fails — the class lives under the
namespace (`com.aqademiq.aqademiq`). `aapt2 dump badging <apk>` prints the real
`launchable-activity` when in doubt.

Reading app state back:

```sh
adb shell run-as com.r13.aqademiq cat \
  /data/data/com.r13.aqademiq/shared_prefs/FlutterSharedPreferences.xml
```
