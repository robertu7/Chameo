import XCTest
@testable import Chameo

final class AppDistributionTests: XCTestCase {
    func testReleaseConfigurationReadsEnabledCapabilities() {
        let configuration = AppDistributionConfiguration(infoDictionary: [
            "CFBundleIdentifier": "com.robertu.Chameo",
            "ChameoBuildVariant": "release",
            "ChameoDefaultAlbumName": "Chameo",
            "ChameoUpdatesEnabled": true,
            "ChameoLaunchAtLoginEnabled": true
        ])

        XCTAssertEqual(configuration.bundleIdentifier, "com.robertu.Chameo")
        XCTAssertEqual(configuration.buildVariant, .release)
        XCTAssertFalse(configuration.isTestBuild)
        XCTAssertEqual(configuration.defaultAlbumName, "Chameo")
        XCTAssertTrue(configuration.updatesEnabled)
        XCTAssertTrue(configuration.launchAtLoginEnabled)
    }

    func testTestConfigurationUsesSeparateIdentityAndDisablesReleaseCapabilities() {
        let configuration = AppDistributionConfiguration(infoDictionary: [
            "CFBundleIdentifier": "com.robertu.Chameo.test",
            "ChameoBuildVariant": "test",
            "ChameoDefaultAlbumName": "Chameo (test)",
            "ChameoUpdatesEnabled": false,
            "ChameoLaunchAtLoginEnabled": false
        ])

        XCTAssertEqual(configuration.bundleIdentifier, "com.robertu.Chameo.test")
        XCTAssertEqual(configuration.buildVariant, .test)
        XCTAssertTrue(configuration.isTestBuild)
        XCTAssertEqual(configuration.defaultAlbumName, "Chameo (test)")
        XCTAssertFalse(configuration.updatesEnabled)
        XCTAssertFalse(configuration.launchAtLoginEnabled)
    }

    func testMissingDistributionKeysUseSafeLocalDefaults() {
        let configuration = AppDistributionConfiguration(infoDictionary: [:])

        XCTAssertEqual(configuration.bundleIdentifier, "com.robertu.Chameo")
        XCTAssertEqual(configuration.buildVariant, .test)
        XCTAssertTrue(configuration.isTestBuild)
        XCTAssertEqual(configuration.defaultAlbumName, "Chameo")
        XCTAssertFalse(configuration.updatesEnabled)
        XCTAssertFalse(configuration.launchAtLoginEnabled)
    }
}
