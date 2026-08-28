import SwiftUI
import UIKit

struct RunsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var filter: RunState? = nil
    @State private var showingStarter = false
    @State private var search = ""

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var filtered: [BatchRun] {
        store.runs.filter {
            (filter == nil || $0.state == filter) &&
            (search.isEmpty || [$0.title, $0.jobReference, $0.machineName].contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                PBPageHeader(
                    title: t("runs.title"),
                    addAccessibilityLabel: t("setup.startRun"),
                    addAction: store.activeRun != nil || store.setups.isEmpty ? nil : { showingStarter = true }
                )

                PBSearchField(prompt: t("setups.search"), text: $search)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        RunFilterPill(titleKey: "common.all", selected: filter == nil) { filter = nil }
                        ForEach([RunState.running, .completed], id: \.self) { state in
                            RunFilterPill(titleKey: state.localizationKey, selected: filter == state) { filter = state }
                        }
                    }
                }

                if filtered.isEmpty {
                    VStack(spacing: 18) {
                        ContentUnavailableView(t("runs.title"), systemImage: "play.circle", description: Text(t("onboarding.ready.run.body")))
                        PBPrimaryButton(title: t(store.setups.contains { $0.status != .draft && $0.status != .archived } ? "setup.startRun" : "onboarding.ready.setup.title"), icon: "plus.circle.fill") {
                            if store.setups.contains(where: { $0.status != .draft && $0.status != .archived }) { showingStarter = true }
                            else { store.selectedTab = 1 }
                        }
                        .disabled(store.activeRun != nil)
                    }.frame(maxWidth: .infinity).padding(.top, 50)
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
        .navigationDestination(item: $store.activeRunRouteID) { id in
            if store.activeRun?.id == id {
                ActiveRunView(runID: id)
            } else if let completed = store.runs.first(where: { $0.id == id }) {
                CompletedRunDetailView(run: completed)
            } else {
                ContentUnavailableView(t("runs.title"), systemImage: "exclamationmark.triangle")
            }
        }
    }
}

struct CompletedRunDetailView: View {
    private let runID: String
    private let initialRun: BatchRun
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingCorrection = false
    @State private var showingDelete = false
    @State private var showingRepeat = false
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    init(run: BatchRun) { runID = run.id; initialRun = run }
    private var run: BatchRun { store.runs.first(where: { $0.id == runID }) ?? initialRun }
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
                        if !run.machineName.isEmpty {
                            Divider(); LabeledContent(t("run.machine"), value: run.machineName)
                        }
                        if !run.material.isEmpty {
                            Divider(); LabeledContent(t("common.material"), value: run.material)
                        }
                        if !run.transferMedium.isEmpty {
                            Divider(); LabeledContent(t("common.transferMedium"), value: run.transferMedium)
                        }
                        if !run.temperature.isEmpty {
                            Divider(); LabeledContent(t("common.temperature"), value: run.temperature)
                        }
                        if !run.pressure.isEmpty {
                            Divider(); LabeledContent(t("common.pressure"), value: run.pressure)
                        }
                        if !run.duration.isEmpty {
                            Divider(); LabeledContent(t("common.durationSeconds"), value: run.duration)
                        }
                        if let date = run.completedAt {
                            Divider()
                            LabeledContent(t("report.date"), value: PBFormat.date(date, locale: locale, time: true))
                        }
                        if !run.jobReference.isEmpty {
                            Divider()
                            LabeledContent(t("common.reference"), value: run.jobReference)
                        }
                        Divider()
                        LabeledContent(t("report.wasteUnits"), value: PBFormat.integer(run.waste, locale: locale))
                        Divider()
                        LabeledContent(t("report.reworkedUnits"), value: PBFormat.integer(run.reworked, locale: locale))
                        Divider()
                        LabeledContent(t("qc.title"), value: PBFormat.integer(run.qcCheckCountTotal, locale: locale))
                        Divider()
                        LabeledContent(t("report.issuesExceptions"), value: PBFormat.integer(run.issues.count, locale: locale))
                        if !run.notes.isEmpty {
                            Divider()
                            LabeledContent(t("common.notes"), value: run.notes)
                        }
                    }
                }
                if !run.processStages.isEmpty {
                    PBCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(t("stage.stage")).font(.headline)
                            ForEach(Array(run.processStages.enumerated()), id: \.element.id) { index, stage in
                                if index > 0 { Divider() }
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("\(PBFormat.integer(index + 1, locale: locale)). \(stage.canonicalLocalizationKey.map(t) ?? stage.name)")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        if !stage.value.isEmpty { Text(stage.value).font(.subheadline).foregroundStyle(PBTheme.secondary) }
                                    }
                                    if stage.repeatCount > 1 {
                                        Text("\(t("stage.repeatCount")): \(PBFormat.integer(stage.repeatCount, locale: locale))")
                                            .font(.caption).foregroundStyle(PBTheme.secondary)
                                    }
                                    if !stage.instruction.isEmpty { completedStageDetail("stage.instruction", stage.instruction) }
                                    if !stage.placementAction.isEmpty { completedStageDetail("stage.placementAction", stage.placementAction) }
                                    if !stage.finishAction.isEmpty { completedStageDetail("stage.finishAction", stage.finishAction) }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !run.issues.isEmpty {
                    PBCard(tone: .caution) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t("report.issuesExceptions")).font(.headline)
                            ForEach(run.issues) { issue in
                                HStack(alignment: .top) {
                                    Text(PBFormat.integer(Int(issue.quantity) ?? 0, locale: locale)).font(.headline)
                                    VStack(alignment: .leading) {
                                        Text(t("issue.symptom.\(issue.symptom)"))
                                        Text(t("issue.disposition.\(issue.disposition)")).font(.caption).foregroundStyle(PBTheme.secondary)
                                        if !issue.note.isEmpty { Text(issue.note).font(.caption) }
                                    }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let setup = store.setups.first(where: { $0.id == run.setupID && $0.status != .archived }) {
                    PBPrimaryButton(title: t("run.repeatSetup"), icon: "arrow.clockwise") { showingRepeat = true }
                        .disabled(store.activeRun != nil)
                    .sheet(isPresented: $showingRepeat) { JobDifferenceSheet(setup: setup).environmentObject(store) }
                }
                Button(t("run.correctRecord")) { showingCorrection = true }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                Button(role: .destructive) { showingDelete = true } label: {
                    Label(t("run.deleteRecord"), systemImage: "trash").font(.headline).frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                }
            }
            .padding(PBTheme.pagePadding)
        }
        .background(PBTheme.canvasGradient)
        .navigationTitle(t("report.batch"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCorrection) {
            BatchCorrectionView(run: run) { jobReference, planned, processed, notes, issues, reason in
                do {
                    try store.correctBatch(id: run.id, jobReference: jobReference, planned: planned,
                                           processed: processed, notes: notes, issues: issues, reason: reason)
                    showingCorrection = false
                }
                catch { failureMessageKey = store.errorLocalizationKey(error); failed = true }
            }.pbEditorSheetStyle()
        }
        .alert(t("run.deleteRecord"), isPresented: $showingDelete) {
            Button(t("run.deleteRecord"), role: .destructive) {
                do { try store.deleteBatch(id: run.id); dismiss() }
                catch { failureMessageKey = store.errorLocalizationKey(error); failed = true }
            }
            Button(t("common.cancel"), role: .cancel) {}
                .accessibilityIdentifier("pb.delete.cancel")
        } message: {
            Text(PBL10n.format("run.deleteRecordConfirm", language: language, locale: locale, run.title as NSString))
        }
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t(failureMessageKey)) }
    }

    @ViewBuilder
    private func completedStageDetail(_ key: String, _ value: String) -> some View {
        Text("\(t(key)): \(value)")
            .font(.caption)
            .foregroundStyle(PBTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BatchCorrectionView: View {
    let run: BatchRun
    let save: (String, Int, Int, String, [IssueDraftInput], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var jobReference: String
    @State private var planned: String
    @State private var processed: String
    @State private var notes: String
    @State private var issues: [IssueDraftInput]
    @State private var reason = ""
    @State private var showingDiscard = false
    private let originalJobReference: String
    private let originalPlanned: String
    private let originalProcessed: String
    private let originalNotes: String
    private let originalIssues: [IssueDraftInput]
    private let symptoms = ["unknown", "color_shift", "ghosting", "edge_lift", "adhesion", "scorch", "alignment", "incomplete_transfer", "uneven_heat_pressure", "moisture", "transfer_shift", "contamination", "substrate_defect", "design_setup", "print_supply", "equipment_power", "interrupted", "other"]
    private let causes = ["unknown", "heat", "pressure", "time", "moisture", "placement", "transfer", "substrate", "design", "printer_ink_paper", "equipment_power", "operator_interruption", "other"]
    init(run: BatchRun, save: @escaping (String, Int, Int, String, [IssueDraftInput], String) -> Void) {
        self.run = run; self.save = save
        originalJobReference = run.jobReference
        originalPlanned = String(run.planned)
        originalProcessed = String(run.processed)
        originalNotes = run.notes
        originalIssues = run.issues
        _jobReference = State(initialValue: run.jobReference)
        _planned = State(initialValue: String(run.planned))
        _processed = State(initialValue: String(run.processed))
        _notes = State(initialValue: run.notes)
        _issues = State(initialValue: run.issues)
    }
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(t("run.jobReference"), text: $jobReference)
                    TextField(t("run.plannedQuantity"), text: $planned).keyboardType(.numberPad)
                    TextField(t("report.processed"), text: $processed).keyboardType(.numberPad)
                    TextEditor(text: $notes).frame(minHeight: 100).accessibilityLabel(t("common.notes"))
                }
                Section(t("report.issuesExceptions")) {
                    LabeledContent(t("report.wasteUnits"), value: PBFormat.integer(issueTotal("discarded"), locale: locale))
                    LabeledContent(t("report.reworkedUnits"), value: PBFormat.integer(issueTotal("reworked"), locale: locale))
                    ForEach($issues) { $issue in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(t("issue.title")).font(.subheadline.bold())
                                Spacer()
                                Button(role: .destructive) { issues.removeAll { $0.id == issue.id } } label: {
                                    Image(systemName: "trash").frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                                }
                            }
                            TextField(t("report.quantity"), text: $issue.quantity).keyboardType(.numberPad)
                            Picker(t("report.disposition"), selection: $issue.disposition) {
                                Text(t("issue.disposition.discarded")).tag("discarded")
                                Text(t("issue.disposition.reworked")).tag("reworked")
                            }.pickerStyle(.segmented).frame(minHeight: PBTheme.minimumTarget)
                            Picker(t("report.symptom"), selection: $issue.symptom) {
                                ForEach(symptoms, id: \.self) { Text(t("issue.symptom.\($0)")).tag($0) }
                            }.pickerStyle(.menu)
                            Picker(t("report.suspectedCause"), selection: $issue.suspectedCause) {
                                ForEach(causes, id: \.self) { Text(t("issue.cause.\($0)")).tag($0) }
                            }.pickerStyle(.menu)
                            TextField(t("report.note") + " *", text: $issue.note)
                        }
                    }
                    Button { issues.append(IssueDraftInput()) } label: {
                        Label(t("issue.add"), systemImage: "plus.circle.fill")
                    }.frame(minHeight: PBTheme.minimumTarget)
                }
                Section(t("run.correctionReason")) {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                        .accessibilityLabel(t("run.correctionReason"))
                        .accessibilityIdentifier("pb.correction.reason")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(t("run.correctRecord"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { cancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.save")) {
                        guard let planned = Int(self.planned), let processed = Int(self.processed) else { return }
                        save(jobReference, planned, processed, notes, issues, reason)
                    }.disabled(!isReady)
                }
            }
            .alert(t("editor.discardChanges"), isPresented: $showingDiscard) {
                Button(t("editor.discard"), role: .destructive) { dismiss() }
                    .accessibilityIdentifier("pb.correction.discard")
                Button(t("common.cancel"), role: .cancel) {}
                    .accessibilityIdentifier("pb.correction.cancel")
            }
        }
        .interactiveDismissDisabled(hasChanges)
    }

    private var hasChanges: Bool {
        jobReference != originalJobReference || planned != originalPlanned || processed != originalProcessed ||
            notes != originalNotes || issues != originalIssues ||
            !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func cancel() {
        guard hasChanges else {
            dismiss()
            return
        }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingDiscard = true
        }
    }

    private var isReady: Bool {
        guard let planned = Int(self.planned), let processed = Int(self.processed), planned > 0,
              processed >= 0, processed <= planned,
              reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }
        let waste = issueTotal("discarded"), reworked = issueTotal("reworked")
        return waste <= processed && reworked <= processed - waste && issues.allSatisfy {
            (Int($0.quantity).map { $0 > 0 } == true) && !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func issueTotal(_ disposition: String) -> Int {
        issues.filter { $0.disposition == disposition }.reduce(0) { $0 + (Int($1.quantity) ?? 0) }
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
