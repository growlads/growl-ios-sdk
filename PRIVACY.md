# Privacy Guide for Host Apps

The Elo SDK shows ads targeted by conversation content. That means your app
sends user-generated text to an ad server. This document lists exactly what
leaves the device, what the SDK will never do on its own, and what you — the
host app — are responsible for. Read it before shipping.

## TL;DR checklist

- [ ] Disclose in your privacy policy that chat content is shared with Elo
      (and any mediation partners) for contextual advertising.
- [ ] Declare the data types below in your App Store Connect privacy
      nutrition label — the SDK's bundled privacy manifest does **not** do
      this for you.
- [ ] Decide on passive location sharing. It is **on by default**; pass
      `shareGeoLocation: false` if you don't want it.
- [ ] Don't request ads in flows where users discuss health, finances,
      sexuality, immigration status, or other sensitive topics — don't call
      `loadAd`/`preloadAd` there at all.
- [ ] If your app serves children or you're in the Kids category, set
      `coppa`/`tfua` and get a compliance review first. Kids-category apps
      generally cannot include third-party advertising at all.
- [ ] If GDPR/US state privacy laws apply to your users, run a CMP that
      writes IAB TCF v2 / GPP keys to `UserDefaults`. The SDK forwards those
      signals; it does not collect consent for you.
- [ ] Only if you call `Elo.setUserData`: disclose that you share age,
      gender, email, and phone with Elo, and declare Email Address and Phone
      Number on your nutrition label. Nothing is sent unless you call it.

## What the SDK sends, and when

Everything below is sent only when your app calls `Elo.loadAd` /
`Elo.preloadAd` (or uses a view/modifier that calls them for you). The SDK
makes no ad requests on its own.

### Chat content — the big one

The `messages` (role + full text) and `contextObjects` you pass are sent
verbatim to Elo's ad server for contextual targeting, and are also visible
to every mediation adapter registered in the auction (via `AdBidRequest`).
The SDK truncates long histories but does not redact anything.

**You control what goes in.** Treat the `messages` parameter as data leaving
your app to a third party:

- Only pass what targeting needs — recent turns, not whole histories.
- Never pass conversations from flows you know handle sensitive or
  regulated content; skip the ad slot instead.
- Disclose this data flow to end users. Suggested privacy-policy language:

  > We work with Elo (elo.ad) to show ads relevant to your conversation.
  > When an ad slot is shown, recent messages in the conversation and basic
  > device information are shared with Elo to select an ad. This content is
  > used for contextual ad selection.

### Device and app signals

Sent with every ad request: device model and hardware version, OS name and
version, system language, screen size and scale, connection type
(wifi/cellular), a WebKit user agent, your app's bundle ID and version,
settings-derived country (from the device region or App Store storefront —
not GPS), and UTC offset.

### Identifiers

- **IDFA** — sent only when *all* of these hold: the user authorized App
  Tracking Transparency in your app, `coppa`/`tfua` are false, and (where
  GDPR applies) TCF purpose-1 consent is present. The SDK never triggers
  the ATT prompt; if you never call
  `ATTrackingManager.requestTrackingAuthorization`, the IDFA never leaves
  the device.
- **IFV** (`identifierForVendor`) — sent as a fallback only when identifiers
  are allowed by the same consent gates but no IDFA is available.
- **Visitor ID** — a random per-install `anon_<UUID>` stored in the SDK's
  own `UserDefaults` suite. Not derived from any device identifier; used for
  frequency capping and targeting continuity. Deleting the app resets it.
- **Publisher user identifier** — whatever you pass to
  `Elo.setUserIdentifier`, which replaces the visitor ID on requests and
  tracking pings. Persisted in the Keychain with the first-party user data
  below, so it survives a relaunch; see that section for what that means for
  sign-out. Send an id from your own systems, not an email address.

### First-party user data (opt-in, off unless you call it)

`Elo.setUserData` shares what your app knows about its signed-in user — age,
gender, email, and phone — as a `user` object on ad requests. The SDK sends
nothing here unless you call it.

- **Contact details leave the device.** They travel to the ad server over
  HTTPS and are SHA-256 hashed there before anything is written, so only
  digests reach Elo's request logs, analytics store, and archives. Do not hash
  them yourself — a digest the server can't reproduce matches nobody.
- **Hashing is pseudonymization, not anonymization.** A digest is still
  personal data under GDPR, and still counts as "Email Address" and "Phone
  Number" on Apple's nutrition label. Hashing narrows what a leak exposes; it
  does not remove your obligations.
- **Store-only today.** The data is stored alongside the ad request; it is not
  forwarded to ad exchanges and does not affect ad selection.
- **Consent-suppressed server-side.** The ad server discards the whole object
  on requests flagged `coppa` or `tfua`, and on any request where GDPR
  applies. The SDK still sends it and lets the server enforce that gate — if
  you would rather it never leave the device, don't call `setUserData` for
  those users.
- **Persisted on the device, encrypted at rest.** So that a relaunch which
  resumes a signed-in session keeps sending it, the SDK stores what you set in
  the **Keychain**, as one record with the publisher user identifier. The item
  is `ThisDeviceOnly`, which keeps it out of iCloud Keychain and encrypted
  device backups — an email address set on one phone never restores onto
  another. Nothing is ever written in plaintext: if the Keychain is
  unavailable the SDK keeps the data in memory for that process rather than
  falling back to an unprotected file.
- **It outlives a sign-out you don't signal.** That is the cost of persistence:
  `Elo.setUserData(nil)` on sign-out is an obligation, not a convenience —
  without it the previous account's details keep riding requests, including on
  a shared device and across relaunches. `Elo.shutdown()` erases the stored
  record as well as the in-memory copy.

### Location

With `shareGeoLocation` enabled (**the default**), the SDK passively reads
the device location *only if your app already holds location authorization*
and attaches it, rounded to `geoLocationPrecision` decimal places (default
2, roughly 1 km). The SDK never requests location permission itself. If your
app has no location permission, nothing is sent regardless of this setting.

Opt out at init (`shareGeoLocation: false`) or at runtime
(`Elo.setShareGeoLocation(false)`). If your location permission's usage
string doesn't cover advertising, opt out or update the string —
repurposing permissioned data beyond its stated use is an App Review and
GDPR risk.

### Consent signals (pass-through)

The SDK reads `IABTCF_TCString`, `IABTCF_AddtlConsent`, `IABTCF_gdprApplies`,
`IABTCF_PurposeConsents`, and the `IABGPP_*` keys from
`UserDefaults.standard` — the standard locations IAB-compliant CMPs write
to — and forwards them with each request. It also forwards your
`coppa`/`tfua` configuration flags. The SDK does not interpret or collect
consent; obtaining a lawful basis is your responsibility as the data
controller.

## What the SDK never does on its own

- Never shows the ATT prompt.
- Never requests location permission.
- Never sends ad requests outside your explicit `loadAd`/`preloadAd` calls.
- Never sends IDFA without ATT authorization plus the consent gates above.
- Never writes to your app's standard `UserDefaults` (it uses its own
  suite; it only *reads* the standard IAB consent keys).

## App Store requirements

### Privacy nutrition label

The SDK bundles a `PrivacyInfo.xcprivacy` manifest, which feeds Xcode's app
privacy report — but your App Store Connect nutrition label is a separate,
manual declaration. At minimum, account for:

| Data type | When | Purpose |
| --- | --- | --- |
| Emails or Text Messages (User Content) | Always — chat content is sent for targeting | Third-Party Advertising |
| Device ID | If you request ATT (IDFA), or via IFV fallback | Third-Party Advertising |
| Coarse Location | `shareGeoLocation` on + app holds location permission (default precision) | Third-Party Advertising |
| Precise Location | Same, if you raise `geoLocationPrecision` to 3+ | Third-Party Advertising |
| Product Interaction | Impression tracking, tap position inside Elo-served ad views (relative to the ad view, never the screen), plus click tracking when a mediated network delivers it | Third-Party Advertising, Analytics |
| Email Address | Only if you pass `email` to `Elo.setUserData` — hashing on receipt does not exempt it | Third-Party Advertising |
| Phone Number | Only if you pass `phone` to `Elo.setUserData` — hashing on receipt does not exempt it | Third-Party Advertising |
| Other Data (age, gender) | Only if you pass them to `Elo.setUserData` | Third-Party Advertising |

Whether data counts as "linked to the user" or "used for tracking" depends
on your overall setup (ATT status, your other SDKs, your Elo account's data
handling). When in doubt, declare conservatively and confirm with Elo.

### App Tracking Transparency

If you want IDFA-based demand, you must add `NSUserTrackingUsageDescription`
to your `Info.plist` and request ATT yourself, and your app's "used for
tracking" declarations must match. If you never prompt, the SDK operates
contextually — this is the lower-risk default.

### SKAdNetwork

If you use the AdMob adapter, merge its `AdMobSKAdNetworkItems.plist` into
your `Info.plist` — see
[Sources/EloAdsMediationAdMob/README.md](./Sources/EloAdsMediationAdMob/README.md).

## Mediation adapters multiply your surface

Every adapter you register brings its own SDK with its own collection
behavior, and receives the auction's `AdBidRequest` (including messages).
The AdMob adapter links Google Mobile Ads, which has independent data
collection and its own [privacy disclosure requirements](https://developers.google.com/admob/ios/data-disclosure) —
you must account for it in your nutrition label separately. Vet any
third-party adapter's data handling before registering it.

## Children

Set `coppa: true` (child-directed) or `tfua: true` (under-age-of-consent)
in `EloConfiguration` where they apply — both disable device identifiers
entirely. These flags do not by themselves make an integration COPPA
compliant, and Apple's Kids category prohibits most third-party advertising.
Do not integrate this SDK into a child-directed app without legal review.
