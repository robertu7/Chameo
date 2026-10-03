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
        XCTAssertEqual(window.contentMinSize, ChameoLayout.utilityWindowSize)
        XCTAssertEqual(window.contentMaxSize, ChameoLayout.utilityWindowSize)
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertFalse(window.standardWindowButton(.zoomButton)?.isEnabled ?? true)
        XCTAssertFalse(window.isReleasedWhenClosed)
        // Fixed geometry must also override saved frames from older resizable builds.
        XCTAssertEqual(SettingsWindowController.contentSize, NSSize(width: 500, height: 460))
        XCTAssertEqual(window.contentLayoutRect.size, ChameoLayout.utilityWindowSize)
        XCTAssertEqual(TimelapseWindowController.contentSize, SettingsWindowController.contentSize)
    }
}
