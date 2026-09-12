import Foundation

/// Editable starting points transcribed from current manufacturer instructions.
/// Operators must confirm the instructions for their exact material and product
/// before a run; entries never enter the app as Proven setups.
enum PBSetupPresetCatalog {
    struct Entry: Identifiable, Equatable {
        let brand: String
        let name: String
        let temperatureF: Int
        let durationSeconds: Int
        let pressure: String
        let peel: String
        var material: String = "Cotton/polyester blend"
        var compatibleMaterials: [String] = []
        var temperatureRangeF: ClosedRange<Int>? = nil
        var durationRangeSeconds: ClosedRange<Int>? = nil
        var prepressSeconds: Int = 3
        var applicationNote: String = "Confirm the current instructions for the exact blank before production."
        var aftercare: String = ""
        var secondPress: (temperatureF: Int, durationSeconds: Int, pressure: String)? = nil

        var id: String { "\(brand)|\(name)" }
        var sourceURL: URL {
            if brand == "Transfer Express" {
                return URL(string: "https://www.transferexpress.com/application-instructions")!
            }
            let productPages: [(String, String)] = [
                ("ColorPrint Easy", "colorprint-easy"),
                ("ColorPrint Extra PU", "colorprint-extra"),
                ("ColorPrint PU", "colorprint-pu"),
                ("DigiBrick", "digibrick"),
                ("Hi-5 Print Matte", "hi-5-print-matte"),
                ("SparklePrint", "sparkleprint"),
                ("S-Print", "s-print"),
                ("Sublithin Soft", "sublithin-soft"),
                ("ColorPrint Aurora", "colorprint-aurora")
            ]
            if let page = productPages.first(where: { name.hasPrefix($0.0) })?.1 {
                return URL(string: "https://www.siserna.com/\(page)/")!
            }
            return URL(string: "https://www.siserna.com/files/heat-transfer-vinyl-instructions.pdf")!
        }
        var sourceCheckedDate: String { "2026-09-11" }
        /// Bundled manufacturer values are editable published guidance only.
        /// They never bypass the current-instruction confirmation or enter the
        /// app as an operator-proven setup.
        var requiresCurrentInstructionConfirmation: Bool { true }
        var bundledStatus: String { "draft" }
        var isOperatorProven: Bool { false }
        var temperatureLabel: String {
            guard let range = temperatureRangeF else { return "\(temperatureF)°F" }
            return "\(range.lowerBound)–\(range.upperBound)°F"
        }
        var durationLabel: String {
            guard let range = durationRangeSeconds else { return "\(durationSeconds) s" }
            return "\(range.lowerBound)–\(range.upperBound) s"
        }
        var publishedGuidance: String {
            "Published range: \(temperatureLabel), \(durationLabel), \(pressure.lowercased()) pressure. \(applicationNote)"
        }
        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    private static func e(
        _ brand: String, _ name: String, _ temperatureF: Int, _ seconds: Int,
        _ pressure: String, _ peel: String, material: String = "Cotton/polyester blend",
        compatibleMaterials: [String]? = nil,
        temperatureRange: ClosedRange<Int>? = nil, durationRange: ClosedRange<Int>? = nil,
        prepress: Int? = nil, note: String? = nil,
        second: (Int, Int, String)? = nil
    ) -> Entry {
        Entry(
            brand: brand, name: name, temperatureF: temperatureF, durationSeconds: seconds,
            pressure: pressure, peel: peel, material: material,
            compatibleMaterials: compatibleMaterials ?? standardTextiles,
            temperatureRangeF: temperatureRange, durationRangeSeconds: durationRange,
            prepressSeconds: prepress ?? 3,
            applicationNote: note ?? "Confirm the current instructions for the exact blank before production.",
            aftercare: brand == "Siser" ? "Wait 24 hours before the first wash and follow the current product care instructions." : "",
            secondPress: second.map { (temperatureF: $0.0, durationSeconds: $0.1, pressure: $0.2) }
        )
    }

    private static let cotton = "100% cotton T-shirt"
    private static let polyester = "100% polyester T-shirt"
    private static let blend = "Cotton/polyester blend"
    private static let triBlend = "Tri-blend garment"
    private static let sublimatedPolyester = "Sublimated polyester"
    private static let stretch = "Stretch fabric"
    private static let nylon = "Nylon"
    private static let leather = "Leather"
    private static let standardTextiles = [cotton, polyester, blend]

    static var sources: [String] {
        Array(Set(entries.map(\.brand))).sorted()
    }

    static var materials: [String] {
        var seen = Set<String>()
        return entries.flatMap(\.compatibleMaterials).filter { seen.insert($0).inserted }
    }

    static func filteredEntries(search: String, source: String, material: String) -> [Entry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let sourceMatches = source.isEmpty || entry.brand == source
            let materialMatches = material.isEmpty || entry.compatibleMaterials.contains(material)
            guard sourceMatches, materialMatches else { return false }
            guard !query.isEmpty else { return true }
            return [entry.brand, entry.name, entry.material, entry.temperatureLabel,
                    entry.durationLabel, entry.pressure, entry.peel]
                .contains { $0.localizedCaseInsensitiveContains(query) } ||
                entry.compatibleMaterials.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// A material filter is an explicit operator choice, not merely a search hint.
    /// Carry it into the draft when the selected preset supports it; otherwise use
    /// the preset's published default material.
    static func resolvedMaterial(for entry: Entry, selectedMaterial: String) -> String {
        let selected = selectedMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
        return entry.compatibleMaterials.contains(selected) ? selected : entry.material
    }

    static let entries: [Entry] = [
        e("Siser", "EasyWeed", 305, 15, "Medium", "Hot or cold", compatibleMaterials: standardTextiles + [leather], durationRange: 10...15),
        e("Siser", "EasyWeed Electric", 305, 15, "Medium", "Hot or cold", compatibleMaterials: standardTextiles + [leather], durationRange: 10...15),
        e("Siser", "EasyWeed Glow in the Dark", 305, 15, "Medium", "Hot or cold", compatibleMaterials: standardTextiles + [leather], durationRange: 10...15),
        e("Siser", "EasyPatterns Plus", 305, 15, "Medium", "Hot or cold", compatibleMaterials: standardTextiles + [leather], durationRange: 10...15),
        e("Siser", "EasyWeed EcoStretch", 250, 15, "Medium", "Hot", compatibleMaterials: standardTextiles + [stretch]),
        e("Siser", "EasyWeed Extra", 305, 15, "Medium", "Hot or cold", compatibleMaterials: standardTextiles + [nylon]),
        e("Siser", "Vernice", 320, 20, "Firm", "Hot or cold"),
        e("Siser", "EasyWeed Sub Block", 265, 15, "Medium", "Hot or cold", material: polyester, compatibleMaterials: [polyester, sublimatedPolyester], durationRange: 10...15),
        e("Siser", "EasyWeed Adhesive: foil base", 275, 15, "Medium", "Hot; then apply top layer", durationRange: 10...15),
        e("Siser", "Easy Puff Glitter: two presses", 310, 3, "Medium", "Warm or cold", durationRange: 2...3, second: (310, 15, "Medium")),
        e("Siser", "EasyReflective", 305, 15, "Medium", "Warm after at least 15 s", compatibleMaterials: standardTextiles + [stretch]),
        e("Siser", "Easy Glow", 305, 15, "Medium", "Warm or cold after 5–10 s"),
        e("Siser", "Easy Puff: single heat application", 280, 10, "Medium", "Hot", durationRange: 8...10,
          note: "Use one heat application only. Confirm the current instructions for layering and the exact blank."),
        e("Siser", "Easy Puff Metallic: two presses", 280, 10, "Medium", "Hot", second: (280, 10, "Medium")),
        e("Siser", "Aurora", 305, 15, "Medium", "Completely cold"),
        e("Siser", "PureHT", 275, 15, "Medium", "Hot", compatibleMaterials: standardTextiles + [leather]),
        e("Siser", "Brick 600", 310, 20, "Medium", "Cold"),
        e("Siser", "Glitter", 320, 15, "Medium", "Warm", compatibleMaterials: standardTextiles + [leather]),
        e("Siser", "Holographic", 320, 20, "Firm", "Cold", compatibleMaterials: standardTextiles + [leather], durationRange: 15...20),
        e("Siser", "Metal", 305, 15, "Medium", "Cold"),
        e("Siser", "Sparkle", 305, 20, "Firm", "Hot or cold", compatibleMaterials: standardTextiles + [leather], durationRange: 15...20),
        e("Siser", "StripFlock Pro", 311, 15, "Medium", "Warm", compatibleMaterials: standardTextiles + [leather], durationRange: 10...15),
        e("Siser", "Twinkle", 305, 15, "Firm", "Warm", compatibleMaterials: standardTextiles + [leather]),
        e("Siser", "ColorPrint Easy", 300, 15, "Medium", "Warm"),
        e("Siser", "ColorPrint Extra PU", 305, 15, "Medium", "Hot or warm", compatibleMaterials: standardTextiles + [nylon, leather]),
        e("Siser", "ColorPrint PU: matte or gloss", 295, 20, "Medium", "Hot"),
        e("Siser", "DigiBrick", 311, 25, "Firm", "Cold"),
        e("Siser", "Hi-5 Print Matte", 250, 5, "Medium", "Hot"),
        e("Siser", "SparklePrint", 311, 15, "Firm", "Hot"),
        e("Siser", "S-Print: matte", 248, 15, "Medium", "Hot"),
        e("Siser", "Sublithin Soft", 265, 15, "Medium", "Hot or warm"),
        e("Siser", "ColorPrint Aurora", 305, 15, "Medium", "Hot or warm after 5–10 s"),
        e("Transfer Express", "Goof Proof: single colour · cotton or blend", 365, 6, "Firm", "Hot", durationRange: 4...6),
        e("Transfer Express", "Goof Proof: single colour · polyester", 325, 12, "Firm", "Hot", material: "100% polyester T-shirt", temperatureRange: 325...335, durationRange: 10...12),
        e("Transfer Express", "Goof Proof: multicolour", 365, 10, "Firm", "Hot"),
        e("Transfer Express", "Goof Proof Premium", 320, 10, "Firm", "Hot"),
        e("Transfer Express", "Hot Split Retro", 360, 10, "Firm", "Hot", temperatureRange: 360...370, durationRange: 8...10),
        e("Transfer Express", "Elasti Prints", 290, 15, "Firm", "Cold", material: polyester, compatibleMaterials: [polyester]),
        e("Transfer Express", "Glow-in-the-Dark", 340, 10, "Firm", "Warm after 3–5 s"),
        e("Transfer Express", "Puff", 340, 8, "Firm", "Hot", compatibleMaterials: [cotton, blend], prepress: 5),
        e("Transfer Express", "Reflective", 315, 15, "Firm", "Cold"),
        e("Transfer Express", "AquaTru", 305, 15, "Firm", "Hot", compatibleMaterials: standardTextiles + [triBlend, stretch, nylon]),
        e("Transfer Express", "Silicone", 290, 15, "Medium", "Cold", compatibleMaterials: [sublimatedPolyester, polyester, blend, stretch]),
        e("Transfer Express", "Goof Proof Watermark", 320, 10, "Firm", "Hot"),
        e("Transfer Express", "UltraColor MAX", 290, 15, "Medium", "Hot", compatibleMaterials: standardTextiles + [triBlend, stretch], durationRange: 12...15),
        e("Transfer Express", "UltraColor Pro: cotton or blend", 340, 10, "Firm", "Hot"),
        e("Transfer Express", "UltraColor Pro: polyester", 290, 15, "Firm", "Hot", material: polyester, compatibleMaterials: [polyester]),
        e("Transfer Express", "UltraColor Stretch: polyester or synthetic", 290, 15, "Medium", "Cold", material: polyester, compatibleMaterials: [polyester, stretch, nylon]),
        e("Transfer Express", "UltraColor Stretch: cotton or blend", 340, 15, "Medium", "Cold", compatibleMaterials: [cotton, blend]),
        e("Transfer Express", "UltraColor Stretch with Blocker: polyester or synthetic", 290, 15, "Medium", "Cold", material: polyester, compatibleMaterials: [polyester, sublimatedPolyester, stretch, nylon]),
        e("Transfer Express", "UltraColor Stretch with Blocker: cotton or blend", 340, 15, "Medium", "Cold", compatibleMaterials: [cotton, blend]),
        e("Transfer Express", "Goof Proof Numbers", 360, 5, "Medium", "Hot"),
        e("Transfer Express", "Elasti Prints Numbers", 290, 15, "Firm", "Cold"),
        e("Transfer Express", "Express Names: fast application", 360, 5, "Medium", "Hot"),
        e("Transfer Express", "Express Names: alternate low temperature", 340, 10, "Medium", "Warm"),
        e("Transfer Express", "Flag Packs", 360, 6, "Medium", "Hot")
    ]
}
