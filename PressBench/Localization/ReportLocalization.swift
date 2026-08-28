import Foundation

/// Human-facing PDF/XLSX report copy uses the same 31-language catalog as the UI.
/// CSV/JSON schema keys intentionally remain canonical and are never localized,
/// so exports stay machine-readable and backward compatible.
enum PBReportLocalization {
    static let humanReportKeys: [String] = [
        "report.productionReport", "report.generatedBy", "report.reportingPeriod", "report.executiveSummary",
        "report.runPerformance", "report.issuesExceptions", "report.setupDefinitions", "report.sampleSize",
        "report.unitsProcessed", "report.firstPassYield", "report.finalYield", "report.reworkRate", "report.wasteRate",
        "report.reworkedUnits", "report.wasteUnits", "report.outcomeMix", "report.date", "report.batch", "report.setup",
        "report.processed", "report.firstPass", "report.final", "report.outcome", "report.symptom", "report.suspectedCause",
        "report.disposition", "report.quantity", "report.note", "report.materialTransfer", "report.machinePlaten",
        "report.pressStage", "report.instructionSource", "report.sourceChecked", "report.noIssues", "report.lowData",
        "report.operatorValuesNotice", "report.sheet.summary", "report.sheet.runs", "report.sheet.setups", "report.sheet.issues"
    ]

    static func text(_ key: String, language: AppLanguage, locale: Locale) -> String {
        PBL10n.text(key, language: language, locale: locale)
    }
}
