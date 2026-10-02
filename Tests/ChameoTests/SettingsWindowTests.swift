import AppKit
import XCTest
@testable import Chameo

@MainActor
final class SettingsWindowTests: XCTestCase {
    func testSettingsWindowKeepsItsHostingControllerAndCategoryAfterClosing() throws {
        let controller = SettingsWindowController(
            localizationController: LocalizationController(),
            updateController: UpdateController(isEnabled: false),
            localPhotos: LocalPhotoSettingsController()
        )
        let window = try XCTUnwrap(controller.window)
        let hostingController = try XCTUnwrap(window.contentViewController)
        controller.state.category = .photos
        window.close()
        controller.loadWindow()
        XCTAssertTrue(controller.window === window)
        XCTAssertTrue(window.contentViewController === hostingController)
        XCTAssertEqual(controller.state.category, .photos)
        controller.state.category = .reminders
        window.close()
        XCTAssertEqual(controller.state.category, .reminders)
    }

    func testSettingsWindowConstrainsContentAfterInstallingItsHostingController() throws {
        let controller = SettingsWindowController(
            localizationController: LocalizationController(),
            updateController: UpdateController(isEnabled: false),
            localPhotos: LocalPhotoSettingsController()
        )
        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.contentMinSize, NSSize(width: 480, height: 420))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertFalse(window.isReleasedWhenClosed)
        // Saved geometry can restore a different size; the initial size contract is explicit.
        XCTAssertEqual(SettingsWindowController.contentSize, NSSize(width: 500, height: 460))
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.width, 480)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.height, 420)
    }
}
