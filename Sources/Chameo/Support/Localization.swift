import Combine
import Foundation

@MainActor
final class LocalizationController: ObservableObject {
    @Published private(set) var preference: AppLanguage
    @Published private(set) var effectiveLocalization: AppLocalization

    private let defaults: UserDefaults
    private var localeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedPreference = AppLanguage(
            rawValue: defaults.string(forKey: AppPreferenceKey.language) ?? ""
        ) ?? .automatic
        preference = storedPreference
        effectiveLocalization = AppLocalization.resolve(preference: storedPreference)

        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAutomaticLanguage()
            }
        }
    }

    deinit {
        if let localeObserver {
            NotificationCenter.default.removeObserver(localeObserver)
        }
    }

    var displayLocale: Locale {
        effectiveLocalization.displayLocale
    }

    func select(_ preference: AppLanguage) {
        guard self.preference != preference else { return }
        defaults.set(preference.rawValue, forKey: AppPreferenceKey.language)
        self.preference = preference
        effectiveLocalization = AppLocalization.resolve(preference: preference)
        NotificationCenter.default.post(name: .chameoLanguageDidChange, object: nil)
    }

    func refreshAutomaticLanguage() {
        guard preference == .automatic else { return }
        let resolved = AppLocalization.resolve(preference: .automatic)
        guard resolved != effectiveLocalization else {
            objectWillChange.send()
            return
        }
        effectiveLocalization = resolved
        NotificationCenter.default.post(name: .chameoLanguageDidChange, object: nil)
    }
}

enum L10n {
    static func string(
        _ key: String,
        localization: AppLocalization = currentLocalization
    ) -> String {
        localizedBundle(for: localization).localizedString(
            forKey: key,
            value: englishFallback(for: key),
            table: "Localizable"
        )
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...,
        localization: AppLocalization = currentLocalization
    ) -> String {
        String(
            format: string(key, localization: localization),
            locale: localization.displayLocale,
            arguments: arguments
        )
    }

    static var currentLocalization: AppLocalization {
        let preference = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: AppPreferenceKey.language) ?? ""
        ) ?? .automatic
        return AppLocalization.resolve(preference: preference)
    }

    private static func englishFallback(for key: String) -> String {
        localizedBundle(for: .english).localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    private static func localizedBundle(for localization: AppLocalization) -> Bundle {
        if let bundle = localizedBundle(
            in: Bundle.main,
            localization: localization
        ) {
            return bundle
        }
        if let bundle = localizedBundle(
            in: Bundle.module,
            localization: localization
        ) {
            return bundle
        }
        return Bundle.main
    }

    private static func localizedBundle(
        in container: Bundle,
        localization: AppLocalization
    ) -> Bundle? {
        for resourceName in localization.resourceNames {
            let rootPath = container.path(
                forResource: resourceName,
                ofType: "lproj"
            )
            let nestedPath = container.path(
                forResource: resourceName,
                ofType: "lproj",
                inDirectory: "Localization"
            )
            if let path = rootPath ?? nestedPath, let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }
}

private extension AppLocalization {
    var resourceNames: [String] {
        switch self {
        case .english:
            return ["en"]
        case .simplifiedChinese:
            return ["zh-Hans", "zh-hans"]
        case .traditionalChinese:
            return ["zh-Hant", "zh-hant"]
        }
    }
}

extension Notification.Name {
    static let chameoLanguageDidChange = Notification.Name("ChameoLanguageDidChange")
}
