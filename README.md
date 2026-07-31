# Elo iOS SDK

Monetize your iOS app with contextual ads powered by [Elo](https://elo.ad/).

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies**, then enter:

```
https://github.com/growlads/elo-ios-sdk
```

Pick **Up to Next Major Version** from `0.1.9`, and add the `EloAds` library to your target.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/growlads/elo-ios-sdk", from: "0.1.9"),
]
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "EloAds", package: "elo-ios-sdk"),
    ]
),
```

`import EloAds` is the core SDK surface. If you also want AdMob mediation,
link the `EloAdsMediationAdMob` product as shown below.

## Quick start

```swift
import EloAds

// 1. Configure once at app launch.
Elo.configure(
    publisherId: "your-publisher-id",
    adUnitId: "your-ad-unit-id"
)

// 2. Build a request from the surrounding conversation.
let messages: [ChatMessage] = [
    ChatMessage(role: .user, content: "What's the best running shoe?"),
    ChatMessage(role: .assistant, content: "Here are some top picks..."),
]

let contextObjects = [
    ContextObject(type: "screen", description: "Running shoe recommendations"),
]

// 3. Ask for an ad. `loadAd` is non-throwing and returns an exhaustive enum.
let result = await Elo.loadAd(messages: messages, contextObjects: contextObjects)

switch result {
case .loaded(let ad):
    print("Ad loaded: \(ad)")
case .noFill(let reason):
    // Not an error — just no match for this context.
    print("No fill: \(reason)")
case .error(let message):
    print("Ad error: \(message)")
}
```

## SwiftUI

`EloAdView` accepts an `AdResult` directly and hides itself on `.noFill` or `.error`, so you can hand it the result without branching:

```swift
import SwiftUI
import EloAds

struct ChatView: View {
    @State private var adResult: AdResult?

    let messages: [ChatMessage] = [
        ChatMessage(role: .user, content: "What's the best running shoe?"),
        ChatMessage(role: .assistant, content: "Here are some top picks..."),
    ]

    var body: some View {
        VStack {
            // ...your chat content...

            EloAdView(result: adResult)
        }
        .task {
            adResult = await Elo.loadAd(messages: messages)
        }
    }
}
```

`EloAdView` automatically tracks render, click, and impression events.
Impressions are counted after the ad is at least 50% visible for 1 second.
For localized surfaces, pass static labels:

```swift
EloAdView(
    result: adResult,
    sponsoredLabel: NSLocalizedString("ad.sponsored", comment: ""),
    openLinkAccessibilityLabel: NSLocalizedString("ad.open_link", comment: ""),
    layout: .compactHorizontal
)
```

Use `.eloAdStyle(...)` and `.eloAdLayout(...)` higher in the SwiftUI tree to
style both Elo-direct and renderer-backed mediation fills consistently.

## Mediation (optional)

> **Available from v0.1.2.** Earlier releases don't include the current
> `EloAdsMediationAdMob` API shown below.

Elo runs a parallel first-price auction across its own demand and any mediation adapters you register. Adapters are opt-in: each one is a separate library product on this same package, so you only link the networks you actually want bidding.

### Available adapters

| Network | Product | Status |
|---------|---------|--------|
| AdMob | `EloAdsMediationAdMob` | First-party |

### Wiring it up

Add the `EloAdsMediationAdMob` product to your target and switch from `Elo.configure(publisherId:adUnitId:)` to `Elo.configure(with:)` so you can pass an `adapters` list:

```swift
dependencies: [
    .package(url: "https://github.com/growlads/elo-ios-sdk", from: "0.1.9"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "EloAds", package: "elo-ios-sdk"),
            .product(name: "EloAdsMediationAdMob", package: "elo-ios-sdk"),
        ]
    ),
]
```

```swift
import EloAds
import EloAdsMediationAdMob

Elo.configure(
    with: EloConfiguration(
        elo: EloNetworkConfiguration(
            publisherId: "YOUR_PUBLISHER_ID",
            adUnitId: "YOUR_AD_UNIT_ID"
        ),
        adapters: [
            AdMobNetworkAdapter(
                adUnitId: "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYYYY",
                // GoogleMobileAds doesn't expose a programmatic bid price,
                // so pass your realized eCPM from AdMob reporting.
                expectedEcpm: 2.40
            )
        ]
    )
)
```

Set `expectedEcpm` to `0.0` to make AdMob last-resort backfill. When AdMob ties
the Elo first-party lane at `0.0`, Elo wins the tie; AdMob only wins when no Elo
bid is available and no other adapter outbids `0.0`.

Render, click, and impression telemetry are unchanged — adapter creatives
surface through the same `EloAdView` component.

Per-adapter setup (manifest keys, expected eCPM, consent forwarding, and
view-level presentation) lives in [`Sources/EloAdsMediationAdMob/README.md`](Sources/EloAdsMediationAdMob/README.md).
Writing a third-party adapter against the v1 contract isn't documented publicly
yet — open an issue and tag a maintainer if that's what you're after.

## Example

The [`Example/`](Example/) folder contains a runnable iOS app you can open in Xcode to see the full integration end-to-end.

```sh
cd Example
open EloAdsExample.xcodeproj
```

Press ▶ in Xcode (iPhone simulator) and open a chat. Each chat demonstrates one of the two ad formats. Replace the placeholder publisher/ad-unit IDs in `Sources/EloAdsExampleApp.swift` with values from your Elo dashboard before expecting real fills.

| Inline banner | Keyboard banner |
|---|---|
| Renders in the message feed. | Pins above the keyboard while the composer is focused. |
| <img src="Example/Screenshots/inline-banner.png" alt="Inline banner ad rendered in the chat feed" width="280"> | <img src="Example/Screenshots/keyboard-banner.png" alt="Banner ad pinned above the keyboard" width="280"> |

## Crash reporting

dSYM files for symbolicating crashes are attached to each [GitHub release](https://github.com/growlads/elo-ios-sdk/releases). Drop the matching version's archive into Crashlytics, Sentry, or Xcode Organizer.

## License

See [LICENSE](LICENSE).
