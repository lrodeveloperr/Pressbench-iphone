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

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        List {
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
                                    Text(PBL10n.format(
                                        "upgrade.pricePerMonthFormat", language: language, locale: locale,
                                        price as NSString
                                    ))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            if let exportURL {
                Section {
                    ShareLink(item: exportURL) {
                        Label(exportURL.lastPathComponent, systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 64)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .tint(PBTheme.primary)
        .navigationTitle(t("report.productionReport"))
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
        }
        .disabled(generating)
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
        let plan = try store.reportPlan(format: format.lowercased())
        let payload = try JSONSerialization.data(withJSONObject: plan, options: [.sortedKeys])
        let setups = try JSONSerialization.data(withJSONObject: store.canonicalReportSetups, options: [.sortedKeys])
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
