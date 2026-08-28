import SwiftUI

@main
struct PressBenchApp: App {
    @StateObject private var store = PressBenchStore.production()
    @StateObject private var appleBackup = AppleBackupManager()
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = false
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage(PBAppearancePreference.storageKey) private var appearanceRaw = PBAppearancePreference.system.rawValue

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
            .environmentObject(appleBackup)
            .environment(\.pbLanguage, language)
            .environment(\.locale, locale)
            .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
            .preferredColorScheme((PBAppearancePreference(rawValue: appearanceRaw) ?? .system).colorScheme)
            .tint(PBTheme.primary)
            .task {
                await store.start()
                appleBackup.attach(to: store)
            }
        }
    }
}
