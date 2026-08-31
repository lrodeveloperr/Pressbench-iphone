import Foundation

private final class PBPrefillBundleMarker: NSObject {}

/// Original, brand-neutral operator choices bundled with the app.
///
/// The catalog contains no temperature, duration, numeric pressure, or
/// manufacturer recipe values. Those must come from the operator's current
/// instructions and remain explicit inputs.
enum PBPrefillCatalog {
    enum Group: String, CaseIterable {
        case platenSizes
        case materials
        case transferMedia
        case pressureDescriptions
        case instructionSources
        case placementActions
        case finishActions
    }

    struct Provenance: Equatable {
        let source: String
        let permittedUseBasis: String
        let verifiedOn: String
        let containsExternalManufacturerData: Bool
    }

    private struct LocalizationCatalog: Decodable {
        let schemaVersion: Int
        let languages: [String]
        let localeOverrideCodes: [String]
        let translationBasis: String
        let groups: [String: [String: [String]]]
    }

    /// Release-auditable legal boundary for the bundled catalog. The values
    /// are original editorial classifications, not an imported recipe dataset.
    static let provenance = Provenance(
        source: "GoodUse Studios original brand-neutral editorial compilation",
        permittedUseBasis: "Original work bundled with PressBench",
        verifiedOn: "2026-08-31",
        containsExternalManufacturerData: false
    )

    private static let localizationCatalog: LocalizationCatalog = {
        let bundle = Bundle(for: PBPrefillBundleMarker.self)
        guard let url = bundle.url(forResource: "PrefillLocalizations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(LocalizationCatalog.self, from: data),
              decoded.schemaVersion == 1 else {
            preconditionFailure("PressBench preset localization catalog is missing or invalid")
        }
        return decoded
    }()

    static func localizedChoices(for group: Group, language: AppLanguage, locale: Locale) -> [String] {
        let code = language.localizationCode(for: locale)
        guard let translations = localizationCatalog.groups[group.rawValue] else { return [] }
        return translations[code] ?? translations[language.rawValue] ?? translations["en"] ?? []
    }

    /// Converts a stored bundled value from any supported language (including
    /// legacy English wording) to the current display language. Custom
    /// operator-entered values are returned unchanged.
    static func localizedValue(_ value: String, for group: Group, language: AppLanguage, locale: Locale) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let translations = localizationCatalog.groups[group.rawValue] else { return value }
        let folded = normalized(trimmed)
        var matchedIndex: Int?
        for choices in translations.values {
            if let index = choices.firstIndex(where: { normalized($0) == folded }) {
                matchedIndex = index
                break
            }
        }
        if matchedIndex == nil { matchedIndex = legacyEnglishAliases[group]?[folded] }
        guard let index = matchedIndex else { return value }
        let target = localizedChoices(for: group, language: language, locale: locale)
        return target.indices.contains(index) ? target[index] : value
    }

    // English projections remain available for release audits and tests.
    static var platenSizes: [String] { english(.platenSizes) }
    static var materials: [String] { english(.materials) }
    static var transferMedia: [String] { english(.transferMedia) }
    static var pressureDescriptions: [String] { english(.pressureDescriptions) }
    static var instructionSources: [String] { english(.instructionSources) }
    static var placementActions: [String] { english(.placementActions) }
    static var finishActions: [String] { english(.finishActions) }

    static var groups: [String: [String]] {
        Dictionary(uniqueKeysWithValues: Group.allCases.map { ($0.rawValue, english($0)) })
    }

    static var choiceCount: Int { groups.values.reduce(0) { $0 + $1.count } }

    /// Keeps recent operator-owned selections first, followed by every bundled
    /// localized choice. Operating parameters are never inferred here.
    static func prioritized(_ choices: [String], recent: [String]) -> [String] {
        var seen = Set<String>()
        return (recent + choices).filter { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return seen.insert(trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted
        }
    }

    static func customerVisibleChoices(
        for group: Group,
        recent: [String],
        language: AppLanguage,
        locale: Locale
    ) -> [String] {
        let localizedRecent = recent.map { localizedValue($0, for: group, language: language, locale: locale) }
        return prioritized(localizedChoices(for: group, language: language, locale: locale), recent: localizedRecent)
    }

    private static func english(_ group: Group) -> [String] {
        localizationCatalog.groups[group.rawValue]?["en"] ?? []
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static let legacyEnglishAliases: [Group: [String: Int]] = [
        .platenSizes: [
            normalized("Cap platen"): 13, normalized("Mug press"): 14,
            normalized("Tumbler press"): 15, normalized("Plate press"): 16
        ],
        .placementActions: [
            normalized("Thread garment"): 13, normalized("Mirror artwork checked"): 14,
            normalized("Print side checked"): 15
        ],
        .finishActions: [
            normalized("Peel hot"): 0, normalized("Peel warm"): 1, normalized("Peel cold"): 2,
            normalized("Repress with protective sheet"): 4, normalized("Repress without carrier"): 5,
            normalized("Remove carrier slowly"): 6, normalized("Remove carrier quickly"): 7,
            normalized("Inspect edges"): 8, normalized("Inspect colour"): 9,
            normalized("Inspect alignment"): 10, normalized("Stretch test after cooling"): 11,
            normalized("Record first-piece result"): 15
        ]
    ]
}
