import SwiftUI
import EloAds
import EloAdsMediationAdMob

// Replace these with your own publisher / ad-unit IDs from the Elo
// dashboard before shipping. The example will run with the placeholders
// in place but Elo-direct requests won't return real fills until you
// swap them — untouched runs surface as a no-fill / error outcome rather
// than silently calling out to a stranger's account. The AdMob ad-unit
// below is Google's documented public test unit and is safe to use
// unchanged in the demo.
private enum DemoConfig {
    static let eloPublisherID = "your-publisher-id"
    static let eloAdUnitID    = "your-ad-unit-id"
    static let admobTestNativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
}

@main
struct EloAdsExampleApp: App {
    init() {
        // `Elo.configure(with:)` is the SDK's single entry point; the
        // `adapters` list below is what opts this demo into AdMob
        // mediation. Leave it empty for an Elo-only integration.
        Elo.configure(
            with: EloConfiguration(
                elo: EloNetworkConfiguration(
                    publisherId: DemoConfig.eloPublisherID,
                    adUnitId: DemoConfig.eloAdUnitID
                ),
                adapters: [
                    AdMobNetworkAdapter(
                        adUnitId: DemoConfig.admobTestNativeAdUnitID,
                        // GoogleMobileAds native ads don't expose a bid
                        // price, so Elo's first-price auction compares
                        // AdMob using this fixed eCPM. Set it to your
                        // realized AdMob value in production.
                        expectedEcpm: 1.0
                    ),
                ]
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var adResult: AdResult?
    @State private var isLoading = false

    private let messages: [ChatMessage] = [
        ChatMessage(role: .user, content: "What's the best running shoe for marathon training?"),
        ChatMessage(role: .assistant, content: "For marathon training, you'll want shoes with good cushioning and durability. Brands like Hoka, Nike, and Brooks are popular picks."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Elo Ads Demo")
                .font(.largeTitle.bold())

            Text("Tap below to request a contextual ad. The auction runs Elo-direct and AdMob in parallel; the higher-eCPM creative renders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: loadAd) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Load ad")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            // EloAdView renders the loaded ad, handles impression and click
            // lifecycle events, and hides itself on `.noFill` / `.error`.
            // Elo-direct clicks still open the destination while client-side
            // click POST delivery is temporarily disabled.
            EloAdView(result: adResult)
                .padding(.horizontal)

            if let adResult { outcomeRow(for: adResult) }

            Spacer()
        }
        .padding()
    }

    private func loadAd() {
        isLoading = true
        Task {
            adResult = await Elo.loadAd(messages: messages)
            isLoading = false
        }
    }

    @ViewBuilder
    private func outcomeRow(for result: AdResult) -> some View {
        // `AdResult` ships in a binary framework, so it can grow cases in
        // future SDK releases — hence `@unknown default`.
        let (label, color): (String, Color) = switch result {
        case .loaded:           ("Loaded",  .green)
        case .noFill(let r):    ("No fill: \(r)", .orange)
        case .error(let m):     ("Error: \(m)",   .red)
        @unknown default:       ("Unknown result", .secondary)
        }
        Text(label)
            .font(.footnote.monospaced())
            .foregroundStyle(color)
    }
}
