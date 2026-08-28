import SwiftUI

struct RunsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var filter: RunState? = nil
    @State private var showingStarter = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var filtered: [BatchRun] { store.runs.filter { filter == nil || $0.state == filter } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                PBPageHeader(
                    title: t("runs.title"),
                    addAccessibilityLabel: t("setup.startRun"),
                    addAction: store.activeRun != nil || store.setups.isEmpty ? nil : { showingStarter = true }
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        RunFilterPill(titleKey: "common.all", selected: filter == nil) { filter = nil }
                        ForEach([RunState.running, .completed], id: \.self) { state in
                            RunFilterPill(titleKey: state.localizationKey, selected: filter == state) { filter = state }
                        }
                    }
                }

                if filtered.isEmpty {
                    ContentUnavailableView(t("runs.title"), systemImage: "play.circle", description: Text(t("onboarding.ready.run.body")))
                        .frame(maxWidth: .infinity).padding(.top, 50)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filtered) { run in
                            if run.state == .running {
                                NavigationLink { ActiveRunView(runID: run.id) } label: { RunCard(run: run) }.buttonStyle(PBTactileButtonStyle())
                            } else {
                                NavigationLink { CompletedRunDetailView(run: run) } label: { RunCard(run: run) }
                                    .buttonStyle(PBTactileButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, PBTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(PBTheme.canvasGradient)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingStarter) { StartRunSheet().environmentObject(store) }
    }
}

private struct CompletedRunDetailView: View {
    let run: BatchRun
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        ScrollView {
            VStack(spacing: PBTheme.pageSpacing) {
                PBCard(tone: .success) {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(PBTheme.successInk)
                        Text(run.title)
                            .font(.title2.bold())
                            .foregroundStyle(PBTheme.navy)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                            PBFormat.integer(run.processed, locale: locale) as NSString,
                            PBFormat.integer(run.planned, locale: locale) as NSString))
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                PBCard {
                    VStack(spacing: 14) {
                        LabeledContent(t("report.firstPassYield"), value: run.firstPassYield.map { PBFormat.percent($0, locale: locale) } ?? "—")
                        Divider()
                        LabeledContent(t("common.durationSeconds"), value: PBFormat.clock(seconds: run.elapsed, locale: locale))
                        if let date = run.completedAt {
                            Divider()
                            LabeledContent(t("report.date"), value: PBFormat.date(date, locale: locale, time: true))
                        }
                        if !run.jobReference.isEmpty {
                            Divider()
                            LabeledContent(t("common.reference"), value: run.jobReference)
                        }
                    }
                }
            }
            .padding(PBTheme.pagePadding)
        }
        .background(PBTheme.canvasGradient)
        .navigationTitle(t("report.batch"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RunFilterPill: View {
    let titleKey: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            Text(PBL10n.text(titleKey, language: language, locale: locale))
                .font(.subheadline.weight(.semibold)).foregroundStyle(selected ? .white : PBTheme.secondary)
                .padding(.horizontal, 18).frame(minHeight: PBTheme.minimumTarget)
                .background(selected ? PBTheme.selectionFill : PBTheme.paper, in: Capsule())
                .overlay { Capsule().stroke(selected ? Color.clear : PBTheme.line, lineWidth: 1) }
        }
        .buttonStyle(PBTactileButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct RunCard: View {
    let run: BatchRun
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var stageText: String { run.canonicalStageLocalizationKey.map(t) ?? run.stage }

    var body: some View {
        PBCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: run.state == .running ? "play.circle.fill" : "checkmark.circle")
                    .font(.title2).foregroundStyle(PBTheme.secondary).frame(width: 48, height: 48).background(PBTheme.surface, in: Circle())
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(run.title).font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Text(t(run.state.localizationKey)).font(.caption2.bold())
                            .foregroundStyle(run.state == .running ? PBTheme.primaryStrong : PBTheme.successInk)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(run.state == .running ? PBTheme.primarySoft : PBTheme.successSoft, in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                            PBFormat.integer(run.processed, locale: locale) as NSString,
                            PBFormat.integer(run.planned, locale: locale) as NSString))
                            .font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(PBTheme.navy)
                        Text(t("common.units")).font(.subheadline).foregroundStyle(PBTheme.secondary)
                        Spacer()
                        if run.state == .running { Image(systemName: "chevron.forward").foregroundStyle(PBTheme.secondary) }
                    }
                    if run.state == .running {
                        HStack(spacing: 7) {
                            Text(PBL10n.format("runs.stageProgress", language: language, locale: locale,
                                PBFormat.integer(run.stageIndex, locale: locale) as NSString,
                                PBFormat.integer(run.stageCount, locale: locale) as NSString))
                            Text("·"); Text(stageText)
                        }.font(.subheadline).foregroundStyle(PBTheme.secondary)
                        Label(PBFormat.clock(seconds: run.elapsed, locale: locale), systemImage: "clock")
                            .font(.caption).foregroundStyle(PBTheme.secondary)
                    } else {
                        HStack {
                            if let completedAt = run.completedAt { Label(PBFormat.date(completedAt, locale: locale, time: true), systemImage: "calendar") }
                            Spacer()
                            if let y = run.firstPassYield { Label(PBFormat.percent(y, locale: locale), systemImage: "chart.line.uptrend.xyaxis") }
                        }.font(.caption).foregroundStyle(PBTheme.secondary)
                    }
                }
            }
        }
    }
}
