import AppKit
import SwiftUI
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

    func testCategoryPagesMountLazilyAndRetainLocalStateWhenRevisited() async throws {
        let state = SettingsState()
        var identities: [SettingsCategory: [UUID]] = [:]
        let view = SettingsPagesProbe(state: state) { category, id in
            identities[category, default: []].append(id)
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 460),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSHostingView(rootView: view)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(Set(identities.keys), [.general], "Unvisited forms must not start permission or preference work")
        for category in [SettingsCategory.photos, .capture, .photos, .general] {
            state.category = category
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(identities[.general]?.count, 1)
        XCTAssertEqual(identities[.photos]?.count, 1, "Revisiting a category must retain its local SwiftUI state")
        XCTAssertEqual(identities[.capture]?.count, 1)
        XCTAssertNil(identities[.reminders])
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
        XCTAssertEqual(TimelapseWindowController.contentSize.width, SettingsWindowController.contentSize.width)
        XCTAssertEqual(TimelapseWindowController.contentSize.height, 480)
    }
}

@MainActor
private struct SettingsPagesProbe: View {
    @ObservedObject var state: SettingsState
    let onAppear: (SettingsCategory, UUID) -> Void

    var body: some View {
        RetainedSettingsPages(selection: $state.category) { category in
            SettingsPageIdentityProbe { onAppear(category, $0) }
        }
    }
}

@MainActor
private struct SettingsPageIdentityProbe: View {
    @State private var identity = UUID()
    let onAppear: (UUID) -> Void

    var body: some View {
        Color.clear.onAppear { onAppear(identity) }
    }
}
