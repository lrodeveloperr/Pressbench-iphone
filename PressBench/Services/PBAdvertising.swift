import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

enum PBAdConfiguration {
    static let slotHeight: CGFloat = 50

    // Google's official iOS demo unit. Live ad IDs are intentionally rejected
    // until production consent, privacy-label, and reporting work is complete.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"
}

@MainActor
enum PBAdvertising {
    private static var started = false
    private static var preparationTask: Task<Bool, Never>?

    static func prepareForAds() async -> Bool {
        if let preparationTask { return await preparationTask.value }
        let task = Task { @MainActor in
            let parameters = RequestParameters()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                    continuation.resume()
                }
            }
            try? await ConsentForm.loadAndPresentIfRequired(from: nil)
            guard ConsentInformation.shared.canRequestAds else { return false }
            startIfNeeded()
            return true
        }
        preparationTask = task
        return await task.value
    }

    static func presentPrivacyOptions() async {
        _ = await prepareForAds()
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }

    private static func startIfNeeded() {
        guard !started else { return }
        started = true
        MobileAds.shared.requestConfiguration.maxAdContentRating = GADMaxAdContentRating.general
        MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        MobileAds.shared.start()
    }
}

struct PBTestBannerSlot: View {
    @State private var canRequestAds = false

    var body: some View {
        Group {
            if canRequestAds { PBTestBannerView() }
            else { Color.clear.accessibilityHidden(true) }
        }
            .frame(width: 320, height: PBAdConfiguration.slotHeight)
            .frame(maxWidth: .infinity, minHeight: PBAdConfiguration.slotHeight,
                   maxHeight: PBAdConfiguration.slotHeight)
            .background(PBTheme.paper)
            .overlay(alignment: .top) { Divider() }
            .accessibilityIdentifier("pb.ad.banner")
            .accessibilityElement(children: .contain)
            .task { canRequestAds = await PBAdvertising.prepareForAds() }
    }
}

private struct PBTestBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
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
