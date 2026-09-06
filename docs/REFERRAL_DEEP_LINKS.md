# Referral deep links

## What ships today

`Share the shape` / the invite sheet now sends a real link:

```
Join me on Aqademiq — my focus sanctuary. Use my referral code A1B2C3D4. https://www.aqademiq.com/join?ref=A1B2C3D4
```

Two link shapes are understood by the app (`lib/core/utils/referral_link.dart`):

| Shape | Opens the app | Needs anything hosted |
|---|---|---|
| `aqademiq://join?ref=CODE` | **yes, today** | no |
| `https://www.aqademiq.com/join?ref=CODE` | **not yet** — see below | yes |

The shared link is the **https** one, because a custom scheme is not clickable
in most chat apps. Until the two association files below are hosted it opens the
marketing site, which is exactly what the bare `https://www.aqademiq.com` it
replaced already did — so nothing regressed, the code is simply in the URL now
as well as in the text.

The code is still spelled out in the message on purpose. Reading it off the
screen and typing it is the only route that works with no hosting, no install
attribution and no clipboard.

## To make the https link open the app

Both files must be served over HTTPS, with `content-type: application/json`, no
redirects, and no authentication.

### 1. Android — `https://www.aqademiq.com/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.r13.aqademiq",
    "sha256_cert_fingerprints": ["<UPPERCASE:COLON:SEPARATED:SHA256>"]
  }
}]
```

Get the fingerprint from the key that actually signs the uploaded build. If Play
App Signing is on, the one that matters is in **Play Console → Test and release →
Setup → App signing**, not your local keystore. For a locally signed build:

```bash
keytool -list -v -keystore <your.keystore> -alias <alias> | grep SHA256
```

List both (upload key and Play signing key) if you use Play App Signing —
`sha256_cert_fingerprints` is an array for exactly this reason.

Verify after deploying:

```bash
adb shell pm verify-app-links --re-verify com.r13.aqademiq
adb shell pm get-app-links com.r13.aqademiq   # want: verified
```

The intent filter is already in `AndroidManifest.xml` with `android:autoVerify="true"`.

### 2. iOS — `https://www.aqademiq.com/.well-known/apple-app-site-association`

No `.json` extension.

```json
{
  "applinks": {
    "details": [{
      "appIDs": ["<TEAMID>.com.r13.aqademiq"],
      "components": [{ "/": "/join*", "comment": "referral links" }]
    }]
  }
}
```

**iOS also needs a change in this repo, which is deliberately not made yet.**
Universal Links require the `com.apple.developer.associated-domains` entitlement:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:www.aqademiq.com</string>
  <string>applinks:aqademiq.com</string>
</array>
```

That entitlement must also be enabled on the provisioning profile. Adding it to
`Runner.entitlements` before the profile has the capability **fails the archive**,
which is why it is left for whoever hosts the AASA file to turn on in the same
pass. The custom `aqademiq://` scheme is registered in `Info.plist` already and
needs none of this.

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
