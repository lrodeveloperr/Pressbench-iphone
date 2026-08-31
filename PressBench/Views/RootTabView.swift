import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        Group {
            if store.persistenceWarning != nil {
                NavigationStack { SettingsView() }
            } else {
                TabView(selection: $store.selectedTab) {
                    NavigationStack { HomeView() }
                        .tabItem { Label(t("tab.home"), systemImage: "house") }
                        .tag(0)
                    NavigationStack { SetupsView() }
                        .tabItem { Label(t("tab.setups"), systemImage: "list.clipboard") }
                        .tag(1)
                    NavigationStack { RunsView() }
                        .tabItem { Label(t("tab.runs"), systemImage: "play.circle") }
                        .tag(2)
                    NavigationStack { MoreView() }
                        .tabItem { Label(t("tab.more"), systemImage: "ellipsis") }
                        .tag(3)
                }
                .toolbarBackground(PBTheme.paper, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .tint(PBTheme.primary)
            }
        }
        .background(PBPageBackground())
    }
}
