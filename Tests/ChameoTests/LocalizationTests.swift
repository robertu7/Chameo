import Foundation
import XCTest
@testable import Chameo

final class LocalizationResolutionTests: XCTestCase {
    func testExplicitLanguagePreferencesResolveDirectly() {
        XCTAssertEqual(
            AppLocalization.resolve(preference: .english, preferredLanguages: ["zh-Hant-TW"]),
            .english
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .simplifiedChinese, preferredLanguages: ["en"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .traditionalChinese, preferredLanguages: ["en"]),
            .traditionalChinese
        )
    }

    func testAutomaticLanguageMapsChineseScriptsAndFallsBackToEnglish() {
        XCTAssertEqual(
            AppLocalization.resolve(
                preference: .automatic,
                preferredLanguages: ["en-US", "zh-Hant-US", "th-US", "zh-Hans-US"]
            ),
            .english
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .automatic, preferredLanguages: ["zh-Hans-CN"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .automatic, preferredLanguages: ["zh-SG"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .automatic, preferredLanguages: ["zh-Hant-HK"]),
            .traditionalChinese
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .automatic, preferredLanguages: ["zh-MO"]),
            .traditionalChinese
        )
        XCTAssertEqual(
            AppLocalization.resolve(preference: .automatic, preferredLanguages: ["th-TH", "fr-FR"]),
            .english
        )
    }

    func testLocalizedResourcesLoadForEverySupportedLanguage() {
        XCTAssertEqual(
            L10n.string("Settings", localization: .english),
            "Settings"
        )
        XCTAssertEqual(
            L10n.string("Settings", localization: .simplifiedChinese),
            "设置"
        )
        XCTAssertEqual(
            L10n.string("Settings", localization: .traditionalChinese),
            "設定"
        )
    }

    func testFormattingUsesTheSelectedLanguageAndPreservesTheSystemRegion() {
        let localization = AppLocalization.traditionalChinese
        XCTAssertEqual(localization.displayLocale.language.languageCode?.identifier(.alpha2), "zh")
        XCTAssertEqual(localization.displayLocale.language.script?.identifier, "Hant")
        XCTAssertEqual(localization.displayLocale.region, Locale.autoupdatingCurrent.region)
        XCTAssertEqual(localization.displayLocale.hourCycle, Locale.autoupdatingCurrent.hourCycle)
    }

    func testReminderNotificationTextUsesRequestedLanguage() {
        let simplified = ReminderService.reminderNotificationText(
            localization: .simplifiedChinese
        )
        let traditional = ReminderService.reminderNotificationText(
            localization: .traditionalChinese
        )

        XCTAssertEqual(simplified.title, "该拍 Chameo 了")
        XCTAssertEqual(traditional.title, "該拍 Chameo 了")
        XCTAssertNotEqual(simplified.body, traditional.body)
    }
}

@MainActor
final class LocalizationControllerTests: XCTestCase {
    func testSelectionPersistsAndPublishesTheEffectiveLanguage() {
        let suiteName = "LocalizationControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let controller = LocalizationController(defaults: defaults)
        controller.select(.traditionalChinese)

        XCTAssertEqual(controller.preference, .traditionalChinese)
        XCTAssertEqual(controller.effectiveLocalization, .traditionalChinese)
        XCTAssertEqual(
            defaults.string(forKey: AppPreferenceKey.language),
            AppLanguage.traditionalChinese.rawValue
        )
    }
}

final class LocalizationCatalogTests: XCTestCase {
    private let localizableCatalogs = [
        "en.lproj/Localizable.strings",
        "zh-Hans.lproj/Localizable.strings",
        "zh-Hant.lproj/Localizable.strings",
    ]
    private let infoPlistCatalogs = [
        "en.lproj/InfoPlist.strings",
        "zh-Hans.lproj/InfoPlist.strings",
        "zh-Hant.lproj/InfoPlist.strings",
    ]

    func testLocalizableCatalogsHaveIdenticalKeysAndPlaceholders() throws {
        let catalogs = try localizableCatalogs.map(loadCatalog)
        let englishKeys = Set(catalogs[0].keys)

        for catalog in catalogs.dropFirst() {
            XCTAssertEqual(Set(catalog.keys), englishKeys)
            for key in englishKeys {
                XCTAssertEqual(
                    placeholderSignature(catalog[key] ?? ""),
                    placeholderSignature(catalogs[0][key] ?? ""),
                    "Placeholder mismatch for \(key)"
                )
            }
        }
    }

    func testInfoPlistCatalogsHaveIdenticalRequiredKeys() throws {
        let expectedKeys: Set<String> = [
            "NSCameraUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSLocationUsageDescription",
            "NSLocationWhenInUseUsageDescription",
            "NSUserNotificationUsageDescription",
        ]

        for path in infoPlistCatalogs {
            XCTAssertEqual(Set(try loadCatalog(path).keys), expectedKeys)
        }
    }

    func testSourceLocalizationKeysExistInEnglishCatalog() throws {
        let englishKeys = Set(try loadCatalog(localizableCatalogs[0]).keys)
        let sourceRoot = repositoryRoot.appendingPathComponent("Sources/Chameo")
        let sourceURLs = try FileManager.default.subpathsOfDirectory(
            atPath: sourceRoot.path
        )
        .filter { $0.hasSuffix(".swift") }
        .map(sourceRoot.appendingPathComponent)
        let expression = try NSRegularExpression(
            pattern: #"(?:L10n\.(?:string|format)|\.(?:localized|formatted))\(\s*"([^"]+)""#
        )
        var referencedKeys = Set<String>()

        for url in sourceURLs {
            let source = try String(contentsOf: url)
            let range = NSRange(source.startIndex..., in: source)
            for match in expression.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else {
                    continue
                }
                referencedKeys.insert(String(source[keyRange]))
            }
        }

        for error in [
            FaceAlignmentError.invalidImage,
            .noFace,
            .missingLandmarks,
            .processingFailed,
        ] {
            referencedKeys.insert(error.localizationKey)
        }

        XCTAssertTrue(
            referencedKeys.isSubset(of: englishKeys),
            "Missing English localization keys: \(referencedKeys.subtracting(englishKeys).sorted())"
        )
    }

    func testUserFacingSwiftUICopyUsesTheLocalizer() throws {
        let sourceRoot = repositoryRoot.appendingPathComponent("Sources/Chameo")
        let sourceURLs = try FileManager.default.subpathsOfDirectory(
            atPath: sourceRoot.path
        )
        .filter { $0.hasSuffix(".swift") }
        .map(sourceRoot.appendingPathComponent)
        let expression = try NSRegularExpression(
            pattern: #"(?:Text|Button|Label|Section|Picker|Toggle|ProgressView|TextField|LabeledContent)\(\s*"([^"]+)""#
        )
        var violations: [String] = []

        for url in sourceURLs {
            let source = try String(contentsOf: url)
            let range = NSRange(source.startIndex..., in: source)
            for match in expression.matches(in: source, range: range) {
                guard let valueRange = Range(match.range(at: 1), in: source) else {
                    continue
                }
                let value = String(source[valueRange])
                if !value.hasPrefix(#"\("#) {
                    violations.append("\(url.lastPathComponent): \(value)")
                }
            }
        }

        XCTAssertEqual(violations, [])
    }

    private func loadCatalog(_ relativePath: String) throws -> [String: String] {
        let url = repositoryRoot
            .appendingPathComponent("Sources/Chameo/Resources/Localization")
            .appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        )
        return try XCTUnwrap(propertyList as? [String: String])
    }

    private func placeholderSignature(_ value: String) -> [String] {
        let pattern = "%(?:lld|@)"
        let expression = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
