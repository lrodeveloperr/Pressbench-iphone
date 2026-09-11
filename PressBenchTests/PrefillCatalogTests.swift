import XCTest
@testable import PressBench

final class PrefillCatalogTests: XCTestCase {
    func testManufacturerSetupPresetsCarryCurrentOfficialProvenance() {
        XCTAssertEqual(PBSetupPresetCatalog.entries.count, 56)
        XCTAssertEqual(PBSetupPresetCatalog.sources, ["Siser", "Transfer Express"])
        XCTAssertGreaterThanOrEqual(PBSetupPresetCatalog.materials.count, 6)
        for preset in PBSetupPresetCatalog.entries {
            XCTAssertEqual(preset.sourceURL.scheme, "https")
            XCTAssertFalse(preset.sourceURL.host?.isEmpty ?? true)
            XCTAssertEqual(preset.sourceCheckedDate, "2026-09-11")
            XCTAssertFalse(preset.name.contains("®"), preset.name)
            XCTAssertFalse(preset.name.contains("™"), preset.name)
            XCTAssertFalse(preset.compatibleMaterials.isEmpty, preset.name)
        }
    }

    func testManufacturerSetupPresetsCanBeFilteredBySourceMaterialAndSearch() {
        let polyesterSiser = PBSetupPresetCatalog.filteredEntries(
            search: "",
            source: "Siser",
            material: "100% polyester T-shirt"
        )
        XCTAssertFalse(polyesterSiser.isEmpty)
        XCTAssertTrue(polyesterSiser.allSatisfy {
            $0.brand == "Siser" && $0.compatibleMaterials.contains("100% polyester T-shirt")
        })

        let searched = PBSetupPresetCatalog.filteredEntries(
            search: "cold",
            source: "Transfer Express",
            material: "Stretch fabric"
        )
        XCTAssertFalse(searched.isEmpty)
        XCTAssertTrue(searched.allSatisfy {
            $0.brand == "Transfer Express" && $0.peel.localizedCaseInsensitiveContains("cold")
        })
    }

    func testPresetMaterialFilterBecomesTheDraftMaterialWhenCompatible() throws {
        let easyWeed = try XCTUnwrap(PBSetupPresetCatalog.entries.first { $0.name == "EasyWeed" })
        XCTAssertEqual(easyWeed.material, "Cotton/polyester blend")
        XCTAssertTrue(easyWeed.compatibleMaterials.contains("100% polyester T-shirt"))
        XCTAssertEqual(
            PBSetupPresetCatalog.resolvedMaterial(
                for: easyWeed, selectedMaterial: "100% polyester T-shirt"
            ),
            "100% polyester T-shirt"
        )
        XCTAssertEqual(
            PBSetupPresetCatalog.resolvedMaterial(for: easyWeed, selectedMaterial: ""),
            easyWeed.material
        )
        XCTAssertEqual(
            PBSetupPresetCatalog.resolvedMaterial(for: easyWeed, selectedMaterial: "Unsupported blank"),
            easyWeed.material
        )
    }

    func testCatalogIsBroadBoundedAndDuplicateFree() {
        XCTAssertEqual(PBPrefillCatalog.choiceCount, 98)
        XCTAssertEqual(PBPrefillCatalog.groups.count, 7)
        XCTAssertFalse(PBPrefillCatalog.provenance.containsExternalManufacturerData)
        XCTAssertFalse(PBPrefillCatalog.provenance.source.isEmpty)
        XCTAssertFalse(PBPrefillCatalog.provenance.permittedUseBasis.isEmpty)
        XCTAssertEqual(PBPrefillCatalog.provenance.verifiedOn, "2026-08-31")

        for (name, choices) in PBPrefillCatalog.groups {
            XCTAssertGreaterThanOrEqual(choices.count, 5, name)
            XCTAssertLessThanOrEqual(choices.count, 20, name)
            XCTAssertEqual(Set(choices).count, choices.count, name)
            XCTAssertTrue(choices.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, name)
        }
    }

    func testCatalogContainsNoOperatingRecipeValuesOrCopiedBrandMarkers() throws {
        let nonDimensionalChoices = PBPrefillCatalog.groups
            .filter { $0.key != "platenSizes" }
            .flatMap { $0.value }
        let timedValue = try NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\s*(?:s|sec|secs|second|seconds)\b"#, options: [.caseInsensitive])

        for value in nonDimensionalChoices {
            XCTAssertFalse(value.contains("°"), value)
            XCTAssertNil(
                timedValue.firstMatch(
                    in: value,
                    options: [],
                    range: NSRange(value.startIndex..., in: value)
                ),
                value
            )
        }

        for value in PBPrefillCatalog.groups.values.flatMap({ $0 }) {
            XCTAssertFalse(value.contains("©"), value)
            XCTAssertFalse(value.contains("®"), value)
            XCTAssertFalse(value.contains("™"), value)
            XCTAssertFalse(value.localizedCaseInsensitiveContains("http"), value)
        }
    }

    func testRecentChoicesAreFirstWithoutAddingDuplicatesOrRecipes() {
        let choices = ["Cotton", "Polyester", "Canvas"]
        let recent = [" canvas ", "COTTON", "User-entered material", ""]

        XCTAssertEqual(
            PBPrefillCatalog.prioritized(choices, recent: recent),
            [" canvas ", "COTTON", "User-entered material", "Polyester"]
        )
    }

    func testEveryPresetGroupIsCompleteAndLocalizedInEveryLanguage() {
        let englishLocale = Locale(identifier: "en-US")
        for language in AppLanguage.allCases {
            let locale = Locale(identifier: language.localeIdentifier(deviceLocale: englishLocale))
            for group in PBPrefillCatalog.Group.allCases {
                let english = PBPrefillCatalog.localizedChoices(for: group, language: .en, locale: englishLocale)
                let localized = PBPrefillCatalog.localizedChoices(for: group, language: language, locale: locale)
                XCTAssertEqual(localized.count, english.count, "\(group.rawValue)/\(language.rawValue)")
                XCTAssertTrue(localized.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                XCTAssertEqual(Set(localized.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale) }).count,
                               localized.count, "\(group.rawValue)/\(language.rawValue)")
            }
        }

        let french = PBPrefillCatalog.customerVisibleChoices(
            for: .materials,
            recent: ["Valeur saisie par l’utilisateur"],
            language: .fr,
            locale: Locale(identifier: "fr-FR")
        )
        XCTAssertEqual(french.first, "Valeur saisie par l’utilisateur")
        XCTAssertEqual(french.count, PBPrefillCatalog.materials.count + 1)
        XCTAssertNotEqual(Array(french.dropFirst()), PBPrefillCatalog.materials)

        let migratedFrench = PBPrefillCatalog.customerVisibleChoices(
            for: .materials,
            recent: ["100% cotton T-shirt"],
            language: .fr,
            locale: Locale(identifier: "fr-FR")
        )
        XCTAssertEqual(migratedFrench.count, PBPrefillCatalog.materials.count)
        XCTAssertNotEqual(migratedFrench.first, "100% cotton T-shirt")
        XCTAssertFalse(migratedFrench.contains("100% cotton T-shirt"))

        XCTAssertNotEqual(
            PBPrefillCatalog.localizedValue(
                "Peel hot", for: .finishActions, language: .es, locale: Locale(identifier: "es-ES")
            ),
            "Peel hot"
        )

        let simplified = PBPrefillCatalog.localizedChoices(
            for: .materials, language: .zh, locale: Locale(identifier: "zh-CN")
        )
        let traditional = PBPrefillCatalog.localizedChoices(
            for: .materials, language: .zh, locale: Locale(identifier: "zh-TW")
        )
        XCTAssertNotEqual(simplified, traditional)
    }
}
