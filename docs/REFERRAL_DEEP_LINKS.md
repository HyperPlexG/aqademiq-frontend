# Referral deep links

## What ships

"Share Invite" (the "Help us grow!" card, `lib/shared/widgets/share_sheet.dart`)
sends `referralShareText(code)`:

```
Join me on Aqademiq — my focus sanctuary. Use my referral code A1B2C3D4. https://www.aqademiq.com/join?ref=A1B2C3D4
```

The button waits (up to 5 s) for the code if it has not loaded yet; it used to
read whatever was there and, on a fast tap, shared the bare site with no code.

Two link shapes are understood by the app (`lib/core/utils/referral_link.dart`):

| Shape | Opens the app | Needs anything hosted |
|---|---|---|
| `aqademiq://join?ref=CODE` | yes | no |
| `https://www.aqademiq.com/join?ref=CODE` | once the files below are hosted | **yes** |

The shared link is the **https** one, because a custom scheme is not clickable
in most chat apps.

## Why the shared link was "not valid" (checked 2026-11-10)

The app side was half done and the website side not at all:

| URL | Status |
|---|---|
| `https://www.aqademiq.com/join?ref=…` | **404** — the site has no `/join` page |
| `https://www.aqademiq.com/.well-known/apple-app-site-association` | **404** |
| `https://www.aqademiq.com/.well-known/assetlinks.json` | **404** |
| `https://aqademiq.com/…` (apex) | 308 → www |

So every tap landed on "page not found" in the browser, with or without the app
installed. The app now does its part (Universal Link entitlement on iOS, a
verifiable App Link filter on Android); the three files below are what the
website (Next.js on Vercel, behind Cloudflare) has to add.

## What the website must serve

All three on **`www.aqademiq.com`**, over HTTPS, with no redirect and no auth.
Cloudflare must not challenge them (no bot-fight / JS challenge on
`/.well-known/*`), or Apple's and Google's crawlers get HTML instead of JSON.

### 1. `/join` — the page for people without the app

`https://www.aqademiq.com/join?ref=CODE` must return **200**, not 404. Anyone
who has the app never sees it (the OS opens the app instead); everyone else
should get:

- the code, large, with a "Copy" button — they type it at onboarding's
  referral step after installing (store installs carry no link data);
- "Download on the App Store" → `https://apps.apple.com/app/id6792360288`;
- "Get it on Google Play" →
  `https://play.google.com/store/apps/details?id=com.r13.aqademiq`;
- optionally, by user agent, a redirect straight to the right store, and the
  Smart App Banner:
  `<meta name="apple-itunes-app" content="app-id=6792360288, app-argument=https://www.aqademiq.com/join?ref=CODE">`.

Treat `ref` as untrusted text: only render it if it matches `^[0-9A-Fa-f]{8}$`.

### 2. iOS — `/.well-known/apple-app-site-association`

No `.json` extension; `content-type: application/json`.

```json
{
  "applinks": {
    "details": [{
      "appIDs": ["R6YW5K2YSP.com.r13.aqademiq"],
      "components": [{ "/": "/join*", "comment": "referral links" }]
    }]
  }
}
```

`R6YW5K2YSP` is the Apple team since the October 2026 transfer (not the old
`SXN54W6F6T`). Apple fetches the file through its CDN when the app is
installed or updated, so after deploying it, reinstall the TestFlight build to
test. Check what Apple's CDN sees with
`curl https://app-site-association.cdn-apple.com/a/v1/www.aqademiq.com`.

The app side is in `ios/Runner/Runner.entitlements`
(`com.apple.developer.associated-domains`: `applinks:www.aqademiq.com`,
`applinks:aqademiq.com`). Associated Domains is an ordinary capability:
automatic signing enables it on the App ID during the archive. If an archive
ever fails with "provisioning profile doesn't include the Associated Domains
capability", tick **Associated Domains** on `com.r13.aqademiq` at
developer.apple.com → Identifiers and archive again.

### 3. Android — `/.well-known/assetlinks.json`

`content-type: application/json`.

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.r13.aqademiq",
    "sha256_cert_fingerprints": [
      "<PLAY APP SIGNING KEY SHA-256>",
      "<UPLOAD KEY SHA-256>"
    ]
  }
}]
```

The fingerprint that matters for Play installs is the **app signing key**:
Play Console → Aqademiq → Test and release → Setup → **App signing** → "App
signing key certificate" → SHA-256 (that page also offers a ready-made
`assetlinks.json`). Add the **upload key** too, so locally signed and sideloaded
builds verify; it is the `upload` alias in the keystore that
`android/key.properties` points to (`storeFile`), read with:

```bash
keytool -list -v -keystore <storeFile> -alias upload | grep SHA256
```

Uppercase, colon-separated, exactly as keytool prints it.

The app side is the `android:autoVerify="true"` filter in
`AndroidManifest.xml`. It lists **www only**: the apex 308-redirects to www,
verification never follows redirects, and on Android 11 and lower a single
unverifiable host fails every host in the app — so the apex has its own,
unverified filter. Verify after deploying:

```bash
adb shell pm verify-app-links --re-verify com.r13.aqademiq
adb shell pm get-app-links com.r13.aqademiq   # want: www.aqademiq.com: verified
```

## What a link is allowed to do

**Prefill the onboarding referral field, and nothing else.**

A deep link is attacker-controlled input — anyone can send anyone a URL — so the
app treats one as a suggestion rather than an instruction:

- it never auto-submits, so the code is visible and can be cleared;
- it never overwrites a code already typed;
- it is taken **once**, so clearing the field is not undone on the next rebuild;
- `referralCodeFrom` returns null unless the value is exactly 8 uppercase hex
  characters, so a link cannot put arbitrary text into the input.

The host check is exact (`aqademiq.com` and `www.aqademiq.com`), not a suffix
match — `evil-aqademiq.com` and `aqademiq.com.attacker.net` are refused, and
`test/referral_link_test.dart` fails if that is ever loosened.

The realistic residual risk is attribution theft: a stranger's link credits them
for your signup. That is indistinguishable from a legitimate referral, because
it is one. The server holds the guarantees that matter regardless — the code
must exist and be active, self-referral is refused, and
`referral_redemptions.referred_user_id` is unique, so a person can be attributed
exactly once, ever.

## Where attribution actually happens

Not `/v1/referrals/redeem` — nothing in the app calls that. The code rides along
with `POST /v1/onboarding/complete` as `referral_code`, and the redemption row is
written there once the account is provisioned.

Which means: **a student who never completes onboarding is never attributed.**
Guest mode skips onboarding entirely (`shouldSkipOnboarding()` returns
`guest || done`), so a guest who arrives via a referral link keeps the code
pending and only spends it if they later go through onboarding.
