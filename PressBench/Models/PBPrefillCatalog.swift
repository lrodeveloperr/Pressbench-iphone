import Foundation

/// Original, brand-neutral operator choices bundled with the app.
///
/// This catalog deliberately contains no temperature, duration, numeric
/// pressure, or manufacturer recipe values. Those must come from the
/// operator's current instructions and remain explicit inputs.
enum PBPrefillCatalog {
    struct Provenance: Equatable {
        let source: String
        let permittedUseBasis: String
        let verifiedOn: String
        let containsExternalManufacturerData: Bool
    }

    /// Release-auditable legal boundary for the bundled catalog. The values
    /// below are original editorial classifications, not an imported dataset.
    static let provenance = Provenance(
        source: "GoodUse Studios original brand-neutral editorial compilation",
        permittedUseBasis: "Original work bundled with PressBench",
        verifiedOn: "2026-08-29",
        containsExternalManufacturerData: false
    )

    static let platenSizes = [
        "6 × 8 in", "9 × 12 in", "11 × 15 in", "12 × 15 in", "15 × 15 in", "15 × 18 in",
        "16 × 20 in", "20 × 25 in", "25 × 31 in", "30 × 40 in", "38 × 38 cm", "40 × 50 cm",
        "50 × 60 cm", "Cap platen", "Mug press", "Tumbler press", "Plate press", "Interchangeable platen"
    ]

    static let materials = [
        "100% cotton T-shirt", "100% polyester T-shirt", "Cotton/polyester blend", "Tri-blend garment",
        "Performance polyester", "Polyester-coated fabric", "Hoodie or sweatshirt", "Canvas tote",
        "Cotton tote", "Cap or hat", "Polyester flag", "Mouse pad", "Ceramic mug", "Coated tumbler",
        "Coated aluminium panel", "Coated hardboard", "Slate blank", "Glass blank", "Wood blank",
        "Synthetic leather"
    ]

    static let transferMedia = [
        "Heat transfer vinyl (HTV)", "Stretch HTV", "Glitter HTV", "Flock HTV", "Puff HTV",
        "Reflective HTV", "Printable HTV", "Direct-to-film transfer (DTF)", "Screen-printed transfer",
        "Sublimation transfer", "Inkjet transfer paper", "Laser transfer paper", "White-toner transfer",
        "Rhinestone transfer", "Embroidered patch", "Woven patch", "Adhesive patch", "Foil transfer"
    ]

    static let pressureDescriptions = [
        "Very light", "Light", "Medium", "Firm", "Very firm"
    ]

    static let instructionSources = [
        "Manufacturer instructions", "Supplier instructions", "Technical data sheet",
        "Verified test result", "Prior successful batch"
    ]

    static let placementActions = [
        "Centre on platen", "Align to collar", "Align to seam", "Use alignment ruler", "Use placement jig",
        "Use pressing pillow", "Use heat-resistant pad", "Use foam pad", "Use lower-platen cover",
        "Use protective sheet", "Secure with heat tape", "Pre-shape garment", "Thread garment",
        "Avoid seams and zippers", "Mirror artwork checked", "Print side checked"
    ]

    static let finishActions = [
        "Peel hot", "Peel warm", "Peel cold", "Allow to cool flat", "Repress with protective sheet",
        "Repress without carrier", "Remove carrier slowly", "Remove carrier quickly", "Inspect edges",
        "Inspect colour", "Inspect alignment", "Stretch test after cooling", "Stack only after cooling",
        "Hang after cooling", "Move to cooling rack", "Record first-piece result"
    ]

    static let groups: [String: [String]] = [
        "platenSizes": platenSizes,
        "materials": materials,
        "transferMedia": transferMedia,
        "pressureDescriptions": pressureDescriptions,
        "instructionSources": instructionSources,
        "placementActions": placementActions,
        "finishActions": finishActions
    ]

    static var choiceCount: Int { groups.values.reduce(0) { $0 + $1.count } }

    /// Keeps the operator's recent selections at the top while retaining every
    /// bundled choice and any manually entered value. No operating parameters
    /// are inferred or introduced here.
    static func prioritized(_ choices: [String], recent: [String]) -> [String] {
        var seen = Set<String>()
        return (recent + choices).filter { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return seen.insert(trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted
        }
    }

    /// Bundled catalog labels are currently authored and reviewed in English.
    /// Until a locale has reviewed display translations, show only values the
    /// operator already owns rather than leaking hard-coded English into UI.
    static func customerVisibleChoices(
        _ bundled: [String],
        recent: [String],
        language: AppLanguage
    ) -> [String] {
        prioritized(language == .en ? bundled : [], recent: recent)
    }
}
