import SwiftUI

@main
struct PressBenchApp: App {
    @StateObject private var store: PressBenchStore
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = false
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue

    #if PRESSBENCH_UI_TESTING
    private static var screenshotModeEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--pressbench-ipad-marketing-screenshot") ||
            ProcessInfo.processInfo.environment["PRESSBENCH_IPAD_MARKETING_SCREENSHOT"] == "1"
    }
    #endif

    init() {
        #if DEBUG || PRESSBENCH_UI_TESTING
        PressBenchUITestBootstrap.resetIfRequested()
        #endif
        let productionStore = PressBenchStore.production()
        #if PRESSBENCH_UI_TESTING
        if Self.screenshotModeEnabled {
            UserDefaults.standard.set(true, forKey: "pressbench.onboarding.completed")
            do { try productionStore.loadScreenshotFixture() }
            catch { fatalError("iPad screenshot fixture failed: \(error)") }
        }
        #endif
        _store = StateObject(wrappedValue: productionStore)
    }

    var body: some Scene {
        WindowGroup {
            let language = AppLanguageStorage.resolved(rawValue: languageRaw)
            let locale = Locale(identifier: language.localeIdentifier(deviceLocale: .current))
            #if PRESSBENCH_UI_TESTING
            let screenshotMode = Self.screenshotModeEnabled
            #else
            let screenshotMode = false
            #endif

            Group {
                if (onboardingCompleted || screenshotMode) && store.operationalReady {
                    RootTabView()
                } else {
                    OnboardingFlowView(completed: $onboardingCompleted)
                }
            }
            .environmentObject(store)
            .environment(\.pbLanguage, language)
            .environment(\.locale, locale)
            .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
            .preferredColorScheme(.light)
            .tint(PBTheme.primary)
            .task {
                await store.start()
            }
        }
    }
}

#if DEBUG || PRESSBENCH_UI_TESTING
private enum PressBenchUITestBootstrap {
    static func resetIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--pressbench-ui-test-reset") {
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let pressBenchDirectory = appSupport.appendingPathComponent("PressBench", isDirectory: true)
            do {
                if FileManager.default.fileExists(atPath: pressBenchDirectory.path) {
                    try FileManager.default.removeItem(at: pressBenchDirectory)
                }
            } catch {
                fatalError("UI-test reset failed: \(error)")
            }
        }
        if arguments.contains("--pressbench-ui-test-limit-reached") {
            UserDefaults.standard.set(PBUsageMeter.freePressLimit, forKey: "pressbench.usage.completedPresses")
        }
    }
}
#endif
