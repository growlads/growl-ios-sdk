# Changelog

## Unreleased

## 0.3.0 — 2026-08-14

- **Fix: calling `Elo.trackRender` or `Elo.trackImpression` yourself no longer
  double-counts.** Ads shown through `EloAdView` have always recorded exactly
  one render and one impression per ad opportunity, however often the view is
  recycled or re-scrolled — but that limit lived in the view layer, so a fully
  custom layout calling the tracking hooks directly could report the same
  opportunity more than once. It now sits behind the public API and covers
  every path into it, so those hooks are safe to call on every layout pass. A
  repeat load that returns the same creative is a distinct opportunity and
  still records. A suppressed duplicate is silent: no ping, and no
  `eloAdDidTrackImpression` callback.
- **Fix: an ad hidden behind a container no longer counts as viewable.**
  Impressions require the ad to be at least half on screen for one continuous
  second, but "on screen" was measured against the whole window — and the frame
  it measured ignored clipping. An ad scrolled out of a transcript, inset by a
  container, or covered when the transcript shrinks for the keyboard therefore
  measured as fully visible and could fire an impression with none of it in
  front of the user. Viewability is now measured against what actually clips
  the ad, so those impressions no longer fire. Expect a small drop in reported
  impressions: the ones that stop were never viewable under the MRC rule. This
  is how the Android SDK has always measured.
- **Fix: the second and later ads shown in the same slot now report an
  impression.** Impression tracking measures how much of the ad is on screen,
  and that measurement was reset to "nothing visible" whenever a new ad
  replaced the one already displayed. Nothing recomputed it: the view had not
  moved, so no new geometry arrived to correct the reset. Every ad after the
  first in a slot that stayed mounted — the usual case when a chat requests a
  fresh ad without the view going away — recorded its render and its click but
  never its impression. Most reliably so when the new ad repeated an earlier
  creative, since identical text lays out identically. The dwell is now keyed
  on the ad opportunity, so a swap restarts the measurement on its own instead
  of waiting for a change in position that never comes.
- **New: `DiagnosticsSnapshot.trackingTotals` counts every render, impression,
  and click attempt since configure.** The existing `trackingEntries` list is a
  bounded ring buffer, so it could not tell you how many impression pings
  failed once a session got past the newest twenty — and a ping the SDK gives
  up on is a lost impression it will never retry. Each `TrackingTotals` carries
  `attempted`, `delivered`, `failed`, `unobservable`, and `inFlight`, is never
  evicted, and still records an outcome whose entry had already aged out. The
  counts also appear in `asExportableText()`. Cleared on configure and
  `shutdown()`, like the rest of diagnostics.
- **Fix: re-configuring the SDK now clears tracking state, matching Android.**
  `Elo.configure` already replaced the session, the ad cache, and the network
  client, but left the render/impression bookkeeping behind — where it could
  suppress tracking for an ad shown under the new configuration. It is now
  cleared alongside the rest, as `Elo.shutdown()` already did.
- **Fix: an ad card no longer loses its image when the same creative comes
  back after you leave and re-enter a chat.** The card drops its thumbnail
  when a creative's image can't be loaded, so a broken URL leaves text rather
  than a blank square. That suppression fired on cancelled image fetches too —
  and iOS cancels the fetch in flight whenever the view goes away, which is
  what navigating out of a chat does. Worse, it was remembered against the
  creative rather than the ad, so once a creative was marked broken every
  later ad that served the same creative rendered without its image as well.
  A cancelled fetch is now left alone and retried on the next showing, and the
  suppression only applies to the ad it was recorded for.

- **Breaking: `EloAd.id` is now the ad opportunity, and the creative moved to a
  new `EloAd.creativeId`.** `id` previously carried the ad server's `ad_id` —
  the *creative* — which is stable across opportunities, so the same creative
  served twice produced two ads that looked identical to the SDK. The ad
  opportunity, which is what render, impression, and click URLs are keyed under
  server-side, was tucked away in an internal field. They have swapped places:
  `id` is the opportunity (one per showing) and `creativeId` names the artwork.
  Correlate delivery on `id`; group by `creativeId`.

  If you log or store `ad.id`, it now changes on every serve of the same
  creative. Switch to `ad.creativeId` wherever you meant the creative.

  **Adapter authors:** `EloAd.init` now takes both `id` and `creativeId`, and
  `id` must be unique per *fill*. Pass your network's per-response id if it has
  one, or mint a `UUID().uuidString`. Passing a creative id there collapses
  every serve of that creative into a single tracked ad, so only the first
  reports a render and an impression. The bundled AdMob adapter now mints one
  per fill, which fixes exactly that under-reporting on AdMob native fills.


## 0.2.0 — 2026-08-09

- **New: `Elo.setUserIdentifier` ties ad requests to your own user account.**
  Every request carries an anonymous, per-install `visitor_id` the SDK
  generates. Apps with a sign-in can now supply their own identifier instead,
  and it replaces that anonymous id on subsequent ad requests and their
  tracking pings — so delivery, frequency capping, and reporting follow the
  user across installs and devices rather than the install. Call it once the
  user is known and clear it on sign-out; the order relative to `Elo.configure`
  does not matter. The anonymous id is kept underneath, so clearing restores
  the same one the install had before. An ad keeps whichever identity it was
  requested under for its whole lifetime, so an impression that fires after a
  sign-out is still reported against the request that fetched it. The
  identifier lives in memory only (re-set it on each launch) and is cleared by
  `shutdown()`; a re-configure does not clear it, since a config refresh is not
  a sign-out. Whitespace is trimmed, a blank string clears it, and values over
  256 characters are ignored with a warning.

- **Fix: the loading placeholder's shimmer now sweeps a few times and then
  rests, and stays still for anyone with Reduce Motion on.** It previously
  repeated for as long as the placeholder was on screen, which is the same
  never-goes-idle problem as the scrolling description below — and a request
  that hangs holds the placeholder there indefinitely. It now shimmers well
  past the point a normal ad request returns, then rests as a plain skeleton.

- **Fix: a scrolling ad description now scrolls a few times and then settles,
  instead of scrolling for as long as the ad is on screen.** A permanently
  animating line keeps the host app's main run loop awake, which never lets the
  app go idle: automation frameworks that wait for idle before each interaction
  (XCUITest, and Appium on top of it) time out on every tap, and on some OS
  versions the repeated re-render also grows memory without bound. The
  description now makes three passes, then stays tail-truncated like any other
  line. Scroll speed, the holds at each end, travel distance and row height are
  unchanged, and a new creative gets its own passes.

- **Fix: a scrolling ad description no longer leaks memory for as long as it
  animates.** Driving the marquee through SwiftUI's animation system makes
  SwiftUI allocate a new `CADisplayLink` every frame without releasing any of
  them on some OS releases (reproduced on the iOS 18.4 and 27.0 simulators) —
  roughly 50 leaked objects per second, unbounded memory growth, and an app
  UI-test frameworks like XCUITest treat as permanently busy, so automated
  taps time out. The scroll offset is now stepped on a fixed 30 Hz clock with
  no `Animation` involved; at the marquee's 30 pt/s velocity each tick moves
  exactly one point, so the motion is visually unchanged.

- **Fix: a scrolling ad description now always starts from the beginning of
  the string, flush with the left edge of the row.** When a new creative
  arrived, or an ad card scrolled back into view, while the previous
  description was still mid-scroll, the outgoing pass kept driving the new
  line's position: it could appear to start from the middle of the sentence,
  or be pushed well to the right and read as indented into the middle of the
  card. Restarting a pass now cancels any animation still in flight (matching
  the Android SDK, which was already correct here) and the scrolling line is
  rebuilt from scratch per run, so it can only ever begin at the head. Scroll
  speed, the holds at each end, and the height of the line are unchanged.

- **Fix: a creative that wins more than once now records a render and an
  impression every time it's shown.** Render and impression dedup was keyed on
  the creative id, which is stable across ad requests — so the second and every
  later time the same creative won an auction in a single app session, the SDK
  suppressed both pings while the ad still displayed and still clicked.
  Those ad opportunities reached the server as a click with no render and no
  impression behind it. Dedup is now keyed on the ad opportunity, so repeated
  showings of one creative each report their own render and impression, while
  the guarantee that matters is unchanged: scrolling an ad out of a lazy list
  and back, a tab switch, or any other re-appearance still reports exactly one
  render and one impression per opportunity.

  **Expect reported renders and impressions to rise** once this ships — the
  missing events were never counted. Click volume is unaffected. Publishers
  whose reporting showed clicks exceeding impressions for a placement should
  see that resolve.

  Two consequences worth knowing: `EloAd` equality (and its hash) now
  distinguishes the same creative served for two different ad requests, where
  it previously treated them as one value; and `Elo.shutdown()` now clears the
  dedup state, so an ad shown before shutdown can report again after a
  re-`configure`.


## 0.1.9 — 2026-07-29

- **An ad image that fails to load now hides the thumbnail instead of leaving
  a blank tile.** The compact card and the keyboard banner used to keep a gray
  placeholder square in the row when the creative's image URL couldn't be
  fetched; the tile and the gap after it now drop out and the text takes the
  space. AdMob-rendered fills apply the same rule to their icon asset — a fill
  with no usable icon no longer shows an empty 56pt square. Creatives that
  carry no image URL at all are unchanged.

- **The ad disclosure now leads the attribution line: `Ad • Headline`.** It
  used to trail the headline (`Headline · Sponsored`), where a long headline
  pushed it into the ellipsis and it disappeared. Leading it makes truncation
  structurally unable to reach it. The separator is now a `•` (U+2022) rather
  than a `·` (U+00B7), and `sponsoredLabel`'s default changed from
  `"Sponsored"` to `"Ad"` — shorter, so it costs the headline less width. The
  parameter name is unchanged, so no call site breaks; keep passing a localized
  string for non-English surfaces. Applies to the compact card, the keyboard
  banner, and AdMob-rendered fills.

- **Creative descriptions are now a single line and scroll when they don't
  fit.** Copy wider than the surface moves right-to-left at 30pt/s until the
  end of the line is visible, holds there for 1.2s, then restarts from the
  beginning after another 1.2s pause — so the whole line is readable and two
  fragments of it are never on screen together. Motion stops while the ad is off
  screen and falls back to a static ellipsis under Reduce Motion. Opt out with
  the new `EloAdStyle.descriptionOverflow: .truncate`.

  Note for layouts that reserve space: the compact card's description used to
  wrap to two lines, so cards with long descriptions are now roughly 19pt
  shorter. If you reserved a fixed slot height for the card, expect extra
  whitespace.

- AdMob-rendered fills get the disclosure reorder only — their body text is a
  registered Google asset view and keeps two-line tail truncation. Marquee for
  the renderer path is a follow-up.


## 0.1.8 — 2026-07-22

- **Fix: `Elo.shutdown()` during an in-flight ad request no longer risks a
  crash.** The networking client now fails closed with a catchable error
  instead of creating a URL task on an invalidated session (which threw an
  uncaught `NSException`). Affects apps that shut the SDK down while a request
  or its retry is still outstanding.

- **Privacy: diagnostics request-payload capture is now opt-in.**
  `DiagnosticsEntry.requestPayloadJSON` (surfaced via `Elo.Debug.snapshot()`)
  is `nil` unless the host app calls the new
  `Elo.setRequestPayloadCaptureEnabled(true)`. The payload retains the
  advertising id, geolocation, and consent strings, so it is no longer
  captured by default — enable it only in development/debug builds. Message
  content and context descriptions remain redacted as before.
- **Diagnostics now surface the server ad-opportunity id.**
  `DiagnosticsEntry` gains a `serverRequestId` field carrying the ad server's
  `request_id` (the ad-opportunity id) for any operation that reached the ad
  server, fill or no-fill. It equals the id the backend records for the request,
  so integrators and test harnesses can correlate a specific ad request to its
  server-side impression and click events. Retained in memory only; never
  exported. Nil only for cached and not-configured outcomes (no server request
  was made).
- **Impression/click diagnostics now carry the correlating opportunity id.**
  `TrackingDiagnosticsEntry` gains a `serverRequestId` field carrying the served
  creative's ad-opportunity id (ad response `request_id`). Impression/click
  tracking URLs are keyed under this id server-side, so reading it off the
  confirmed-impression entry correlates the exact request to its funnel row —
  instead of inferring which `loadAd` operation produced the displayed creative
  (transcript-driven preloads/reloads create several). Retained in memory only.
- **Diagnostics now record the requested ad display position.**
  `DiagnosticsEntry` gains a `displayPosition: AdDisplayPosition?` field carrying
  the position the operation requested (`nil` when the caller passed none). It
  disambiguates otherwise-identical `loaded(elo)` rows — e.g. a `.banner`
  keyboard-banner load from a background no-position context preload for the
  same message count — so integrators and test harnesses can select the
  operation for a specific surface deterministically. Retained in memory only;
  never exported.

- **Breaking: `AdResult.loaded` now carries the winning bid's auction data** —
  `case loaded(EloAd, eCpm: Double, networkId: String)`, matching Android's
  `AdResult.Loaded(ad, eCpm, networkId)`. `eCpm` is the winning price
  (USD-equivalent CPM, always `>= 0`); `networkId` identifies the winning
  adapter (`"elo"` for Elo demand). Update pattern matches from
  `case .loaded(let ad)` to `case .loaded(let ad, _, _)` (or bind the new
  values). Cache-served preloads return the auction data of the original win.
- **Privacy: the `X-Elo-State` session header no longer leaks to third
  parties.** Tracking pings only attach it when the URL matches the configured
  API origin (scheme + host + port), and a redirect off the API origin strips
  it mid-flight — matching the Android SDK's origin gating.
- **Privacy: removed the `Device-Name` and `System-Version` HTTP headers** from
  SDK requests. Android never sent them; device/OS context already travels in
  the `User-Agent` and the OpenRTB `device` object.
- Preloaded ads are keyed on display position and the consent snapshot in
  addition to messages and context, so a preload is never served for a
  different slot position or after a consent change (Android parity).
- Ad request payloads omit the `context` key entirely when no context objects
  are provided, instead of sending an empty array (Android wire parity).
- New `MessageRole.summary` for hosts that condense long transcripts into one
  summary message plus the latest exchange (Android parity).
- New `NoFillReason.other(String)` case for reasons that don't fit the
  existing categories (Android parity).
- `AdNetworkAdapter` gains an optional `shutdown()` teardown hook (default
  no-op) invoked from `Elo.shutdown()` and on re-configure, mirroring
  Android's adapter lifecycle.
- **Fixed impressions never firing for SDK-rendered creatives on recent OS
  releases.** The viewability plumbing moved from `GeometryReader` +
  preference keys (which stopped delivering non-zero frames) to
  `onGeometryChange`, restoring the ≥50%-visible-for-1-second impression
  contract.
- The mediation auction deadline is now the tighter of the per-request
  timeout and the configured auction timeout, so adapters and the mediator
  agree on the deadline (Android parity).
- Impression and click delegate callbacks are no longer delivered after
  `Elo.shutdown()` or a re-configure — tracking that completes late can't
  notify a delegate about a previous session's ads.
- Elo-direct click POST delivery is temporarily disabled. Tapping still opens
  the creative destination and delivers publisher callbacks, while diagnostics
  report server receipt as unobservable. Third-party `click_trackers` remain
  server-owned.
- Elo render and impression URL trackers now validate HTTP completion and
  require 2xx responses instead of silently swallowing delivery failures.
  Their delegate callbacks wait for confirmed Elo delivery; third-party adapter
  completion remains explicitly unobservable.
- `Elo.Debug.snapshot().trackingEntries` adds a bounded, in-memory history of
  tracking attempts and privacy-safe outcomes without retaining tracker URLs,
  request headers, or chat content.
- `Elo.Debug.snapshot().entries` now includes preload outcomes and their
  redacted request payloads, so privacy and request diagnostics remain visible
  when a later `loadAd` consumes the in-memory cache.
- Diagnostics load entries now expose a locally generated `operationId` so
  hosts can distinguish concurrent or same-second requests in memory. The ID
  is omitted from plain-text diagnostics exports.



## 0.1.7 — 2026-07-11

- **`Elo.initialize` is deprecated** and will be removed in 1.0.
  `Elo.configure` is now the single entry point, in two forms:
  - `Elo.configure(publisherId:adUnitId:shareGeoLocation:geoLocationPrecision:)` —
    new convenience for Elo-only integrations; the geo controls keep the
    on-by-default sharing opt-out visible at the simplest entry point.
  - `Elo.configure(with: EloConfiguration)` — unchanged; mediation
    adapters, COPPA/TFUA, `logLevel`, and `baseUrl` live here.
  Migrating from `initialize` is a rename for most apps; if you passed
  `coppa:`/`tfua:`, move them onto `EloConfiguration`.
- `EloError.notConfigured`'s description now points at `Elo.configure(with:)`.
- **Breaking: `EloAdLayout.heroCard` is removed.** Elo-direct creatives never
  had a dedicated hero treatment (it silently fell back to
  `.compactHorizontal`), and the AdMob hero card was the only layout that
  drew a CTA button. Switch statements over `EloAdLayout` and
  `.eloAdLayout(.heroCard)` call sites need updating; renderer-backed fills
  now always use the compact card treatment, so no bundled adapter draws a
  CTA button anymore.
- The dist-repo example app is now generated from this repo's sources and
  compile-checked against the SDK on every release, so it can no longer drift
  from the published API.



## 0.1.6 — 2026-07-11

- **Behavior change for upgraders:** passive geo sharing is now **on by
  default** and configurable directly from `Elo.initialize(...)` via
  `shareGeoLocation` / `geoLocationPrecision`. Apps whose users already
  granted location permission start attaching a rounded, coarse location to
  ad requests after upgrading. The SDK still never requests location
  permission; it only reads an already-authorized location. Opt out with
  `shareGeoLocation: false` at init or `Elo.setShareGeoLocation(false)`.
  See `PRIVACY.md` before shipping.
- New `.inlineBanner` layout: a two-line strip (thumbnail, "Title · Ad"
  attribution, one-line description, chevron) for persistent slots anchored
  to the composer or keyboard.
- New `.eloKeyboardBannerAd(messages:)` view modifier that pins the inline banner
  above the keyboard with a single line — no keyboard tracking or layout
  code in the host app. The slot collapses on no-fill and keeps the current
  ad on screen while a reload is in flight.
- Elo-rendered creatives drop the CTA pill: the whole card is tappable and a
  trailing chevron signals it. `callToActionLabel` now only affects
  renderer-backed fills that draw their own CTA button.
- The inline banner's outer margins are excluded from the tap target so the
  gap next to a composer cannot register accidental ad clicks.
- Send permission-free `device.geo.country` (locale region mapped to
  alpha-3, App Store storefront fallback) and `device.geo.utcoffset` on
  every ad request. Both reflect account/settings, not physical location.
- Fixed: renderer-backed ads size to their intrinsic height again after a
  sizing regression left dead space around some creatives.
- Fixed: preloaded creatives are released on `shutdown` and reconfigure so
  mediation resources (e.g. AdMob `NativeAd` handles) no longer leak.
- Fixed: a request-owning `EloAdView` whose slot collapsed after a no-fill
  could never reload when `messages` changed.
- Docs: new host-app privacy guide (`PRIVACY.md`) with App Store
  nutrition-label and consent guidance, README privacy warnings,
  `MessageRole` mapping guidance for human-to-human chats, and an accuracy
  pass across the SDK docs.



## 0.1.5 — 2026-06-30

- Repair the public SwiftPM release path after the `0.1.3` and `0.1.4`
  binary assets drifted from the checksums recorded in their package
  manifests.
- Harden release publishing so existing GitHub release assets are treated as
  immutable and verified by downloading them after release creation.
- Update installation snippets to the current public release version and point
  iOS documentation links at the canonical `docs.elo.ad` site.



## 0.1.4 — 2026-06-27

EloAds iOS SDK 0.1.4. See the source-repo for full changelog.

## 0.1.3 — 2026-05-31

- Ship `EloAdsMediationAdMob` as a binary XCFramework alongside `EloAds`.
- Add a linker dependency target so AdMob consumers receive the Google Mobile Ads dependencies through SwiftPM.
- Keep release tags pointed at the generated SwiftPM package commit.

## 0.1.2 — 2026-05-24

Move native ad presentation control to `EloAdView` so Elo-direct and
AdMob-rendered cards share the same SwiftUI styling path. This release also
includes the configuration and AdMob documentation updates that were prepared
for the superseded `0.1.1` package update.

- Added view-level `EloAdLayout`, `.eloAdLayout(...)`, and renderer configuration propagation.
- Removed AdMob adapter initializer presentation knobs; `AdMobNetworkAdapter` now only handles network configuration.
- Deprecated `AdMobNativeStyle` and `AdMobNativeLayout` in favor of `EloAdStyle` and `EloAdLayout`.
- Rebuilt renderer-backed native views when layout/style/label configuration changes on an already-mounted `EloAdView`.
- Simplified `EloConfiguration` around publisher/ad-unit identity, privacy
  flags, log level, and optional mediation adapters.
- Replaced legacy ad view variants with the single SwiftUI `EloAdView` surface.
- Added AdMob `expectedEcpm` bidding, compact native layout updates, and
  no-CTA rendering.
- Standardized impression tracking at 50% visible for 1 second.
- Updated README snippets for the `0.1.2` package and current AdMob API.

## 0.1.0 — 2026-05-09

Rebrand from Growl to Elo across the SDK surface so iOS naming matches the Android SDK (`ad.elo.androidsdk`). No behavior change.

- Swift module `GrowlAds` → `EloAds`; mediation adapter target `GrowlAdsMediationAdMob` → `EloAdsMediationAdMob`.
- Public namespace `Growl` → `Elo`; all `GrowlFoo` types → `EloFoo` (`EloAd`, `EloAdView`, `EloAdDelegate`, `EloConfiguration`, `EloChatSession`, `EloState`, `EloError`, `EloAdStyle`, etc.).
- Lowercase: `Configuration.growl` → `.elo`; delegate callbacks `growlAdDid*` → `eloAdDid*`; `.growlAdStyle` modifier → `.eloAdStyle`; default network ID `"growl"` → `"elo"`.
- XCFramework artifact `GrowlAds.xcframework.zip` → `EloAds.xcframework.zip`.
- **Breaking change:** existing 0.0.x consumers must migrate symbol names; there is no shim. Per the project's pre-1.0 contract, breaking changes are expected on minor bumps.

## 0.0.1 — 2026-04-15

Initial public release. SDK distributed as an XCFramework via Swift Package Manager.

- `Elo` entry point: `configure`, `loadAd`, `preloadAd`, `setDelegate`, `mediationDebugSnapshot`, `enable`/`disable`, `shutdown`.
- SwiftUI ad views: `EloAdView`, `EloBadgeAdView`, `EloChatAdView` with automatic render/impression/click tracking (impression fires after ≥50% visible for 1s).
- Manual tracking hooks: `Elo.trackRender`, `Elo.trackImpression`, `Elo.trackClick`.
- Optional AdMob mediation via the `EloAdsMediationAdMob` product (source target).
- Minimum deployment target: iOS 16.
