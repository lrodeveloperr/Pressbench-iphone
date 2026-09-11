import SwiftUI
import UIKit

struct ReportsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var exportURL: URL?
    @State private var failed = false
    @State private var generating = false
    @State private var showingShare = false
    @State private var showingUpgrade = false
    @State private var pendingFormat: String?
    @State private var exportTask: Task<Void, Never>?
    @State private var search = ""
    @State private var issuesOnly = false
    @State private var machineFilter = ""
    @State private var setupFilter = ""
    @State private var materialFilter = ""
    @State private var usesDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var matchingRuns: [BatchRun] {
        store.runs.filter { run in
            guard run.state == .completed, !issuesOnly || !run.issues.isEmpty else { return false }
            guard machineFilter.isEmpty || run.machineName == machineFilter else { return false }
            guard setupFilter.isEmpty || run.setupID == setupFilter else { return false }
            guard materialFilter.isEmpty || run.material == materialFilter else { return false }
            if usesDateRange {
                guard let completedAt = run.completedAt else { return false }
                let start = Calendar.current.startOfDay(for: min(startDate, endDate))
                let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: max(startDate, endDate))) ?? endDate
                guard completedAt >= start && completedAt < end else { return false }
            }
            guard !search.isEmpty else { return true }
            var values = [
                run.id, run.title, run.jobReference, run.machineName, run.material, run.transferMedium,
                run.temperature, run.pressure, run.platen, run.instructionSource,
                run.instructionCheckedDate, run.notes, String(run.processed), String(run.planned)
            ]
            if let completedAt = run.completedAt {
                values.append(PBFormat.date(completedAt, locale: locale, time: true))
                values.append(ISO8601DateFormatter().string(from: completedAt))
            }
            values.append(contentsOf: run.processStages.flatMap {
                [$0.name, $0.value, $0.instruction, $0.placementAction, $0.finishAction]
            })
            for issue in run.issues {
                values.append(contentsOf: [
                    issue.symptom, issue.suspectedCause, issue.disposition, issue.note,
                    t("issue.symptom.\(issue.symptom)"), t("issue.cause.\(issue.suspectedCause)"),
                    t("issue.disposition.\(issue.disposition)")
                ])
            }
            return values.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }
    private var matchingBatchIDs: Set<String> { Set(matchingRuns.map(\.id)) }
    private var machineChoices: [String] { Array(Set(store.runs.map(\.machineName).filter { !$0.isEmpty })).sorted() }
    private var setupChoices: [Setup] { store.setups.filter { $0.status != .archived }.sorted { $0.title < $1.title } }
    private var materialChoices: [String] { Array(Set(store.runs.map(\.material).filter { !$0.isEmpty })).sorted() }
    private var processedUnits: Int { matchingRuns.reduce(0) { $0 + $1.processed } }
    private var wasteUnits: Int { matchingRuns.reduce(0) { $0 + $1.waste } }
    private var reworkedUnits: Int { matchingRuns.reduce(0) { $0 + $1.reworked } }
    private var firstPassYield: Double {
        guard processedUnits > 0 else { return 0 }
        return Double(max(0, processedUnits - wasteUnits - reworkedUnits)) / Double(processedUnits)
    }
    private var topSymptoms: [(String, Int)] {
        let counts = matchingRuns.flatMap(\.issues).reduce(into: [String: Int]()) { result, issue in
            result[issue.symptom, default: 0] += Int(issue.quantity) ?? 0
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            Section(t("report.reportingPeriod")) {
                Picker(t("run.machine"), selection: $machineFilter) {
                    Text(t("common.all")).tag("")
                    ForEach(machineChoices, id: \.self) { Text($0).tag($0) }
                }
                Picker(t("report.setup"), selection: $setupFilter) {
                    Text(t("common.all")).tag("")
                    ForEach(setupChoices) { Text($0.title).tag($0.id) }
                }
                Picker(t("common.material"), selection: $materialFilter) {
                    Text(t("common.all")).tag("")
                    ForEach(materialChoices, id: \.self) { Text($0).tag($0) }
                }
                Toggle(t("report.reportingPeriod"), isOn: $usesDateRange)
                if usesDateRange {
                    DatePicker(t("report.date") + " 1", selection: $startDate, displayedComponents: .date)
                    DatePicker(t("report.date") + " 2", selection: $endDate, displayedComponents: .date)
                }
            }

            Section {
                Toggle(isOn: $issuesOnly) {
                    Label(t("report.issuesExceptions"), systemImage: "exclamationmark.bubble")
                }
                LabeledContent(t("report.sampleSize"), value: PBFormat.integer(matchingRuns.count, locale: locale))
            }

            Section(t("common.analytics")) {
                LabeledContent(t("report.unitsProcessed"), value: PBFormat.integer(processedUnits, locale: locale))
                LabeledContent(t("report.firstPassYield"), value: PBFormat.percent(firstPassYield, locale: locale))
                LabeledContent(t("report.reworkedUnits"), value: PBFormat.integer(reworkedUnits, locale: locale))
                LabeledContent(t("report.wasteUnits"), value: PBFormat.integer(wasteUnits, locale: locale))
                ForEach(Array(topSymptoms.enumerated()), id: \.offset) { _, item in
                    LabeledContent(t("issue.symptom.\(item.0)"), value: PBFormat.integer(item.1, locale: locale))
                }
            }

            Section {
                exportButton(format: "PDF", systemImage: "doc.richtext")
                exportButton(format: "XLSX", systemImage: "tablecells.badge.ellipsis")
            } header: {
                Text(t("report.productionReport"))
            } footer: {
                Text(t("report.operatorValuesNotice"))
            }

            if !store.isPro {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(t("common.purchasesPro"), systemImage: "star.circle.fill").font(.headline).foregroundStyle(PBTheme.primaryStrong)
                        Text([t("report.productionReport"), "PDF / XLSX"].joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(PBTheme.secondary)
                        Button {
                            showingUpgrade = true
                        } label: {
                            HStack {
                                Text(t("common.unlockPro"))
                                Spacer()
                                if let price = store.productDisplayPrice {
                                    Text(price)
                                }
                            }
                            .pbFullSurfaceTarget()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            if let exportURL {
                Section {
                    ShareLink(item: exportURL) {
                        Label(exportURL.lastPathComponent, systemImage: "square.and.arrow.up")
                            .pbFullSurfaceTarget()
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 64)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .tint(PBTheme.primary)
        .navigationTitle(t("report.productionReport"))
        .searchable(text: $search, prompt: t("setups.search"))
        .overlay { if generating { ProgressView().controlSize(.large) } }
        .sheet(isPresented: $showingShare) {
            if let exportURL { ActivityShareView(items: [exportURL as Any]) }
        }
        .sheet(isPresented: $showingUpgrade, onDismiss: {
            guard store.isPro, let format = pendingFormat else { pendingFormat = nil; return }
            pendingFormat = nil
            startExport(format)
        }) {
            ProUpgradeView().environmentObject(store).pbEditorSheetStyle()
        }
        .onDisappear {
            exportTask?.cancel()
            exportTask = nil
            generating = false
        }
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t("common.actionFailed")) }
    }

    private func exportButton(format: String, systemImage: String) -> some View {
        Button {
            if store.isPro { startExport(format) }
            else { pendingFormat = format; showingUpgrade = true }
        } label: {
            HStack {
                Label(format, systemImage: systemImage)
                Spacer()
                Image(systemName: store.isPro ? "chevron.forward" : "lock.fill").foregroundStyle(PBTheme.secondary)
            }
            .pbFullSurfaceTarget()
        }
        .disabled(generating || matchingRuns.isEmpty)
        .accessibilityIdentifier("pb.reports.\(format.lowercased())")
    }

    private func startExport(_ format: String) {
        exportTask?.cancel()
        generating = true
        exportTask = Task { @MainActor in
            await Task.yield()
            defer {
                generating = false
                exportTask = nil
            }
            do {
                let work = try prepareExport(format)
                try Task.checkCancellation()
                let worker = Task.detached(priority: .userInitiated) { try work.generate() }
                let url = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                try Task.checkCancellation()
                exportURL = url
                showingShare = true
            } catch is CancellationError {
                return
            } catch {
                failed = true
            }
        }
    }

    private func prepareExport(_ format: String) throws -> ReportExportWork {
        let batchIDs = matchingBatchIDs
        let plan = try store.reportPlan(format: format.lowercased(), batchIDs: batchIDs)
        let payload = try JSONSerialization.data(withJSONObject: plan, options: [.sortedKeys])
        let setups = try JSONSerialization.data(withJSONObject: store.canonicalReportSetups(batchIDs: batchIDs), options: [.sortedKeys])
        return ReportExportWork(format: format, payload: payload, setups: setups, language: language, localeIdentifier: locale.identifier)
    }
}

private struct ReportExportWork: @unchecked Sendable {
    let format: String
    let payload: Data
    let setups: Data
    let language: AppLanguage
    let localeIdentifier: String

    func generate() throws -> URL {
        try Task.checkCancellation()
        guard let plan = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let setupRows = try JSONSerialization.jsonObject(with: setups) as? [[String: Any]] else {
            throw PressBenchReportExporter.ExportError.encoding
        }
        try Task.checkCancellation()
        let locale = Locale(identifier: localeIdentifier)
        switch format {
        case "PDF": return try PressBenchReportExporter.pdf(plan: plan, setups: setupRows, language: language, locale: locale)
        case "XLSX": return try PressBenchReportExporter.xlsx(plan: plan, setups: setupRows, language: language, locale: locale)
        default: throw PressBenchReportExporter.ExportError.encoding
        }
    }

}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
