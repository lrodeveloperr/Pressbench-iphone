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

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        List {
            Section {
                exportButton(format: "CSV", systemImage: "tablecells")
                exportButton(format: "JSON", systemImage: "curlybraces")
                exportButton(format: "PDF", systemImage: "doc.richtext")
                    .disabled(!store.isPro)
                exportButton(format: "XLSX", systemImage: "tablecells.badge.ellipsis")
                    .disabled(!store.isPro)
            } header: {
                Text(t("common.exports"))
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
                            Task { await store.purchasePro() }
                        } label: {
                            HStack {
                                Text(t("common.unlockPro"))
                                Spacer()
                                if let price = store.productDisplayPrice { Text(price) }
                            }
                        }
                        Button(t("common.restorePurchases")) { Task { await store.restorePurchases() } }
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
        .navigationTitle(t("common.exports"))
        .overlay { if generating { ProgressView().controlSize(.large) } }
        .sheet(isPresented: $showingShare) {
            if let exportURL { ActivityShareView(items: [exportURL as Any]) }
        }
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t("common.actionFailed")) }
    }

    private func exportButton(format: String, systemImage: String) -> some View {
        Button {
            startExport(format)
        } label: {
            HStack {
                Label(format, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.forward").foregroundStyle(PBTheme.secondary)
            }
        }
        .disabled(generating)
    }

    private func startExport(_ format: String) {
        generating = true
        Task { @MainActor in
            await Task.yield()
            defer { generating = false }
            do {
                let work = try prepareExport(format)
                exportURL = try await Task.detached(priority: .userInitiated) { try work.generate() }.value
                showingShare = true
            } catch {
                failed = true
            }
        }
    }

    private func prepareExport(_ format: String) throws -> ReportExportWork {
        if format == "CSV" {
            guard let data = try store.csvExport().data(using: .utf8) else {
                throw PressBenchReportExporter.ExportError.encoding
            }
            return ReportExportWork(format: format, payload: data, setups: Data(), language: language, localeIdentifier: locale.identifier)
        }
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
        if format == "CSV" { return try write(payload, name: "PressBench-Detailed-Export.csv") }
        guard let plan = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let setupRows = try JSONSerialization.jsonObject(with: setups) as? [[String: Any]] else {
            throw PressBenchReportExporter.ExportError.encoding
        }
        let locale = Locale(identifier: localeIdentifier)
        switch format {
        case "JSON": return try PressBenchReportExporter.json(plan: plan)
        case "PDF": return try PressBenchReportExporter.pdf(plan: plan, setups: setupRows, language: language, locale: locale)
        case "XLSX": return try PressBenchReportExporter.xlsx(plan: plan, setups: setupRows, language: language, locale: locale)
        default: throw PressBenchReportExporter.ExportError.encoding
        }
    }

    private func write(_ data: Data, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PressBenchExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
