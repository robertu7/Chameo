import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case english
    case simplifiedChinese
    case traditionalChinese

    public var id: String { rawValue }
}

public enum AppLocalization: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    public static func resolve(
        preference: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLocalization {
        switch preference {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .traditionalChinese:
            return .traditionalChinese
        case .automatic:
            break
        }

        for identifier in preferredLanguages {
            let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
            if normalized == "en" || normalized.hasPrefix("en-") {
                return .english
            }
            guard normalized == "zh" || normalized.hasPrefix("zh-") else {
                continue
            }
            if normalized.contains("hans")
                || normalized.hasPrefix("zh-cn")
                || normalized.hasPrefix("zh-sg") {
                return .simplifiedChinese
            }
            return .traditionalChinese
        }
        return .english
    }

    public var displayLocale: Locale {
        var components = Locale.Components(locale: .autoupdatingCurrent)
        switch self {
        case .english:
            components.languageComponents.languageCode = Locale.LanguageCode("en")
            components.languageComponents.script = nil
        case .simplifiedChinese:
            components.languageComponents.languageCode = Locale.LanguageCode("zh")
            components.languageComponents.script = Locale.Script("Hans")
        case .traditionalChinese:
            components.languageComponents.languageCode = Locale.LanguageCode("zh")
            components.languageComponents.script = Locale.Script("Hant")
        }
        return Locale(components: components)
    }
}
