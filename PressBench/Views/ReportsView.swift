import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var exportURL: URL?
    @State private var failed = false
    @State private var generating = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        List {
            Section {
                exportButton(format: "CSV", systemImage: "tablecells") { try makeCSV() }
                exportButton(format: "JSON", systemImage: "curlybraces") { try makeJSON() }
                exportButton(format: "PDF", systemImage: "doc.richtext") { try makePDF() }
                    .disabled(!store.isPro)
                exportButton(format: "XLSX", systemImage: "tablecells.badge.ellipsis") { try makeXLSX() }
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
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t("common.actionFailed")) }
    }

    private func exportButton(format: String, systemImage: String, action: @escaping () throws -> URL) -> some View {
        Button {
            generating = true
            defer { generating = false }
            do { exportURL = try action() }
            catch { failed = true }
        } label: {
            HStack {
                Label(format, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.forward").foregroundStyle(PBTheme.secondary)
            }
        }
    }

    private func makeCSV() throws -> URL {
        let text = try store.csvExport()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PressBenchExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("PressBench-Detailed-Export.csv")
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private func makeJSON() throws -> URL {
        try PressBenchReportExporter.json(plan: store.reportPlan(format: "json"))
    }

    private func makePDF() throws -> URL {
        try PressBenchReportExporter.pdf(
            plan: store.reportPlan(format: "pdf"),
            setups: store.canonicalReportSetups,
            language: language,
            locale: locale
        )
    }

    private func makeXLSX() throws -> URL {
        try PressBenchReportExporter.xlsx(
            plan: store.reportPlan(format: "xlsx"),
            setups: store.canonicalReportSetups,
            language: language,
            locale: locale
        )
    }
}
