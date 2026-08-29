import GoogleMobileAds
import SwiftUI
import UIKit

enum PBAdConfiguration {
    static let slotHeight: CGFloat = 50

    // Google's official iOS demo unit. Live ad IDs are intentionally rejected
    // until production consent, privacy-label, and reporting work is complete.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"
}

@MainActor
private enum PBAdvertising {
    private static var started = false

    static func startIfNeeded() {
        guard !started else { return }
        started = true
        MobileAds.shared.requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
        MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        MobileAds.shared.start()
    }
}

struct PBTestBannerSlot: View {
    var body: some View {
        PBTestBannerView()
            .frame(width: 320, height: PBAdConfiguration.slotHeight)
            .frame(maxWidth: .infinity, minHeight: PBAdConfiguration.slotHeight,
                   maxHeight: PBAdConfiguration.slotHeight)
            .background(PBTheme.paper)
            .overlay(alignment: .top) { Divider() }
            .accessibilityIdentifier("pb.ad.banner")
    }
}

private struct PBTestBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        PBAdvertising.startIfNeeded()
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = PBAdConfiguration.testBannerUnitID
        banner.rootViewController = Self.activeRootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        if banner.rootViewController == nil {
            banner.rootViewController = Self.activeRootViewController()
        }
    }

    private static func activeRootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        return scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    }
}

private struct PBTestBannerModifier: ViewModifier {
    let visible: Bool

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if visible { PBTestBannerSlot() }
        }
    }
}

extension View {
    func pbTestBanner(visible: Bool) -> some View {
        modifier(PBTestBannerModifier(visible: visible))
    }
}
