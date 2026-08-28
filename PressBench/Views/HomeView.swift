import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingMachineEditor = false
    @State private var showingStarter = false
    @State private var showingSetupEditor = false
    @State private var continueToSetup = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                header
                if needsFirstUseSetup {
                    firstUseCard
                } else {
                    startRunCard
                    metrics
                    recentSetups
                }
            }
            .padding(.horizontal, PBTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(PBTheme.canvasGradient)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingMachineEditor, onDismiss: {
            if continueToSetup { continueToSetup = false; showingSetupEditor = true }
        }) {
            MachineEditorView { _ in continueToSetup = true }.environmentObject(store)
        }
        .sheet(isPresented: $showingSetupEditor) { SetupEditorView(draft: store.setupDraft(for: nil)).environmentObject(store) }
        .sheet(isPresented: $showingStarter) { StartRunSheet().environmentObject(store) }
    }

    private var needsFirstUseSetup: Bool {
        !store.machines.contains(where: { $0.active }) || !store.setups.contains(where: { $0.status != .archived })
    }

    private var firstUseCard: some View {
        PBCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BrandLogo(size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("onboarding.ready.title"))
                            .font(.headline)
                            .foregroundStyle(PBTheme.navy)
                        Text(t("onboarding.ready.body"))
                            .font(.subheadline)
                            .foregroundStyle(PBTheme.secondary)
                    }
                }

                Divider().opacity(0.35)
                if !store.machines.contains(where: { $0.active }) {
                    FirstUseAction(icon: "rectangle.stack.fill", titleKey: "onboarding.ready.machine.title", subtitleKey: "onboarding.ready.machine.body") {
                        showingMachineEditor = true
                    }
                } else {
                    FirstUseAction(icon: "list.clipboard.fill", titleKey: "onboarding.ready.setup.title", subtitleKey: "onboarding.ready.setup.body") {
                        showingSetupEditor = true
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            PBPageHeader(title: "PressBench")
            Text(t("home.greeting"))
                .font(.subheadline)
                .foregroundStyle(PBTheme.secondary)
        }
    }

    private var startRunCard: some View {
        Button {
            if let active = store.activeRun { store.activeRunRouteID = active.id; store.selectedTab = 2 }
            else { showingStarter = true }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(store.activeRun == nil ? "home.startRun.title" : "runs.activeRun")).font(.title3.bold())
                    Text(store.activeRun.map { PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                        PBFormat.integer($0.processed, locale: locale) as NSString,
                        PBFormat.integer($0.planned, locale: locale) as NSString) } ?? t("home.startRun.body"))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.forward").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(PBTheme.selectionFill, in: RoundedRectangle(cornerRadius: PBTheme.cardRadius, style: .continuous))
            .shadow(color: PBTheme.controlShadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PBTactileButtonStyle())
    }

    private var metrics: some View {
        let m = store.metrics
        return LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
            MetricTile(titleKey: "home.metric.setups", value: PBFormat.integer(m.setups, locale: locale), icon: "slider.horizontal.3")
            MetricTile(titleKey: "home.metric.batches", value: PBFormat.integer(m.batches, locale: locale), icon: "square.stack.3d.up")
            MetricTile(titleKey: "home.metric.firstPass", value: PBFormat.percent(m.firstPassYield, locale: locale), icon: "chart.line.uptrend.xyaxis")
            MetricTile(titleKey: "home.metric.waste", value: PBFormat.percent(m.wasteRate, locale: locale), icon: "trash")
        }
    }

    private var recentSetups: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("home.recentSetups")).font(.title3.bold())
                Spacer()
                Button { store.selectedTab = 1 } label: {
                    Text(t("home.viewAll"))
                        .frame(minHeight: PBTheme.minimumTarget)
                        .contentShape(Rectangle())
                }
            }
            PBCard {
                VStack(spacing: 0) {
                    ForEach(Array(store.recentSetups.prefix(3).enumerated()), id: \.element.id) { index, setup in
                        NavigationLink(value: setup) {
                            SetupRow(setup: setup, compact: true)
                        }
                        .buttonStyle(PBTactileButtonStyle())
                        if index < min(2, store.recentSetups.count - 1) { Divider().opacity(0.35) }
                    }
                }
            }
        }
        .navigationDestination(for: Setup.self) { SetupDetailView(setup: $0) }
    }

}

private struct MetricTile: View {
    let titleKey: String
    let value: String
    let icon: String
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(PBTheme.secondary)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(PBTheme.surface, in: Circle())
            Text(PBL10n.text(titleKey, language: language, locale: locale))
                .font(.caption)
                .foregroundStyle(PBTheme.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.68)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(PBTheme.navy)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.65)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(PBTheme.line, lineWidth: 1) }
        .shadow(color: PBTheme.cardShadow, radius: 10, x: 0, y: 5)
    }
}

private struct FirstUseAction: View {
    let icon: String
    let titleKey: String
    let subtitleKey: String
    let action: () -> Void
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PBTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(PBL10n.text(titleKey, language: language, locale: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(PBL10n.text(subtitleKey, language: language, locale: locale))
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .foregroundStyle(PBTheme.secondary)
            }
            .frame(minHeight: PBTheme.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PBTactileButtonStyle())
    }
}
