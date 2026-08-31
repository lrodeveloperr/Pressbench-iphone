import SwiftUI

@main
struct PressBenchApp: App {
    @StateObject private var store: PressBenchStore
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = false
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue

    init() {
        #if DEBUG
        PressBenchUITestBootstrap.resetIfRequested()
        #endif
        let store = PressBenchStore.production()
        #if DEBUG
        PressBenchUITestBootstrap.seedIfRequested(store)
        #endif
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            let language = AppLanguageStorage.resolved(rawValue: languageRaw)
            let locale = Locale(identifier: language.localeIdentifier(deviceLocale: .current))

            Group {
                if onboardingCompleted && store.operationalReady {
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
            .task { await store.start() }
        }
    }
}

#if DEBUG
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

    @MainActor
    static func seedIfRequested(_ store: PressBenchStore) {
        guard ProcessInfo.processInfo.arguments.contains("--pressbench-ui-test-single-setup") else { return }
        do {
            try store.seedSingleRunnableSetupForUITest()
            UserDefaults.standard.set(true, forKey: "pressbench.onboarding.completed")
        } catch {
            fatalError("Focused UI-test seed failed: \(error)")
        }
    }
}
#endif
