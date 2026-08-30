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
    static let consentDidChange = Notification.Name("PressBenchAdvertisingConsentDidChange")
    private static var started = false
    private static var preparationTask: Task<Bool, Never>?

    static var isUITestRun: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--pressbench-ui-test") }
        #else
        false
        #endif
    }

    static var isMarketingCapture: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--pressbench-marketing-capture")
        #else
        false
        #endif
    }

    static var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

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

    static func presentPrivacyOptions() async -> Bool {
        _ = await prepareForAds()
        guard privacyOptionsRequired else { return false }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            preparationTask = nil
            NotificationCenter.default.post(name: consentDidChange, object: nil)
            return true
        } catch {
            return false
        }
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
    @State private var consentResolved = false
    @State private var bannerLoadResolved = false
    @State private var bannerLoaded = false
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if PBAdvertising.isUITestRun {
                Color.clear
                    .frame(width: 320, height: PBAdConfiguration.slotHeight)
                    .frame(maxWidth: .infinity,
                           minHeight: PBAdConfiguration.slotHeight,
                           maxHeight: PBAdConfiguration.slotHeight)
                    .background(PBTheme.paper)
                    .overlay(alignment: .top) { Divider() }
                    .accessibilityIdentifier("pb.ad.banner")
                    .accessibilityElement()
                    .accessibilityLabel(PBL10n.text("ads.bannerLabel", language: language, locale: locale))
            } else if canRequestAds {
                PBTestBannerView { loaded in
                    bannerLoaded = loaded
                    bannerLoadResolved = true
                }
                    .frame(width: 320, height: bannerLoadResolved && !bannerLoaded ? 0 : PBAdConfiguration.slotHeight)
                    .frame(maxWidth: .infinity,
                           minHeight: bannerLoadResolved && !bannerLoaded ? 0 : PBAdConfiguration.slotHeight,
                           maxHeight: bannerLoadResolved && !bannerLoaded ? 0 : PBAdConfiguration.slotHeight)
                    .clipped()
                    .background(PBTheme.paper)
                    .overlay(alignment: .top) { Divider() }
                    .accessibilityIdentifier("pb.ad.banner")
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(PBL10n.text("ads.bannerLabel", language: language, locale: locale))
                    .accessibilityHidden(bannerLoadResolved && !bannerLoaded)
            } else if !consentResolved {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: PBAdConfiguration.slotHeight,
                           maxHeight: PBAdConfiguration.slotHeight)
                    .accessibilityHidden(true)
            }
        }
        .task {
            guard !PBAdvertising.isUITestRun else { return }
            canRequestAds = await PBAdvertising.prepareForAds()
            consentResolved = true
        }
        .onReceive(NotificationCenter.default.publisher(for: PBAdvertising.consentDidChange)) { _ in
            Task { @MainActor in
                bannerLoadResolved = false
                bannerLoaded = false
                canRequestAds = await PBAdvertising.prepareForAds()
                consentResolved = true
            }
        }
    }
}

private struct PBTestBannerView: UIViewRepresentable {
    let onLoadStateChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoadStateChange: onLoadStateChange) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = PBAdConfiguration.testBannerUnitID
        banner.rootViewController = Self.activeRootViewController()
        banner.delegate = context.coordinator
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

    final class Coordinator: NSObject, BannerViewDelegate {
        let onLoadStateChange: (Bool) -> Void

        init(onLoadStateChange: @escaping (Bool) -> Void) {
            self.onLoadStateChange = onLoadStateChange
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onLoadStateChange(true)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onLoadStateChange(false)
        }
    }
}

private struct PBTestBannerModifier: ViewModifier {
    let visible: Bool

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if visible {
                if !PBAdvertising.isMarketingCapture {
                    PBTestBannerSlot()
                        .background(PBTheme.paper)
                }
            }
        }
        .background(PBTheme.paper.ignoresSafeArea(edges: .bottom))
    }
}

extension View {
    func pbTestBanner(visible: Bool) -> some View {
        modifier(PBTestBannerModifier(visible: visible))
    }
}
