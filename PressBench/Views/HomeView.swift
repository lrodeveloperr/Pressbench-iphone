import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingMachineEditor = false
    @State private var showingStarter = false
    @State private var selectedStartSetup: Setup?
    @State private var showingUpgrade = false
    @State private var showingSetupEditor = false
    @State private var selectedMetricDetail: HomeMetricDetail?
    @State private var resumeStartAfterUpgrade = false

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
        .sheet(isPresented: $showingMachineEditor) { MachineEditorView().environmentObject(store) }
        .sheet(isPresented: $showingSetupEditor) { SetupEditorView(draft: store.setupDraft(for: nil)).environmentObject(store) }
        .sheet(item: $selectedMetricDetail) { metric in
            HomeMetricDetailView(metric: metric).environmentObject(store)
        }
        .sheet(isPresented: $showingStarter) { StartRunSheet().environmentObject(store) }
        .sheet(item: $selectedStartSetup) { setup in
            RunConfigurationView(setup: setup).environmentObject(store)
        }
        .sheet(isPresented: $showingUpgrade, onDismiss: {
            guard resumeStartAfterUpgrade else { return }
            resumeStartAfterUpgrade = false
            if store.isPro { beginRunSelection() }
        }) { ProUpgradeView().environmentObject(store).pbEditorSheetStyle() }
    }

    private var needsFirstUseSetup: Bool {
        !store.machines.contains(where: { $0.active }) || !store.setups.contains(where: { $0.status != .archived })
    }

    private var runnableSetups: [Setup] {
        store.recentSetups.filter { $0.status == .trial || $0.status == .proven }
    }

    private func beginRunSelection() {
        if runnableSetups.count == 1 {
            selectedStartSetup = runnableSetups[0]
        } else {
            showingStarter = true
        }
    }

    private var firstUseCard: some View {
        Group {
            if !store.machines.contains(where: { $0.active }) {
                PBPrimaryButton(title: firstUseTitle("onboarding.ready.machine.title"), icon: "plus.circle.fill") {
                    showingMachineEditor = true
                }
                .accessibilityIdentifier("pb.home.firstUseAction")
            } else {
                PBPrimaryButton(title: firstUseTitle("onboarding.ready.setup.title"), icon: "plus.circle.fill") {
                    showingSetupEditor = true
                }
                .accessibilityIdentifier("pb.home.firstUseAction")
            }
        }
        .frame(minHeight: PBTheme.minimumTarget)
    }

    private func firstUseTitle(_ key: String) -> String {
        let value = t(key)
        guard let separator = value.firstIndex(of: "."),
              value[..<separator].allSatisfy(\.isNumber) else { return value }
        return value[value.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var header: some View {
        PBPageHeader(title: "PressBench")
    }

    private var startRunCard: some View {
        Button {
            if let active = store.activeRun { store.activeRunRouteID = active.id; store.selectedTab = 2 }
            else if store.canStartAnotherRun { beginRunSelection() }
            else { resumeStartAfterUpgrade = true; showingUpgrade = true }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(store.activeRun == nil ? "home.startRun.title" : "runs.activeRun")).font(.title3.bold())
                    if let activeRun = store.activeRun {
                        Text(PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                            PBFormat.integer(activeRun.processed, locale: locale) as NSString,
                            PBFormat.integer(activeRun.planned, locale: locale) as NSString))
                            .font(.subheadline.weight(.semibold))
                    }
                    if store.activeRun == nil && !store.isPro {
                        Text(PBL10n.format(
                            "usage.freeRunsRemaining", language: language, locale: locale,
                            PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                            PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString
                        ))
                        .font(.subheadline.weight(.bold))
                    }
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
        .accessibilityIdentifier("pb.home.startRun")
    }

    private var metrics: some View {
        let m = store.metrics
        return LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
            MetricTile(titleKey: m.setups == 1 ? "setup.title" : "home.metric.setups", value: PBFormat.integer(m.setups, locale: locale), icon: "slider.horizontal.3") {
                store.selectedTab = 1
            }
            MetricTile(titleKey: m.batches == 1 ? "runs.batch" : "home.metric.batches", value: PBFormat.integer(m.batches, locale: locale), icon: "square.stack.3d.up") {
                store.selectedTab = 2
            }
            MetricTile(titleKey: "home.metric.firstPass", value: PBFormat.percent(m.firstPassYield, locale: locale), icon: "chart.line.uptrend.xyaxis") {
                selectedMetricDetail = .firstPass
            }
            MetricTile(titleKey: "home.metric.waste", value: PBFormat.percent(m.wasteRate, locale: locale), icon: "trash") {
                selectedMetricDetail = .waste
            }
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

private enum HomeMetricDetail: String, Identifiable {
    case firstPass
    case waste
    var id: String { rawValue }
}

private struct HomeMetricDetailView: View {
    let metric: HomeMetricDetail
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var titleKey: String { metric == .firstPass ? "report.firstPassYield" : "report.wasteRate" }
    private var value: String {
        let metrics = store.metrics
        return PBFormat.percent(metric == .firstPass ? metrics.firstPassYield : metrics.wasteRate, locale: locale)
    }
    private var completedRuns: [BatchRun] { store.runs.filter { $0.state == .completed } }
    private func safeTotal(_ value: (BatchRun) -> Int) -> Int {
        completedRuns.reduce(0) { total, run in
            let next = max(0, value(run))
            return next > Int.max - total ? Int.max : total + next
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PBTheme.pageSpacing) {
                    PBCard {
                        VStack(spacing: 14) {
                            Text(value)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PBTheme.navy)
                            Divider()
                            LabeledContent(t("report.sampleSize"), value: PBFormat.integer(completedRuns.count, locale: locale))
                            LabeledContent(t("report.unitsProcessed"), value: PBFormat.integer(safeTotal(\.processed), locale: locale))
                            if metric == .firstPass {
                                LabeledContent(t("report.firstPass"), value: PBFormat.integer(firstPassUnits, locale: locale))
                                LabeledContent(t("report.reworkedUnits"), value: PBFormat.integer(safeTotal(\.reworked), locale: locale))
                                LabeledContent(t("report.wasteUnits"), value: PBFormat.integer(safeTotal(\.waste), locale: locale))
                            } else {
                                LabeledContent(t("report.wasteUnits"), value: PBFormat.integer(safeTotal(\.waste), locale: locale))
                            }
                        }
                    }
                    PBPrimaryButton(title: t("home.viewAll"), icon: "list.bullet.rectangle") {
                        dismiss()
                        store.selectedTab = 2
                    }
                }
                .padding(PBTheme.pagePadding)
            }
            .background(PBTheme.canvasGradient)
            .navigationTitle(t(titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.ok")) { dismiss() }
                }
            }
        }
        .pbEditorSheetStyle()
    }

    private var firstPassUnits: Int {
        let processed = safeTotal(\.processed)
        let afterRework = processed - min(processed, safeTotal(\.reworked))
        return afterRework - min(afterRework, safeTotal(\.waste))
    }
}

private struct MetricTile: View {
    let titleKey: String
    let value: String
    let icon: String
    let action: () -> Void
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(PBTactileButtonStyle())
    }

    private var content: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(PBTheme.secondary)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(PBTheme.surface, in: Circle())
            Text(PBL10n.text(titleKey, language: language, locale: locale))
                .font(.caption)
                .foregroundStyle(PBTheme.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.68)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(PBTheme.navy)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.65)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .center)
        .padding(12)
        .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(PBTheme.line, lineWidth: 1) }
        .shadow(color: PBTheme.cardShadow, radius: 10, x: 0, y: 5)
    }
}
