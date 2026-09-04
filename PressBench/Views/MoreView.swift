import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    PBPageHeader(title: t("more.title"))
                    Text(PBL10n.format("more.versionFormat", language: language, locale: locale, appVersion as NSString))
                        .font(.caption).foregroundStyle(PBTheme.secondary)
                }

                PBCard {
                    VStack(spacing: 0) {
                        NavigationLink { ReportsView() } label: { menuRow("report.productionReport", icon: "doc.richtext") }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pb.more.reports")
                        Divider().opacity(0.35)
                        Button { store.selectedTab = 2 } label: { menuRow("common.batchHistory", icon: "list.clipboard") }.buttonStyle(.plain)
                        Divider().opacity(0.35)
                        NavigationLink { MachinesView() } label: { menuRow("machines.title", icon: "rectangle.stack") }.buttonStyle(.plain)
                    }
                }

                NavigationLink { SettingsView() } label: {
                    PBCard {
                        menuRow("common.settings", icon: "gearshape")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pb.more.settings")
            }
            .padding(.horizontal, PBTheme.pagePadding).padding(.bottom, 24)
        }
        .background(PBTheme.canvasGradient)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func menuRow(_ key: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(PBTheme.primary)
            Text(t(key)).font(.headline).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.forward").foregroundStyle(PBTheme.secondary)
        }
        .pbFullSurfaceTarget(minHeight: 64)
    }
}
