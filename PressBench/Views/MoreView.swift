import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = true
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingUpgrade = false
    @State private var privacyOptionsAvailable = false
    @State private var privacyOptionsFailed = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    PBPageHeader(title: t("more.title"))
                    Text(PBL10n.format("more.versionFormat", language: language, locale: locale, "0.21.4" as NSString))
                        .font(.caption).foregroundStyle(PBTheme.secondary)
                }

                PBCard {
                    VStack(spacing: 0) {
                        NavigationLink { ReportsView() } label: { menuRow("report.productionReport", icon: "doc.richtext") }
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
                        if store.canManageMonthlySubscription {
                            ExternalMenuLink(titleKey: "upgrade.manage", icon: "creditcard", url: PressBenchPolicyLinks.manageSubscription)
                        } else if store.isPro {
                            ExternalMenuLink(titleKey: "common.purchasesPro", icon: "creditcard", url: PressBenchPolicyLinks.purchases)
                        } else {
                            Button { showingUpgrade = true } label: { menuRow("common.purchasesPro", icon: "creditcard") }
                                .buttonStyle(.plain)
                        }
                        if !store.isPro {
                            Divider().opacity(0.35)
                            ExternalMenuLink(titleKey: "ads.report", icon: "exclamationmark.bubble", url: PressBenchPolicyLinks.reportAd)
                            if privacyOptionsAvailable {
                                Divider().opacity(0.35)
                                Button {
                                    Task {
                                        let shown = await PBAdvertising.presentPrivacyOptions()
                                        privacyOptionsAvailable = PBAdvertising.privacyOptionsRequired
                                        privacyOptionsFailed = !shown
                                    }
                                } label: {
                                    menuRow("ads.privacyChoices", icon: "checkmark.shield")
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                .disabled(store.activeRun != nil)
                .opacity(store.activeRun == nil ? 1 : 0.45)
                .buttonStyle(.plain).padding(18)
                .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: PBTheme.cardRadius, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: PBTheme.cardRadius).stroke(PBTheme.line, lineWidth: 1) }
            }
            .padding(.horizontal, PBTheme.pagePadding).padding(.bottom, 24)
        }
        .background(PBTheme.canvasGradient)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingUpgrade) { ProUpgradeView().environmentObject(store).pbEditorSheetStyle() }
        .task {
            guard store.adEligibilityResolved, !store.isPro else { return }
            _ = await PBAdvertising.prepareForAds()
            privacyOptionsAvailable = PBAdvertising.privacyOptionsRequired
        }
        .alert("PressBench", isPresented: $privacyOptionsFailed) {
            Button(t("common.ok"), role: .cancel) {}
        } message: {
            Text(t("common.actionFailed"))
        }
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
