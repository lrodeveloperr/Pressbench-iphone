import XCTest
@testable import PressBench

@MainActor
final class ReportExporterTests: XCTestCase {
    private var sampleBatch: [String: Any] {
        [
            "id": "B-1", "quantityProcessed": 10, "quantityGood": 9, "quantityWaste": 1, "quantityReworked": 1,
            "outcome": "rework", "completedAt": "2026-08-19T12:00:00.000Z",
            "issues": [["quantity": 1, "symptom": "=HYPERLINK(\"https://example.invalid\")", "suspectedCause": "unknown", "disposition": "reworked", "note": "+SUM(1,1)"]],
            "recipe": ["title": "=1+1", "blankMaterial": "Cotton", "transferMedium": "DTF"]
        ]
    }

    private var sampleSetup: [String: Any] {
        ["title": "=1+1", "blankMaterial": "Cotton", "transferMedium": "DTF", "machineNickname": "Press A", "platenZone": "Main", "temperature": 325, "temperatureUnit": "F", "pressTimeSeconds": 15, "instructionSource": ["name": "Supplier"]]
    }

    func testPremiumRenderersCreateReadableArtifactsWithoutFormulaCells() throws {
        let plan: [String: Any] = ["allowed": true, "datasetFingerprint": "sha256:test", "records": [sampleBatch]]
        let language = AppLanguage.en
        let locale = Locale(identifier: "en-US")
        let pdf = try PressBenchReportExporter.pdf(plan: plan, setups: [sampleSetup], language: language, locale: locale)
        let xlsx = try PressBenchReportExporter.xlsx(plan: plan, setups: [sampleSetup], language: language, locale: locale)

        let pdfData = try Data(contentsOf: pdf)
        XCTAssertTrue(String(decoding: pdfData.prefix(4), as: UTF8.self).hasPrefix("%PDF"))

        let xlsxData = try Data(contentsOf: xlsx)
        XCTAssertEqual(Array(xlsxData.prefix(2)), [0x50, 0x4B])
        let archiveText = String(decoding: xlsxData, as: UTF8.self)
        XCTAssertTrue(archiveText.contains("t=\"inlineStr\""))
        XCTAssertFalse(archiveText.contains("<f>"))
    }

}
