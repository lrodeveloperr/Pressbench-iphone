import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = true
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

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
                        NavigationLink { ReportsView() } label: { menuRow("common.exports", icon: "square.and.arrow.up") }
                            .buttonStyle(.plain)
                        Divider().opacity(0.35)
                        Button { store.selectedTab = 2 } label: { menuRow("common.batchHistory", icon: "list.clipboard") }.buttonStyle(.plain)
                        Divider().opacity(0.35)
                        NavigationLink { MachinesView() } label: { menuRow("machines.title", icon: "rectangle.stack") }.buttonStyle(.plain)
                    }
                }

                PBCard {
                    VStack(spacing: 0) {
                        ExternalMenuLink(titleKey: "common.privacyPolicy", icon: "hand.raised", url: PressBenchPolicyLinks.privacy)
                        Divider().opacity(0.35)
                        ExternalMenuLink(titleKey: "common.termsOfUse", icon: "doc.text", url: PressBenchPolicyLinks.terms)
                        Divider().opacity(0.35)
                        ExternalMenuLink(titleKey: "common.safetyNotice", icon: "exclamationmark.triangle", url: PressBenchPolicyLinks.safety)
                        Divider().opacity(0.35)
                        ExternalMenuLink(titleKey: "common.purchasesPro", icon: "creditcard", url: PressBenchPolicyLinks.purchases)
                        Divider().opacity(0.35)
                        ExternalMenuLink(titleKey: "common.localDataBackups", icon: "externaldrive", url: PressBenchPolicyLinks.dataChoices)
                        Divider().opacity(0.35)
                        ExternalMenuLink(titleKey: "common.support", icon: "questionmark.circle", url: PressBenchPolicyLinks.support)
                        if language != .en {
                            Divider().opacity(0.35)
                            Text(t("onboarding.legal.policyLanguageNotice")).font(.caption).foregroundStyle(PBTheme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                        }
                    }
                }

                PBCard {
                    NavigationLink { SettingsView() } label: { menuRow("common.settings", icon: "gearshape") }.buttonStyle(.plain)
                }

                Button { onboardingCompleted = false } label: {
                    HStack {
                        Image(systemName: "rectangle.stack")
                        Text(t("more.viewOnboarding"))
                        Spacer()
                        Image(systemName: "chevron.forward")
                    }
                    .font(.headline).foregroundStyle(PBTheme.navy)
                }
                .buttonStyle(.plain).padding(18)
                .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: PBTheme.cardRadius, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: PBTheme.cardRadius).stroke(PBTheme.line, lineWidth: 1) }
            }
            .padding(.horizontal, PBTheme.pagePadding).padding(.bottom, 24)
        }
        .background(PBTheme.canvasGradient)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.22.0"
    }

    private func menuRow(_ key: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(PBTheme.primary)
            Text(t(key)).font(.headline).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.forward").foregroundStyle(PBTheme.secondary)
        }.frame(minHeight: 64)
    }
}

private struct ExternalMenuLink: View {
    let titleKey: String
    let icon: String
    let url: URL
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon).frame(width: 28).foregroundStyle(PBTheme.primary)
                Text(PBL10n.text(titleKey, language: language, locale: locale)).font(.headline).foregroundStyle(.primary)
                Spacer(); Image(systemName: "arrow.up.forward").foregroundStyle(PBTheme.secondary)
            }.frame(minHeight: 64)
        }
    }
}
