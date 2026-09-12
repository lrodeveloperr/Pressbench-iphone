import XCTest
@testable import PressBench

final class LanguageSupportTests: XCTestCase {
    func testLanguageContractContains31CanonicalLanguages() {
        XCTAssertEqual(AppLanguage.allCases.count, 31)
        XCTAssertEqual(Set(AppLanguage.allCases.map(\.rawValue)).count, 31)
    }

    func testRTLLanguagesMatchDomainContract() {
        XCTAssertEqual(Set(AppLanguage.allCases.filter(\.isRTL).map(\.rawValue)), Set(["ar", "he", "ur"]))
    }

    func testEveryLanguageHasLocaleAndNativeName() {
        for language in AppLanguage.allCases {
            XCTAssertFalse(language.localeIdentifier().isEmpty)
            XCTAssertFalse(language.nativeName.isEmpty)
        }
    }

    func testRegionalLocaleResolutionMatchesPressBenchContract() {
        XCTAssertEqual(AppLanguage.en.localeIdentifier(deviceLocale: Locale(identifier: "en_CA")), "en-CA")
        XCTAssertEqual(AppLanguage.en.localeIdentifier(deviceLocale: Locale(identifier: "en_GB")), "en-GB")
        XCTAssertEqual(AppLanguage.es.localeIdentifier(deviceLocale: Locale(identifier: "es_ES")), "es-ES")
        XCTAssertEqual(AppLanguage.pt.localeIdentifier(deviceLocale: Locale(identifier: "pt_BR")), "pt-BR")
        XCTAssertEqual(AppLanguage.fr.localeIdentifier(deviceLocale: Locale(identifier: "fr_CA")), "fr-CA")
        XCTAssertEqual(AppLanguage.zh.localeIdentifier(deviceLocale: Locale(identifier: "zh_Hant_TW")), "zh-Hant")
        XCTAssertEqual(AppLanguage.zh.localeIdentifier(deviceLocale: Locale(identifier: "zh_Hans_CN")), "zh-Hans")
    }

    func testLocalizationCatalogIsCompleteForEveryLanguage() {
        XCTAssertEqual(PBL10n.catalog.strings.count, 368)
        let requiredCodes = Set(AppLanguage.allCases.map(\.rawValue) + ["zh-Hant"])
        for (key, entry) in PBL10n.catalog.strings {
            XCTAssertEqual(Set(entry.translations.keys), requiredCodes, "Missing locale in \(key)")
            for code in requiredCodes {
                XCTAssertFalse(entry.translations[code, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               "Empty translation for \(key) / \(code)")
            }
        }
    }

    func testHumanReportCatalogIsComplete() {
        for key in PBReportLocalization.humanReportKeys {
            XCTAssertNotNil(PBL10n.catalog.strings[key], "Missing report key: \(key)")
        }
    }
}
