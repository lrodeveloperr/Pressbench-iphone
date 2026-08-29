import XCTest
@testable import PressBench

final class PrefillCatalogTests: XCTestCase {
    func testCatalogIsBroadBoundedAndDuplicateFree() {
        XCTAssertEqual(PBPrefillCatalog.choiceCount, 98)
        XCTAssertEqual(PBPrefillCatalog.groups.count, 7)
        XCTAssertFalse(PBPrefillCatalog.provenance.containsExternalManufacturerData)
        XCTAssertFalse(PBPrefillCatalog.provenance.source.isEmpty)
        XCTAssertFalse(PBPrefillCatalog.provenance.permittedUseBasis.isEmpty)
        XCTAssertEqual(PBPrefillCatalog.provenance.verifiedOn, "2026-08-29")

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

    func testUntranslatedBundledEnglishIsNotExposedInOtherLanguages() {
        XCTAssertEqual(
            PBPrefillCatalog.customerVisibleChoices(
                PBPrefillCatalog.materials,
                recent: ["Valeur saisie par l’utilisateur"],
                language: .fr
            ),
            ["Valeur saisie par l’utilisateur"]
        )
        XCTAssertEqual(
            PBPrefillCatalog.customerVisibleChoices(
                ["Bundled English"],
                recent: ["Recent value"],
                language: .en
            ),
            ["Recent value", "Bundled English"]
        )
    }
}
