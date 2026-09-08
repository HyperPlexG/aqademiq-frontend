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

If the keystore is lost and the app is **already on Play**, it is not
recoverable from here — Play Support can reset an upload key, but only for apps
enrolled in Play App Signing, and only on their timeline. If the app has **never
been uploaded**, generate a fresh one (`keytool -genkey -v -keystore
aqademiq-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`)
and back it up somewhere that is not a single laptop.

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
is why 1.0.0 is dead and everything is now 1.1.0); Play only requires that
**versionCode strictly increases**, and it never reopens a number. The two
stores share the counter here, so a build made for TestFlight burns a
versionCode for Play too. That is deliberate — one number, one build, either
store — but it means Play sees gaps, which is fine and not worth "fixing".

## What Play checks, and where this app stands

| Requirement | State |
| --- | --- |
| `targetSdk` ≥ 36 (from 31 Aug 2026) | ✅ 36, inherited from the Flutter SDK |
| App Bundle, not APK | ✅ `bundleRelease` |
| 64-bit native code | ✅ arm64-v8a shipped alongside armeabi-v7a and x86_64 |
| Upload signed with the upload key | ❌ needs the keystore (above) |
| Data safety form, content rating, privacy policy | Console-side, not in this repo |

Foreground-service use needs a declaration in the Console: the app holds
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` so Prism audio and the focus timer survive
the screen going off. Play asks what the service is for and, for `mediaPlayback`,
usually wants a short video showing it. There is deliberately **no**
`SCHEDULE_EXACT_ALARM` — the reminder scheduler uses inexact alarms precisely to
avoid that permission's policy review.
