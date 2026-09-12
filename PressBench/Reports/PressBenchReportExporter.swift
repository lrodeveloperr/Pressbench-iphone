import Foundation
import UIKit

enum PressBenchReportExporter {
    enum ExportError: LocalizedError {
        case planDenied(String)
        case encoding
        var errorDescription: String? {
            switch self {
            case .planDenied(let reason): return reason
            case .encoding: return "export_encoding"
            }
        }
    }

    static func pdf(
        plan: [String: Any],
        setups: [[String: Any]],
        language: AppLanguage,
        locale: Locale
    ) throws -> URL {
        guard plan["allowed"] as? Bool == true else { throw ExportError.planDenied(plan["reason"] as? String ?? "report_denied") }
        let records = plan["records"] as? [[String: Any]] ?? []
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            var cursor: CGFloat = 42
            var pageNumber = 0

            func beginPage() {
                context.beginPage()
                pageNumber += 1
                cursor = 42
                drawFooter(pageNumber: pageNumber, in: context.cgContext, page: page, language: language, locale: locale)
            }

            func ensure(_ height: CGFloat) {
                if cursor + height > 730 { beginPage() }
            }

            func title(_ text: String) {
                ensure(34)
                draw(text, font: .boldSystemFont(ofSize: 23), color: UIColor(red: 0.02, green: 0.15, blue: 0.35, alpha: 1),
                     rect: CGRect(x: 42, y: cursor, width: 528, height: 30))
                cursor += 35
            }

            func section(_ text: String) {
                ensure(28)
                cursor += 8
                draw(text, font: .boldSystemFont(ofSize: 13), color: .label,
                     rect: CGRect(x: 42, y: cursor, width: 528, height: 20))
                cursor += 25
            }

            beginPage()
            title(PBReportLocalization.text("report.productionReport", language: language, locale: locale))
            draw("PressBench", font: .boldSystemFont(ofSize: 11), color: .secondaryLabel,
                 rect: CGRect(x: 42, y: cursor, width: 528, height: 16))
            cursor += 20
            draw(PBReportLocalization.text("report.operatorValuesNotice", language: language, locale: locale),
                 font: .systemFont(ofSize: 8.5), color: .secondaryLabel,
                 rect: CGRect(x: 42, y: cursor, width: 528, height: 34))
            cursor += 42
            draw("\(PBReportLocalization.text("report.reportingPeriod", language: language, locale: locale)): \(reportingPeriod(records, locale))",
                 font: .systemFont(ofSize: 8.5), color: .secondaryLabel,
                 rect: CGRect(x: 42, y: cursor, width: 528, height: 18))
            cursor += 22

            let totals = reportTotals(records)
            section(PBReportLocalization.text("report.executiveSummary", language: language, locale: locale))
            let metrics: [(String, String)] = [
                ("report.sampleSize", formatInt(records.count, locale)),
                ("report.unitsProcessed", formatInt(totals.processed, locale)),
                ("report.firstPassYield", formatPercent(totals.firstPassYield, locale)),
                ("report.finalYield", formatPercent(totals.finalYield, locale)),
                ("report.reworkRate", formatPercent(totals.reworkRate, locale)),
                ("report.wasteRate", formatPercent(totals.wasteRate, locale))
            ]
            for row in stride(from: 0, to: metrics.count, by: 3) {
                ensure(55)
                for column in 0..<3 where row + column < metrics.count {
                    let item = metrics[row + column]
                    let x = 42 + CGFloat(column) * 176
                    draw(item.1, font: .boldSystemFont(ofSize: 15), color: UIColor(red: 0.02, green: 0.15, blue: 0.35, alpha: 1),
                         rect: CGRect(x: x, y: cursor, width: 166, height: 20), alignment: .center)
                    draw(PBReportLocalization.text(item.0, language: language, locale: locale),
                         font: .systemFont(ofSize: 7.5), color: .secondaryLabel,
                         rect: CGRect(x: x, y: cursor + 22, width: 166, height: 24), alignment: .center)
                }
                cursor += 55
            }

            section(PBReportLocalization.text("report.runPerformance", language: language, locale: locale))
            let headers = ["report.date", "report.batch", "report.setup", "report.processed", "report.final",
                           "report.reworkedUnits", "report.wasteUnits", "report.firstPass", "report.finalYield"]
            let widths: [CGFloat] = [48, 60, 120, 52, 44, 52, 44, 54, 54]
            func tableRow(_ values: [String], header: Bool = false) {
                ensure(31)
                var x: CGFloat = 42
                for index in values.indices {
                    let rect = CGRect(x: x, y: cursor, width: widths[index], height: 30)
                    UIColor(white: header ? 0.95 : 1, alpha: 1).setFill()
                    context.cgContext.fill(rect)
                    UIColor(white: 0.88, alpha: 1).setStroke()
                    context.cgContext.stroke(rect)
                    draw(values[index], font: header ? .boldSystemFont(ofSize: 6.6) : .systemFont(ofSize: 6.4), color: .label,
                         rect: rect.insetBy(dx: 3, dy: 5), alignment: index >= 3 ? .right : .left)
                    x += widths[index]
                }
                cursor += 30
            }
            tableRow(headers.map { PBReportLocalization.text($0, language: language, locale: locale) }, header: true)
            for batch in records {
                if cursor + 31 > 730 {
                    beginPage()
                    section(PBReportLocalization.text("report.runPerformance", language: language, locale: locale))
                    tableRow(headers.map { PBReportLocalization.text($0, language: language, locale: locale) }, header: true)
                }
                let recipe = batch["recipe"] as? [String: Any] ?? [:]
                let processed = int(batch["quantityProcessed"])
                let good = int(batch["quantityGood"])
                let rework = int(batch["quantityReworked"])
                let waste = int(batch["quantityWaste"])
                let firstPass = processed > 0 ? Double(max(0, good - rework)) / Double(processed) : 0
                let finalYield = processed > 0 ? Double(good) / Double(processed) : 0
                tableRow([
                    shortDate(batch["completedAt"] as? String, locale),
                    batch["id"] as? String ?? "",
                    localizedSetupTitle(recipe, language: language, locale: locale),
                    formatInt(processed, locale),
                    formatInt(good, locale),
                    formatInt(rework, locale),
                    formatInt(waste, locale),
                    formatPercent(firstPass, locale),
                    formatPercent(finalYield, locale)
                ])
            }

            section(PBReportLocalization.text("report.issuesExceptions", language: language, locale: locale))
            var issueCount = 0
            for batch in records {
                for issue in batch["issues"] as? [[String: Any]] ?? [] {
                    issueCount += 1
                    if cursor + 44 > 730 {
                        beginPage()
                        section(PBReportLocalization.text("report.issuesExceptions", language: language, locale: locale))
                    }
                    let line = [
                        batch["id"] as? String ?? "",
                        localizedIssueValue(issue["symptom"] as? String, prefix: "issue.symptom", language: language, locale: locale),
                        localizedIssueValue(issue["suspectedCause"] as? String, prefix: "issue.cause", language: language, locale: locale),
                        localizedIssueValue(issue["disposition"] as? String, prefix: "issue.disposition", language: language, locale: locale),
                        formatInt(int(issue["quantity"]), locale)
                    ].filter { !$0.isEmpty }.joined(separator: " · ")
                    draw(line, font: .systemFont(ofSize: 8), color: .label,
                         rect: CGRect(x: 42, y: cursor, width: 528, height: 18))
                    draw(issue["note"] as? String ?? "", font: .systemFont(ofSize: 7.2), color: .secondaryLabel,
                         rect: CGRect(x: 42, y: cursor + 18, width: 528, height: 22))
                    cursor += 44
                }
            }
            if issueCount == 0 {
                draw(PBReportLocalization.text("report.noIssues", language: language, locale: locale),
                     font: .systemFont(ofSize: 9), color: .secondaryLabel,
                     rect: CGRect(x: 42, y: cursor, width: 528, height: 18))
                cursor += 24
            }

            section(PBReportLocalization.text("report.setupDefinitions", language: language, locale: locale))
            for setup in setups {
                if cursor + 104 > 730 {
                    beginPage()
                    section(PBReportLocalization.text("report.setupDefinitions", language: language, locale: locale))
                }
                let titleText = localizedSetupTitle(setup, language: language, locale: locale)
                let instructionSource = setup["instructionSource"] as? [String: Any] ?? [:]
                let facts = [
                    "\(PBReportLocalization.text("report.batch", language: language, locale: locale)): \((setup["reportBatchIDs"] as? [String] ?? []).joined(separator: ", "))",
                    "\(PBReportLocalization.text("report.materialTransfer", language: language, locale: locale)): \(localizedPreset(setup["blankMaterial"] as? String, group: .materials, language: language, locale: locale)) / \(localizedPreset(setup["transferMedium"] as? String, group: .transferMedia, language: language, locale: locale))",
                    "\(PBReportLocalization.text("report.machinePlaten", language: language, locale: locale)): \(localizedMachineNickname(setup, language: language, locale: locale)) / \(localizedPreset(setup["platenZone"] as? String, group: .platenSizes, language: language, locale: locale))",
                    "\(PBReportLocalization.text("report.instructionSource", language: language, locale: locale)): \(localizedPreset(instructionSource["name"] as? String, group: .instructionSources, language: language, locale: locale))",
                    "\(PBReportLocalization.text("common.reference", language: language, locale: locale)): \(instructionSource["reference"] as? String ?? "")"
                ]
                draw(titleText, font: .boldSystemFont(ofSize: 9), color: .label,
                     rect: CGRect(x: 42, y: cursor, width: 528, height: 18))
                cursor += 19
                for fact in facts {
                    draw(fact, font: .systemFont(ofSize: 7.2), color: .secondaryLabel,
                         rect: CGRect(x: 50, y: cursor, width: 520, height: 16))
                    cursor += 16
                }
                for (index, stage) in (setup["steps"] as? [[String: Any]] ?? []).enumerated() {
                    let summaryText = stageSummary(stage, index: index, language: language, locale: locale)
                    let summaryHeight = wrappedHeight(summaryText, font: .boldSystemFont(ofSize: 7.2), width: 520)
                    let detailText = stageDetail(stage)
                    let detailHeight = detailText.isEmpty ? CGFloat(0) : wrappedHeight(detailText, font: .systemFont(ofSize: 7), width: 512)
                    let stageHeight = summaryHeight + detailHeight + 4
                    if cursor + stageHeight > 730 {
                        beginPage()
                        section(PBReportLocalization.text("report.setupDefinitions", language: language, locale: locale))
                        draw(titleText, font: .boldSystemFont(ofSize: 9), color: .label,
                             rect: CGRect(x: 42, y: cursor, width: 528, height: 18))
                        cursor += 19
                    }
                    drawWrapped(summaryText, font: .boldSystemFont(ofSize: 7.2), color: .label,
                                rect: CGRect(x: 50, y: cursor, width: 520, height: summaryHeight))
                    if !detailText.isEmpty {
                        drawWrapped(detailText, font: .systemFont(ofSize: 7), color: .secondaryLabel,
                                    rect: CGRect(x: 58, y: cursor + summaryHeight, width: 512, height: detailHeight))
                    }
                    cursor += stageHeight
                }
                cursor += 7
            }
        }
        return try write(data, name: "PressBench-Production-Report.pdf")
    }

    static func xlsx(
        plan: [String: Any],
        setups: [[String: Any]],
        language: AppLanguage,
        locale: Locale
    ) throws -> URL {
        guard plan["allowed"] as? Bool == true else { throw ExportError.planDenied(plan["reason"] as? String ?? "report_denied") }
        let records = plan["records"] as? [[String: Any]] ?? []
        let totals = reportTotals(records)
        let names = [
            PBReportLocalization.text("report.sheet.summary", language: language, locale: locale),
            PBReportLocalization.text("report.sheet.runs", language: language, locale: locale),
            PBReportLocalization.text("report.sheet.setups", language: language, locale: locale),
            PBReportLocalization.text("report.sheet.issues", language: language, locale: locale)
        ]

        var zip = PBStoredZip()
        zip.add("[Content_Types].xml", contentTypesXML())
        zip.add("_rels/.rels", rootRelationshipsXML())
        zip.add("xl/workbook.xml", workbookXML(sheetNames: names))
        zip.add("xl/_rels/workbook.xml.rels", workbookRelationshipsXML())
        zip.add("xl/styles.xml", stylesXML())

        let summaryRows: [[PBXLSXCell]] = [
            [.text(PBReportLocalization.text("report.productionReport", language: language, locale: locale))],
            [.text(PBReportLocalization.text("report.operatorValuesNotice", language: language, locale: locale))],
            [.text(PBReportLocalization.text("report.reportingPeriod", language: language, locale: locale)), .text(reportingPeriod(records, locale))],
            [.text(PBReportLocalization.text("report.sampleSize", language: language, locale: locale)), .number(Double(records.count))],
            [.text(PBReportLocalization.text("report.unitsProcessed", language: language, locale: locale)), .number(Double(totals.processed))],
            [.text(PBReportLocalization.text("report.firstPassYield", language: language, locale: locale)), .number(totals.firstPassYield)],
            [.text(PBReportLocalization.text("report.finalYield", language: language, locale: locale)), .number(totals.finalYield)],
            [.text(PBReportLocalization.text("report.reworkRate", language: language, locale: locale)), .number(totals.reworkRate)],
            [.text(PBReportLocalization.text("report.wasteRate", language: language, locale: locale)), .number(totals.wasteRate)]
        ]
        zip.add("xl/worksheets/sheet1.xml", worksheetXML(summaryRows, percentRows: [6, 7, 8, 9], widths: [34, 24], titleRows: [1]))

        var runRows = [[PBXLSXCell]]()
        runRows.append(["report.date", "report.batch", "report.setup", "report.processed", "report.final",
                        "report.reworkedUnits", "report.wasteUnits", "report.firstPass", "report.finalYield"].map {
            .text(PBReportLocalization.text($0, language: language, locale: locale))
        })
        for batch in records {
            let recipe = batch["recipe"] as? [String: Any] ?? [:]
            let processed = int(batch["quantityProcessed"]), good = int(batch["quantityGood"]), rework = int(batch["quantityReworked"])
            let waste = int(batch["quantityWaste"])
            runRows.append([
                .text(shortDate(batch["completedAt"] as? String, locale)),
                .text(batch["id"] as? String ?? ""),
                .text(localizedSetupTitle(recipe, language: language, locale: locale)),
                .number(Double(processed)),
                .number(Double(good)),
                .number(Double(rework)),
                .number(Double(waste)),
                .number(processed > 0 ? Double(max(0, good - rework)) / Double(processed) : 0),
                .number(processed > 0 ? Double(good) / Double(processed) : 0)
            ])
        }
        zip.add("xl/worksheets/sheet2.xml", worksheetXML(runRows, percentColumns: [8, 9], widths: [15, 22, 30, 12, 12, 14, 12, 13, 13], headerRow: 1))

        var setupRows: [[PBXLSXCell]] = [[
            .text(PBReportLocalization.text("report.batch", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.setup", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.materialTransfer", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.machinePlaten", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.pressStage", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.instructionSource", language: language, locale: locale))
        ]]
        for setup in setups {
            let source = setup["instructionSource"] as? [String: Any] ?? [:]
            let steps = setup["steps"] as? [[String: Any]] ?? []
            let exportedSteps = steps.isEmpty ? [[:]] : steps
            for (index, stage) in exportedSteps.enumerated() {
                setupRows.append([
                    .text((setup["reportBatchIDs"] as? [String] ?? []).joined(separator: ", ")),
                    .text(localizedSetupTitle(setup, language: language, locale: locale)),
                    .text([
                        localizedPreset(setup["blankMaterial"] as? String, group: .materials, language: language, locale: locale),
                        localizedPreset(setup["transferMedium"] as? String, group: .transferMedia, language: language, locale: locale)
                    ].filter { !$0.isEmpty }.joined(separator: " / ")),
                    .text([
                        localizedMachineNickname(setup, language: language, locale: locale),
                        localizedPreset(setup["platenZone"] as? String, group: .platenSizes, language: language, locale: locale)
                    ].filter { !$0.isEmpty }.joined(separator: " / ")),
                    .text(stage.isEmpty ? "" : [stageSummary(stage, index: index, language: language, locale: locale), stageDetail(stage)].filter { !$0.isEmpty }.joined(separator: " · ")),
                    .text([
                        localizedPreset(source["name"] as? String, group: .instructionSources, language: language, locale: locale),
                        source["reference"] as? String ?? ""
                    ].filter { !$0.isEmpty }.joined(separator: " · "))
                ])
            }
        }
        zip.add("xl/worksheets/sheet3.xml", worksheetXML(setupRows, widths: [26, 28, 34, 30, 52, 44], headerRow: 1))

        var issueRows: [[PBXLSXCell]] = [[
            .text(PBReportLocalization.text("report.batch", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.symptom", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.suspectedCause", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.disposition", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.quantity", language: language, locale: locale)),
            .text(PBReportLocalization.text("report.note", language: language, locale: locale))
        ]]
        for batch in records {
            for issue in batch["issues"] as? [[String: Any]] ?? [] {
                issueRows.append([
                    .text(batch["id"] as? String ?? ""),
                    .text(localizedIssueValue(issue["symptom"] as? String, prefix: "issue.symptom", language: language, locale: locale)),
                    .text(localizedIssueValue(issue["suspectedCause"] as? String, prefix: "issue.cause", language: language, locale: locale)),
                    .text(localizedIssueValue(issue["disposition"] as? String, prefix: "issue.disposition", language: language, locale: locale)),
                    .number(Double(int(issue["quantity"]))), .text(issue["note"] as? String ?? "")
                ])
            }
        }
        zip.add("xl/worksheets/sheet4.xml", worksheetXML(issueRows, widths: [22, 24, 24, 18, 12, 44], headerRow: 1))
        return try write(zip.data(), name: "PressBench-Detailed-Report.xlsx")
    }

    // MARK: - PDF helpers

    private static func drawFooter(pageNumber: Int, in cg: CGContext, page: CGRect, language: AppLanguage, locale: Locale) {
        let lineY: CGFloat = 755
        cg.setStrokeColor(UIColor(white: 0.88, alpha: 1).cgColor)
        cg.move(to: CGPoint(x: 42, y: lineY)); cg.addLine(to: CGPoint(x: 570, y: lineY)); cg.strokePath()
        draw("PressBench · \(PBReportLocalization.text("report.productionReport", language: language, locale: locale))", font: .systemFont(ofSize: 6.5), color: .secondaryLabel,
             rect: CGRect(x: 42, y: lineY + 7, width: 430, height: 12))
        draw("\(pageNumber)", font: .systemFont(ofSize: 6.5), color: .secondaryLabel,
             rect: CGRect(x: 520, y: lineY + 7, width: 50, height: 12), alignment: .right)
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, rect: CGRect, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle(); style.alignment = alignment; style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }
    private static func wrappedHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
        return ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style], context: nil
        ).height)
    }
    private static func drawWrapped(_ text: String, font: UIFont, color: UIColor, rect: CGRect) {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    private struct Totals {
        var processed = 0, good = 0, rework = 0, waste = 0
        var firstPassYield: Double { processed > 0 ? Double(max(0, good - rework)) / Double(processed) : 0 }
        var finalYield: Double { processed > 0 ? Double(good) / Double(processed) : 0 }
        var reworkRate: Double { processed > 0 ? Double(rework) / Double(processed) : 0 }
        var wasteRate: Double { processed > 0 ? Double(waste) / Double(processed) : 0 }
    }

    private static func reportTotals(_ records: [[String: Any]]) -> Totals {
        records.reduce(into: Totals()) { total, batch in
            total.processed += int(batch["quantityProcessed"])
            total.good += int(batch["quantityGood"])
            total.rework += int(batch["quantityReworked"])
            total.waste += int(batch["quantityWaste"])
        }
    }

    private static func formatInt(_ value: Int, _ locale: Locale) -> String { value.formatted(.number.locale(locale)) }
    private static func formatPercent(_ value: Double, _ locale: Locale) -> String { value.formatted(.percent.precision(.fractionLength(1)).locale(locale)) }
    private static func shortDate(_ value: String?, _ locale: Locale) -> String {
        guard let value, let date = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value)) ?? (try? Date.ISO8601FormatStyle().parse(value)) else { return value ?? "" }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }
    private static func reportingPeriod(_ records: [[String: Any]], _ locale: Locale) -> String {
        let dates = records.compactMap { record -> Date? in
            guard let value = record["completedAt"] as? String else { return nil }
            return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value)) ??
                (try? Date.ISO8601FormatStyle().parse(value))
        }.sorted()
        guard let first = dates.first, let last = dates.last else { return "—" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        let firstText = first.formatted(style)
        let lastText = last.formatted(style)
        return firstText == lastText ? firstText : "\(firstText) – \(lastText)"
    }
    private static func int(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Double { return Int(value) }
        return 0
    }
    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
    private static func temperatureText(_ setup: [String: Any], locale: Locale) -> String {
        guard let value = double(setup["temperature"]) else { return "" }
        let number = PBFormat.decimal(value, locale: locale)
        return "\(number)°\(setup["temperatureUnit"] as? String ?? "")"
    }
    private static func durationText(_ setup: [String: Any], locale: Locale) -> String {
        let duration = int(setup["pressTimeSeconds"])
        return duration > 0 ? PBFormat.seconds(duration, locale: locale) : ""
    }
    private static func stageSummary(_ stage: [String: Any], index: Int, language: AppLanguage, locale: Locale) -> String {
        let type = stage["stageType"] as? String ?? ""
        let storedName = stage["name"] as? String ?? ""
        let canonicalKey = "stage.\(type)"
        let name = storedName.isEmpty && PBL10n.catalog.strings[canonicalKey] != nil
            ? PBReportLocalization.text(canonicalKey, language: language, locale: locale) : storedName
        let temperature = double(stage["temperature"]).map {
            "\(PBFormat.decimal($0, locale: locale))°\(stage["temperatureUnit"] as? String ?? "")"
        } ?? ""
        let duration = int(stage["durationSeconds"])
        let durationLabel = duration > 0 ? PBFormat.seconds(duration, locale: locale) : ""
        let pressure = localizedPreset(stage["pressure"] as? String, group: .pressureDescriptions, language: language, locale: locale)
        let machine = stage["machineNickname"] as? String ?? ""
        let platen = localizedPreset(stage["platenZone"] as? String, group: .platenSizes, language: language, locale: locale)
        let repeatCount = max(1, int(stage["repeatCount"]))
        let repeatLabel = repeatCount > 1 ? "×\(repeatCount)" : ""
        return ["\(index + 1). \(name)", machine, platen, temperature, durationLabel, pressure, repeatLabel]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
    private static func stageDetail(_ stage: [String: Any]) -> String {
        [stage["instruction"], stage["placementAction"], stage["finishAction"]]
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
    private static func localizedPreset(
        _ value: String?,
        group: PBPrefillCatalog.Group,
        language: AppLanguage,
        locale: Locale
    ) -> String {
        PBPrefillCatalog.localizedValue(value ?? "", for: group, language: language, locale: locale)
    }
    private static func localizedSetupTitle(
        _ setup: [String: Any],
        language: AppLanguage,
        locale: Locale
    ) -> String {
        let title = setup["title"] as? String ?? ""
        let material = setup["blankMaterial"] as? String ?? ""
        let transfer = setup["transferMedium"] as? String ?? ""
        let machine = setup["machineNickname"] as? String ?? ""
        let generated = [material, transfer, machine].filter { !$0.isEmpty }.joined(separator: " · ")
        guard !title.isEmpty, title == generated else { return title }
        return [
            localizedPreset(material, group: .materials, language: language, locale: locale),
            localizedPreset(transfer, group: .transferMedia, language: language, locale: locale),
            localizedMachineNickname(setup, language: language, locale: locale)
        ].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    private static func localizedMachineNickname(
        _ setup: [String: Any],
        language: AppLanguage,
        locale: Locale
    ) -> String {
        let nickname = setup["machineNickname"] as? String ?? ""
        let platen = setup["platenZone"] as? String ?? ""
        return nickname == platen
            ? localizedPreset(platen, group: .platenSizes, language: language, locale: locale)
            : nickname
    }
    private static func localizedIssueValue(
        _ value: String?,
        prefix: String,
        language: AppLanguage,
        locale: Locale
    ) -> String {
        guard let value, !value.isEmpty else { return "" }
        let key = "\(prefix).\(value)"
        guard PBL10n.catalog.strings[key] != nil else { return value }
        return PBReportLocalization.text(key, language: language, locale: locale)
    }

    private static func write(_ data: Data, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PressBenchExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - XLSX

    private enum PBXLSXCell { case text(String), number(Double) }

    private static func worksheetXML(
        _ rows: [[PBXLSXCell]],
        percentRows: Set<Int> = [],
        percentColumns: Set<Int> = [],
        widths: [Double] = [],
        headerRow: Int? = nil,
        titleRows: Set<Int> = []
    ) -> String {
        var output = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">"#
        if let headerRow {
            output += "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"\(headerRow)\" topLeftCell=\"A\(headerRow + 1)\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
        }
        output += "<sheetFormatPr defaultRowHeight=\"18\"/>"
        if !widths.isEmpty {
            output += "<cols>" + widths.enumerated().map { index, width in
                "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
            }.joined() + "</cols>"
        }
        output += "<sheetData>"
        for (rowIndex, row) in rows.enumerated() {
            let excelRow = rowIndex + 1
            let rowHeight = titleRows.contains(excelRow) ? " ht=\"28\" customHeight=\"1\"" : (headerRow == excelRow ? " ht=\"30\" customHeight=\"1\"" : "")
            output += "<row r=\"\(excelRow)\"\(rowHeight)>"
            for (columnIndex, cell) in row.enumerated() {
                let reference = "\(columnName(columnIndex + 1))\(excelRow)"
                let baseStyle: Int
                if titleRows.contains(excelRow) { baseStyle = 3 }
                else if headerRow == excelRow { baseStyle = 2 }
                else { baseStyle = 4 }
                switch cell {
                case .text(let value):
                    output += "<c r=\"\(reference)\" s=\"\(baseStyle)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(value))</t></is></c>"
                case .number(let value):
                    let style = percentRows.contains(excelRow) || percentColumns.contains(columnIndex + 1) ? 1 : baseStyle
                    output += "<c r=\"\(reference)\" s=\"\(style)\"><v>\(value)</v></c>"
                }
            }
            output += "</row>"
        }
        output += "</sheetData>"
        if let headerRow, let maxColumns = rows.map(\.count).max(), maxColumns > 0 {
            output += "<autoFilter ref=\"A\(headerRow):\(columnName(maxColumns))\(max(headerRow, rows.count))\"/>"
        }
        output += "</worksheet>"
        return output
    }

    private static func contentTypesXML() -> String {
        #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet4.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>"#
    }
    private static func rootRelationshipsXML() -> String {
        #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>"#
    }
    private static func workbookRelationshipsXML() -> String {
        #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet4.xml"/><Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>"#
    }
    private static func workbookXML(sheetNames: [String]) -> String {
        let sheets = sheetNames.enumerated().map { index, name in
            "<sheet name=\"\(xmlAttribute(name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }.joined()
        return #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>"# + sheets + "</sheets></workbook>"
    }
    private static func stylesXML() -> String {
        #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="0.0%"/></numFmts><fonts count="3"><font><sz val="11"/><name val="Aptos"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font><font><b/><sz val="16"/><color rgb="FF173B72"/><name val="Aptos Display"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF245FC7"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="5"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFill="1" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs></styleSheet>"#
    }
    private static func columnName(_ index: Int) -> String {
        var n = index, result = ""
        while n > 0 { n -= 1; result = String(UnicodeScalar(65 + (n % 26))!) + result; n /= 26 }
        return result
    }
    static func xml(_ value: String) -> String {
        let xml10 = String(value.unicodeScalars.filter { scalar in
            scalar.value == 0x9 || scalar.value == 0xA || scalar.value == 0xD ||
                (0x20...0xD7FF).contains(scalar.value) ||
                (0xE000...0xFFFD).contains(scalar.value) ||
                (0x10000...0x10FFFF).contains(scalar.value)
        })
        return xml10.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    private static func xmlAttribute(_ value: String) -> String {
        xml(value).replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
}

private struct PBStoredZip {
    private struct Entry { let name: Data; let data: Data; let crc: UInt32; let offset: UInt32 }
    private var buffer = Data()
    private var entries = [Entry]()

    mutating func add(_ name: String, _ string: String) { add(name, Data(string.utf8)) }
    mutating func add(_ name: String, _ data: Data) {
        let nameData = Data(name.utf8), crc = crc32(data), offset = UInt32(buffer.count)
        buffer.appendLE(UInt32(0x04034b50)); buffer.appendLE(UInt16(20)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0))
        buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0)); buffer.appendLE(crc); buffer.appendLE(UInt32(data.count)); buffer.appendLE(UInt32(data.count))
        buffer.appendLE(UInt16(nameData.count)); buffer.appendLE(UInt16(0)); buffer.append(nameData); buffer.append(data)
        entries.append(Entry(name: nameData, data: data, crc: crc, offset: offset))
    }

    mutating func data() -> Data {
        let centralOffset = UInt32(buffer.count)
        for entry in entries {
            buffer.appendLE(UInt32(0x02014b50)); buffer.appendLE(UInt16(20)); buffer.appendLE(UInt16(20)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0))
            buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0)); buffer.appendLE(entry.crc); buffer.appendLE(UInt32(entry.data.count)); buffer.appendLE(UInt32(entry.data.count))
            buffer.appendLE(UInt16(entry.name.count)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt32(0)); buffer.appendLE(entry.offset); buffer.append(entry.name)
        }
        let centralSize = UInt32(buffer.count) - centralOffset
        buffer.appendLE(UInt32(0x06054b50)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(0)); buffer.appendLE(UInt16(entries.count)); buffer.appendLE(UInt16(entries.count)); buffer.appendLE(centralSize); buffer.appendLE(centralOffset); buffer.appendLE(UInt16(0))
        return buffer
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (0xedb88320 & UInt32(bitPattern: -Int32(crc & 1))) }
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
