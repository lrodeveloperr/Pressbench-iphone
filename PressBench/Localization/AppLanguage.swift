import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case en, es, pt, fr, de, it, nl, pl, tr, ro, cs, uk, ru, ar, zh, ja, ko, hi, ur, bn, vi, id, th, fil, ms, fi, sv, da, nb, el, he

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .en: "English"
        case .es: "Español"
        case .pt: "Português"
        case .fr: "Français"
        case .de: "Deutsch"
        case .it: "Italiano"
        case .nl: "Nederlands"
        case .pl: "Polski"
        case .tr: "Türkçe"
        case .ro: "Română"
        case .cs: "Čeština"
        case .uk: "Українська"
        case .ru: "Русский"
        case .ar: "العربية"
        case .zh: "中文"
        case .ja: "日本語"
        case .ko: "한국어"
        case .hi: "हिन्दी"
        case .ur: "اردو"
        case .bn: "বাংলা"
        case .vi: "Tiếng Việt"
        case .id: "Bahasa Indonesia"
        case .th: "ไทย"
        case .fil: "Filipino"
        case .ms: "Bahasa Melayu"
        case .fi: "Suomi"
        case .sv: "Svenska"
        case .da: "Dansk"
        case .nb: "Norsk bokmål"
        case .el: "Ελληνικά"
        case .he: "עברית"
        }
    }

    /// Resolve the selected language against the device region/script so the
    /// 31 language choices retain PressBench's locale-specific behaviour.
    func localeIdentifier(deviceLocale: Locale = .current) -> String {
        let region = deviceLocale.region?.identifier.uppercased() ?? ""
        let script = deviceLocale.language.script?.identifier.lowercased() ?? ""
        switch self {
        case .en: return region == "CA" ? "en-CA" : region == "GB" ? "en-GB" : "en-US"
        case .es: return region == "ES" ? "es-ES" : "es-MX"
        case .pt: return region == "BR" ? "pt-BR" : "pt-PT"
        case .fr: return region == "CA" ? "fr-CA" : "fr-FR"
        case .zh:
            return script == "hant" || ["TW", "HK", "MO"].contains(region) ? "zh-Hant" : "zh-Hans"
        case .de: return "de-DE"
        case .it: return "it-IT"
        case .nl: return "nl-NL"
        case .pl: return "pl-PL"
        case .tr: return "tr-TR"
        case .ro: return "ro-RO"
        case .cs: return "cs-CZ"
        case .uk: return "uk-UA"
        case .ru: return "ru-RU"
        case .ar: return "ar-SA"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        case .hi: return "hi-IN"
        case .ur: return "ur-PK"
        case .bn: return "bn-BD"
        case .vi: return "vi-VN"
        case .id: return "id-ID"
        case .th: return "th-TH"
        case .fil: return "fil-PH"
        case .ms: return "ms-MY"
        case .fi: return "fi-FI"
        case .sv: return "sv-SE"
        case .da: return "da-DK"
        case .nb: return "nb-NO"
        case .el: return "el-GR"
        case .he: return "he-IL"
        }
    }

    func localizationCode(for locale: Locale) -> String {
        if self == .zh && locale.identifier.lowercased().contains("hant") { return "zh-Hant" }
        return rawValue
    }

    var isRTL: Bool { self == .ar || self == .he || self == .ur }

    static func detected(from locale: Locale = .current) -> AppLanguage {
        let code = locale.language.languageCode?.identifier.lowercased() ?? "en"
        let aliases: [String: String] = ["iw": "he", "in": "id", "no": "nb", "tl": "fil"]
        return AppLanguage(rawValue: aliases[code] ?? code) ?? .en
    }
}

enum AppLanguageStorage {
    static let key = "pressbench.language"

    static func resolved(rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? AppLanguage.detected()
    }
}
