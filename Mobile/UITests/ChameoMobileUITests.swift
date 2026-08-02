import XCTest

final class ChameoMobileUITests: XCTestCase {
    @MainActor
    func testFreshLaunchShowsLocalizedOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-hasCompletedPermissionOnboarding", "NO",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Chameo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Next"].exists)
    }

    @MainActor
    func testCompletedLaunchUsesThreeTabNavigationAndOpensSettings() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-hasCompletedPermissionOnboarding", "YES",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["Show Face Guide"].exists)
    }

    @MainActor
    func testTraditionalChineseOnboardingLoadsLocalizedResources() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(zh-Hant)",
            "-AppleLocale", "zh_TW",
            "-hasCompletedPermissionOnboarding", "NO",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["歡迎使用 Chameo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["下一步"].exists)
    }
}
