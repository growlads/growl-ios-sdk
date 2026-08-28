# Changelog

## Unreleased

## 0.4.1 — 2026-08-28

- **Fix: retained ad views no longer report duplicate renders or impressions
  after SDK reconfiguration.** Per-opportunity tracking latches now last for
  the process lifetime, including across `Elo.configure()` and
  `Elo.shutdown()`, so remounting an old view cannot bill the same opportunity
  again.

- **Fix: an ad covered by an overlay, or on screen while the app is not
  frontmost, no longer counts as an impression.** Viewability was measured
  purely geometrically, so a sheet, dialog, or any view drawn over the ad left
  its frame untouched underneath and a fully covered ad measured as fully
  visible. Backgrounding was invisible the same way. Neither fires a layout or
  geometry event, so an in-flight dwell was never cancelled either.

  The measurement now scales the geometric fraction by the share of it the
  window's hit test still reaches, the dwell requires the app to be frontmost,
  and a bounded periodic probe resets the full one-second dwell whenever a
  cover appears. Removing the cover automatically starts a fresh dwell.
  Leaving the foreground cancels an armed dwell and returning arms a fresh one.

  What this catches is a cover with a view of its own above your screen: a
  sheet, an alert, any presented controller. Three kinds stay undetectable, as
  they are for any hit-test based check — a cover that declines touches itself
  (`allowsHitTesting(false)`), a SwiftUI sibling drawn over the ad inside the
  same view (a `ZStack` or `.overlay` scrim has no view of its own for the hit
  test to return), and a cover in a separate `UIWindow`.

- **Change: the ad disclosure moved onto the creative mark's corner, and the
  strip's mark is now a ringed circle.** In 0.4.0 the disclosure became a
  badge in the surface's top-trailing corner; it now rides the top-trailing
  corner of the creative mark itself. Badging the artwork reads as marking the
  creative rather than the container, and it keeps the disclosure clear of
  whatever closes the row — the surface corner overlaid the call-to-action
  pill whenever one ran to the edge. It hangs off the mark's corner rather
  than sitting flush inside it, so it nests against the artwork instead of
  covering it, and on the strip it is a point smaller, since that mark is a
  fraction of the card's.

  The badge itself is restyled: a near-white disc with a hairline black ring
  and black copy at medium weight, squared up from a capsule since the default
  copy is two characters. Longer copy relaxes it back into a capsule rather than being
  squeezed. Those are the only fixed colors in the SDK — the badge sits on
  creative artwork rather than on a surface the theme controls, so a fill that
  followed light/dark would read against one creative and vanish into the
  next. `EloAdDisclosure.color` and `EloAdStyle.badgeColor` still override it,
  which takes the ring off and inverts the copy as before.

  The strip's mark now carries a hairline grey ring, so a white or near-white
  logo has an edge of its own instead of dissolving into the surface at that
  size; the card's mark is large enough to stand without one.
  The card's mark stays a rounded square and the strip's stays a circle:
  creative artwork is a brand mark far more often than photography, and marks
  are routinely wide wordmarks, which a circular crop takes the ends off. The
  strip's mark is small enough to read as an avatar, where a wordmark is
  unreadable either way. A creative with no artwork has no
  mark to ride, and the badge keeps its 0.4.0 position in the surface's
  top-trailing corner. The copy, the `sponsoredLabel` API, and the guarantee
  that the disclosure is always drawn and never truncated are unchanged.

- **Change: the strip's creative mark is larger, without the strip changing
  height.** The strip's row is pinned to the call-to-action button's 44pt tap
  target, so its mark grew into height the row already paid for (34pt → 40pt).
  The card's mark is unchanged at 56pt: the card's row is pinned to the mark
  itself, so a larger one would have had to come out of the card's own padding,
  and at that size it crowded the text column rather than reading as an
  accompanying mark. The card stays 80pt tall. Horizontal padding is untouched
  on both, so nothing shifts laterally. `EloAdLoadingView`'s skeleton follows,
  since a placeholder that lands at a different height than the fill shoves the
  surrounding UI.

- **Fix: an ad faded in by the host app now reports an impression.** Viewability
  treated a transparent ad as not on screen, and nothing recomputes it when
  opacity changes — the measurement only wakes on layout, geometry, and window
  changes. An app that animated its ad slot from `opacity(0)` therefore latched
  the ad at "nothing visible" for its entire showing: fully opaque and in front
  of the user, but unable to reach the MRC bar, so no impression ever fired.
  Renders were unaffected, which is why the slot looked healthy while
  impressions fell away. Viewability is now purely geometric — what clips the ad
  and the window, never `alpha` or `isHidden` — matching how the Android SDK has
  always measured. Publishers who fade, cross-fade, or otherwise animate the
  opacity of the ad slot should expect their iOS impressions to return to the
  render volume they already see. Introduced in 0.3.0.

- **Fix: an ad request can no longer stall on WebKit.** The SDK reads the
  browser user agent once per install by spinning up a `WKWebView`, and that
  read sits on the path every bid awaits. WebKit's cold start is unbounded —
  it has to launch its own WebContent and GPU helper processes first, measured
  at over five minutes each on a cold simulator — and the auction deadline
  could not cancel it, because the underlying callback is not cancellable. On
  an unlucky first launch that meant an ad request hanging far past the point
  the auction had given up. The fetch is now bounded: if the browser user agent
  is not available within two seconds the request proceeds without it and a
  later request picks it up once WebKit is warm. The value is still cached
  after the first successful read, so steady-state behaviour is unchanged.

- **Fix: `EloChatSession.setMessages` no longer fires a second, unusable ad
  request per user turn.** It preloaded with no display position while every
  slot loads with one (`.banner` for the keyboard banner), and the display
  position is part of the preload cache key — so the preloaded ad could never
  be taken and the slot always went to the network anyway. Each user turn
  therefore billed two ad opportunities for one render, halving every
  opportunity-based ratio on your dashboards. Verified end to end against a
  live ad server: 29 opportunities for 14 renders before, 7 for 7 after.
  `setMessages` now only stores the transcript. To warm the cache, call
  `Elo.preloadAd(...)` yourself with the position the slot will render into.


## 0.4.0 — 2026-08-19

- **New: `Elo.setUserIdentity(userIdentifier:userData:)` writes both halves of
  the identity at once.** The identifier and the user data are persisted as one
  Keychain record, so setting them with the two existing setters in sequence
  left an intermediate state on disk: an account switch stored `(B, A's contact
  details)` until the second call landed, and an ad request or a process kill in
  that window sent or retained one account's PII under the other's identifier.
  Prefer the new call from your auth-state hook whenever both are changing.
  `setUserIdentifier(_:)` and `setUserData(_:)` are unchanged and still correct
  when only one is.

- **Change: the ad disclosure moved off the headline into a corner badge.** It
  used to lead the attribution line as `Ad • Headline`, which cost the copy
  roughly five characters of the narrowest column in the SDK — on the keyboard
  strip especially, that is space the headline needs. It is now a small capsule
  overlaid in the surface's top-trailing corner: the headline gets the full
  width of its column, and the disclosure still cannot be truncated, because it
  is outside the text flow entirely rather than merely at the head of it.
  Applies to the compact card and the inline banner alike, and card height is
  unchanged.

  One consequence worth knowing: `EloAdDisclosure.color` now *fills* the badge
  capsule rather than coloring inline text, and the copy is drawn over it in
  the card background color.

  If a UI test asserted the combined `"Ad • Headline"` label, split it — the
  disclosure and the headline are separate elements now.

- **Breaking: `sponsoredLabel` now takes an `EloAdDisclosure`, not a `String`.**
  The new value carries the disclosure copy plus an optional `font`, `color`
  and `accessibilityIdentifier`, so you can restyle the disclosure and give UI
  tests a stable handle on it. String *literals* are unaffected —
  `sponsoredLabel: "Anzeige"` still compiles — but a `String` **variable** now
  needs the explicit wrap, and that includes anything returned by
  `NSLocalizedString`:
  `sponsoredLabel: EloAdDisclosure(NSLocalizedString("ad.sponsored", comment: ""))`.
  Applies to every `EloAdView` initializer and to `eloKeyboardBannerAd`.

  It is a value rather than a `View` on purpose. `EloAdView` draws the badge
  itself, overlaid on the surface, which is what makes the disclosure
  untruncatable: nothing in the layout can squeeze or clip it. A
  publisher-supplied view would have to be laid out beside the headline, where
  a long headline can do both. `accessibilityIdentifier` names the badge, which
  is its own element.

  `EloAdRenderConfiguration.sponsoredLabel` is unchanged and still a `String`:
  adapters build their own native views, so there is nothing there for a font
  or an identifier to bind to. No adapter needs a change, and mediated fills
  keep the look they have today — they take your disclosure *copy* and render
  it in the adapter's own treatment, colored from `EloAdStyle.badgeColor` like
  the rest of that card.

- **Fix: the ad slot no longer changes height when the request lands.** The
  strip's row was sized by whatever filled its trailing slot — a call-to-action
  button carries a 44pt tap target, a chevron is a fraction of that — so a CTA
  fill grew the slot 10pt on arrival and the loading placeholder matched only
  the chevron case. Both layouts and the placeholder now reserve the same row
  height (44pt on the strip, 56pt on the card), which also fixes the card's
  mirror image: a creative with no artwork collapses its tile and used to
  *shrink* the card below the placeholder.

- **Fix: creative artwork is fitted rather than centre-cropped.** A brand mark
  is rarely square, and filling the tile cropped a wide wordmark down to
  whatever sat in the middle of it — on the strip's circular mark, often a
  featureless block of the brand's colour. The whole mark is now shown, drawn
  with high-quality interpolation, and the strip's mark grew from 30pt to 34pt
  (no height change: the row was already taller than it).

- **Fix: the loading placeholder's corners are rounded again.** Its shimmer
  highlight was composited after the rounded clip and repainted the corners,
  so the placeholder read as a square while it animated. Its hairline border
  was half-clipped for the same reason and now matches the filled ad's.

- **Change: an image-only creative no longer gets an invented description.**
  A creative with an image but no description used to render the SDK's own
  copy, "Click to learn more →", whenever there was no CTA button. With the
  call-to-action backend-managed, the SDK writes no call-to-action of its own:
  such a creative now renders its headline and nothing beneath it. The
  trailing disclosure chevron still signals the row is tappable, unchanged.
  Android never had this fallback, so both platforms now agree.

- **Breaking: `callToActionLabel` is gone from `EloAdView` and
  `eloKeyboardBannerAd`.** Call-to-action copy is backend-managed now: it
  arrives on the creative as `EloAd.ctaText` and labels the pill both layouts
  draw. The publisher-supplied parameter only ever reached renderer-backed
  fills and no bundled adapter read it, so nothing that shipped ever rendered
  it. Drop the argument from your call sites.
  `EloAdRenderConfiguration.callToActionLabel` goes with it, so a third-party
  renderer that read it must drop it too.

- **Breaking: `openLinkAccessibilityLabel` and the VoiceOver hint it carried
  are both gone.** The parameter is removed from `EloAdView` and
  `eloKeyboardBannerAd`, and the tappable surface no longer sets an
  `accessibilityHint` at all — `EloAdRenderConfiguration` drops the field with
  it, and the bundled AdMob renderer stops setting the hint too.

  This is a deliberate accessibility reduction, so it is worth stating plainly:
  VoiceOver used to announce "Open sponsored link" after the element's label
  and role, telling the listener that activating it leaves the app for an
  advertiser's destination. It no longer does. Sighted users still get that
  from the "Ad" disclosure, the button styling and the chevron; a VoiceOver
  user now gets the disclosure but no statement of where activation leads.
  Nothing else about the ad's accessibility changes — the disclosure, the
  element labels and the button role are all untouched.

- **New: creatives can carry their own call-to-action button.** Some demand
  sources send a label such as "Learn more" with the creative. Where one
  arrives, both layouts draw it as a pill in the trailing slot in place of the
  disclosure chevron. `EloAd.ctaText` exposes the label, and
  `EloAdStyle.callToActionBackground` / `callToActionForeground` color the
  pill.

- **Change: the two layouts take deliberately different tap rules.** The
  in-chat card is one tap target from edge to edge, whether or not the
  creative sends a label — in a transcript the card reads as a single object,
  and there is no neighbouring control for a stray tap to hit, so its pill is
  decoration rather than a second button. The keyboard banner does the
  opposite: when the creative sends a label, only that button taps, because
  the strip sits directly under the reader's thumb beside the composer and an
  edge-to-edge target there invites accidental clicks. A strip without a label
  keeps its whole row tappable behind the chevron. Either way the tap opens
  the same destination, and render and impression tracking stay on the
  container, so viewability is unaffected.

- **Change: the keyboard banner shows its loading skeleton by default.**
  `showLoadingPlaceholder` on `eloKeyboardBannerAd` now defaults to `true`,
  matching `EloAdView`. The skeleton stands in at the strip's own
  size, so the composer above keeps its place when an ad arrives, and the slot
  reads as loading rather than as empty. Pass `false` to keep the keyboard
  edge completely clear until an ad fills.

- **Fix: a slow creative image no longer holds the whole ad in its skeleton.**
  The thumbnail now carries its own shimmer and swaps in when the image
  finishes, so the headline and description render as soon as the ad does.

- **Change: the keyboard banner's strip was retuned to fit real creatives.**
  A circular brand mark, tighter gutters, and a smaller type scale on the
  attribution line — at the previous size an ordinary advertiser name
  ellipsized before the strip had drawn anything else.

- **New: `Elo.setUserData` shares first-party user data on ad requests.** Apps
  that know their signed-in user can pass age, gender, email, and phone number.
  The fields are recorded server-side for upcoming targeting features and have
  no effect on ad selection yet. Pass contact details as they are: they travel
  over HTTPS and are SHA-256 hashed at the ad server before anything is stored,
  so Elo never persists a plain email address or phone number, and you don't
  have to hash them yourself. Give a phone number its country code (E.164),
  since without one it is ambiguous and the server discards it. The SDK does
  not validate what you set — values are forwarded as supplied and the server
  normalizes each one and drops whatever it can't use, so there is one set of
  rules rather than two that can disagree. Like `setUserIdentifier`, the data
  is persisted on the device and encrypted at rest, so you set it once rather
  than on every launch; `shutdown()` erases the stored copy while a
  re-configure does not. Because it outlives a sign-out, clearing it on
  sign-out is an obligation — set both this and the identifier from one
  auth-state hook, which is also the place that keeps a stored copy from going
  stale when the user changes their email or phone. Each call
  replaces the whole object. The data never joins tracking pings, and the ad
  server discards it entirely on requests flagged COPPA or TFUA, and on any
  request where GDPR applies. Sharing contact details means your app transmits an email
  address and phone number to Elo — account for that in your privacy policy and
  App Store nutrition label; see `PRIVACY.md`.


- **Change: publisher-supplied identity now survives an app restart.** The
  identifier from `Elo.setUserIdentifier` and the data from `Elo.setUserData`
  used to live in memory only, so an app that keeps people signed in between
  launches reported as anonymous on every relaunch until the user happened to
  sign in again. Both are now stored on the device as one encrypted record —
  the Keychain, as a `ThisDeviceOnly` item so it never reaches
  iCloud Keychain or an encrypted device backup — and are read back at
  launch, so you set identity once rather than on every start. The trade is
  that identity now outlives a sign-out you don't signal: call
  `Elo.setUserIdentifier(nil)` and `Elo.setUserData(nil)` when the user signs
  out, or the next person on that device inherits both. Upgrading needs no
  migration — there was never a stored record to read, so the first launch on
  this version starts anonymous exactly as before, and an integration that
  already sets identity each launch keeps working unchanged. What does change
  for it: app termination used to clear identity on its behalf, so an
  integration that never signalled sign-out was covered by the process boundary
  and no longer is. `shutdown()` erases the
  stored record. Nothing is ever written in plaintext — if the platform store
  is unavailable the SDK keeps identity in memory for that process instead of
  falling back to an unprotected file. Storing contact details on the device is
  worth a line in your privacy policy and App Store nutrition label; see `PRIVACY.md`.


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
