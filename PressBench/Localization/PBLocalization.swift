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

    /// Localizes bundled operational values that can already be present in
    /// on-device setups. Operator-entered text and proper names are preserved.
    static func operationalText(_ value: String, language: AppLanguage, locale: Locale) -> String {
        let code = language.localizationCode(for: locale)
        return rtlOperationalTranslations[code]?[value] ?? value
    }

    private static let rtlOperationalTranslations: [String: [String: String]] = [
        "ar": [
            "N/A": "غير متاح",
            "EasyWeed": "إيزي ويد",
            "EasyWeed EcoStretch": "إيزي ويد إيكو ستريتش",
            "Confirm the current instructions for the exact blank before production.":
                "تأكّد من تعليمات الاستخدام الحالية للخامة المحددة قبل بدء الإنتاج.",
            "Remove moisture and wrinkles before placement.":
                "أزل الرطوبة والتجاعيد قبل وضع الخامة.",
            "Use one heat application only. Confirm the current instructions for layering and the exact blank.":
                "استخدم تطبيقًا حراريًا واحدًا فقط. تأكّد من التعليمات الحالية للطبقات والخامة المحددة.",
            "Wait 24 hours before the first wash and follow the current product care instructions.":
                "انتظر 24 ساعة قبل الغسلة الأولى واتبع تعليمات العناية الحالية بالمنتج."
        ],
        "he": [
            "N/A": "לא זמין",
            "EasyWeed": "איזי ויד",
            "EasyWeed EcoStretch": "איזי ויד אקו סטרץ׳",
            "Confirm the current instructions for the exact blank before production.":
                "יש לאמת את הוראות השימוש העדכניות עבור חומר הגלם המדויק לפני הייצור.",
            "Remove moisture and wrinkles before placement.":
                "יש להסיר לחות וקמטים לפני ההנחה.",
            "Use one heat application only. Confirm the current instructions for layering and the exact blank.":
                "יש לבצע חימום אחד בלבד. יש לאמת את ההוראות העדכניות לשכבות ולחומר הגלם המדויק.",
            "Wait 24 hours before the first wash and follow the current product care instructions.":
                "יש להמתין 24 שעות לפני הכביסה הראשונה ולפעול לפי הוראות הטיפול העדכניות של המוצר."
        ],
        "ur": [
            "N/A": "دستیاب نہیں",
            "EasyWeed": "ایزی ویڈ",
            "EasyWeed EcoStretch": "ایزی ویڈ ایکو اسٹریچ",
            "Confirm the current instructions for the exact blank before production.":
                "پیداوار سے پہلے متعلقہ خام شے کے لیے تازہ ترین ہدایات کی تصدیق کریں۔",
            "Remove moisture and wrinkles before placement.":
                "جگہ پر رکھنے سے پہلے نمی اور سلوٹیں دور کریں۔",
            "Use one heat application only. Confirm the current instructions for layering and the exact blank.":
                "صرف ایک بار حرارت لگائیں۔ تہہ بندی اور مخصوص خام مٹیریل کے لیے موجودہ ہدایات کی تصدیق کریں۔",
            "Wait 24 hours before the first wash and follow the current product care instructions.":
                "پہلی دھلائی سے پہلے 24 گھنٹے انتظار کریں اور مصنوعات کی موجودہ نگہداشت کی ہدایات پر عمل کریں۔"
        ]
    ]
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

    static func decimal(_ value: Double, locale: Locale, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Uses the international SI symbol rather than an English unit word.
    static func seconds(_ value: Int, locale: Locale) -> String {
        "\(integer(value, locale: locale)) s"
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
        let canonical = stageType.isEmpty ? name : stageType
        switch canonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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
        switch phase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "preflight": return "stage.placement"
        case "first_piece": return "onboarding.process.firstPiece"
        case "result_pending", "committing": return "onboarding.process.result"
        case "completed": return "runState.completed"
        default: break
        }
        let canonical = currentStageType.isEmpty ? stage : currentStageType
        switch canonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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

extension SetupStageDraft {
    var canonicalLocalizationKey: String? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedType = stageType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canonicalEnglishNames: [String: Set<String>] = [
            "placement": ["placement"],
            "prepress": ["pre-press", "prepress"],
            "press": ["press"],
            "peel": ["peel"],
            "cool": ["cool"],
            "postpress": ["post-press", "postpress"]
        ]
        guard normalizedName.isEmpty || canonicalEnglishNames[normalizedType]?.contains(normalizedName) == true else {
            return nil
        }
        switch normalizedType {
        case "placement": return "stage.placement"
        case "prepress": return "stage.prepress"
        case "press": return "stage.press"
        case "peel": return "stage.peel"
        case "cool": return "stage.cool"
        case "postpress": return "stage.postpress"
        default: return nil
        }
    }
}
