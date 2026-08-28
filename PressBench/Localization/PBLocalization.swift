import Foundation
import SwiftUI

private final class PBLocalizationBundleMarker: NSObject {}

struct PBLocalizationEntry: Decodable {
    let context: String
    let source: String
    let translations: [String: String]
}

struct PBLocalizationCatalog: Decodable {
    let schemaVersion: Int
    let languages: [String]
    let localeOverrideCodes: [String]
    let strings: [String: PBLocalizationEntry]
}

enum PBL10n {
    static let catalog: PBLocalizationCatalog = {
        let bundle = Bundle(for: PBLocalizationBundleMarker.self)
        guard let url = bundle.url(forResource: "Localizations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PBLocalizationCatalog.self, from: data) else {
            preconditionFailure("PressBench localization catalog is missing or invalid")
        }
        return decoded
    }()

    static func text(_ key: String, language: AppLanguage, locale: Locale) -> String {
        guard let entry = catalog.strings[key] else { return key }
        let code = language.localizationCode(for: locale)
        return entry.translations[code] ?? entry.translations[language.rawValue] ?? entry.translations["en"] ?? entry.source
    }

    static func format(_ key: String, language: AppLanguage, locale: Locale, _ arguments: CVarArg...) -> String {
        let format = text(key, language: language, locale: locale)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func hasTranslation(_ key: String, code: String) -> Bool {
        guard let value = catalog.strings[key]?.translations[code] else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct PBAppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.detected()
}

extension EnvironmentValues {
    var pbLanguage: AppLanguage {
        get { self[PBAppLanguageEnvironmentKey.self] }
        set { self[PBAppLanguageEnvironmentKey.self] = newValue }
    }
}

enum PBFormat {
    static func integer(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    static func percent(_ value: Double, locale: Locale, fractionDigits: Int = 1) -> String {
        value.formatted(.percent.precision(.fractionLength(fractionDigits)).locale(locale))
    }

    static func date(_ value: Date, locale: Locale, time: Bool = false) -> String {
        if time {
            return value.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
        }
        return value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    static func clock(seconds: TimeInterval, locale: Locale) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let secs = total % 60
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 2
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        let minuteText = formatter.string(from: NSNumber(value: minutes)) ?? String(format: "%02d", minutes)
        let secondText = formatter.string(from: NSNumber(value: secs)) ?? String(format: "%02d", secs)
        return "\(minuteText):\(secondText)"
    }
}

extension ProcessStage {
    var canonicalLocalizationKey: String? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "placement": return "stage.placement"
        case "pre-press", "prepress": return "stage.prepress"
        case "press": return "stage.press"
        case "peel": return "stage.peel"
        case "cool": return "stage.cool"
        case "post-press", "postpress": return "stage.postpress"
        default: return nil
        }
    }
}

extension BatchRun {
    var canonicalStageLocalizationKey: String? {
        switch stage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "placement": return "stage.placement"
        case "pre-press", "prepress": return "stage.prepress"
        case "press": return "stage.press"
        case "peel": return "stage.peel"
        case "cool": return "stage.cool"
        case "post-press", "postpress": return "stage.postpress"
        default: return nil
        }
    }
}
