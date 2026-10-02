import XCTest
@testable import Chameo

@MainActor
final class MainCameraLifecycleTests: XCTestCase {
    func testCameraVisibilityBelongsOnlyToTheActiveHostingSurface() {
        let state = AppState()
        state.visibleMainSurface = .popover
        XCTAssertTrue(state.isCameraVisible(on: .popover))
        XCTAssertFalse(state.isCameraVisible(on: .standalone))
        state.visibleMainSurface = .standalone
        XCTAssertFalse(state.isCameraVisible(on: .popover))
        XCTAssertTrue(state.isCameraVisible(on: .standalone))
        state.selectedTab = .library
        XCTAssertFalse(state.isCameraVisible(on: .standalone))
        state.prepareForSettings()
        state.selectedTab = .camera
        XCTAssertFalse(state.isCameraVisible(on: .popover))
        XCTAssertFalse(state.isCameraVisible(on: .standalone))
    }

    func testCameraRequiresAVisibleMainSurfaceAndCameraTab() {
        let state = AppState()
        var events: [Bool] = []
        let lifecycle = MainCameraLifecycle(appState: state,
            start: { events.append(true) }, stop: { events.append(false) })
        withExtendedLifetime(lifecycle) {
            XCTAssertEqual(events, [false])
            state.visibleMainSurface = .popover
            XCTAssertTrue(state.shouldRunCamera)
            state.selectedTab = .library
            state.selectedTab = .camera
            state.prepareForSettings()
            state.selectedTab = .library
            state.selectedTab = .camera
            XCTAssertFalse(state.shouldRunCamera)
            XCTAssertEqual(events, [false, true, false, true, false])
        }
    }

    func testLatePopoverDismissalCannotStopTheStandaloneCamera() {
        let state = AppState()
        var events: [Bool] = []
        let lifecycle = MainCameraLifecycle(appState: state,
            start: { events.append(true) }, stop: { events.append(false) })
        withExtendedLifetime(lifecycle) {
            state.visibleMainSurface = .popover
            state.visibleMainSurface = .standalone
            state.dismiss(.popover)
            XCTAssertEqual(state.visibleMainSurface, .standalone)
            XCTAssertEqual(events, [false, true])
            state.dismiss(.standalone)
            XCTAssertEqual(events, [false, true, false])
        }
    }

    func testOpeningSettingsPreservesTheLibrarySelectionOnReturn() {
        let state = AppState()
        let selectedDay = Date(timeIntervalSince1970: 1_700_000_000)
        state.selectedTab = .library
        state.selectedLibraryDay = selectedDay
        state.visibleMainSurface = .popover
        state.prepareForSettings()
        state.prepareForMenuBarOpen(status: .pendingToday)
        XCTAssertEqual(state.selectedTab, .library)
        XCTAssertEqual(state.selectedLibraryDay, selectedDay)
        XCTAssertNil(state.visibleMainSurface)
        // The usual daily shortcut resumes after returning from Settings once.
        state.prepareForMenuBarOpen(status: .pendingToday)
        XCTAssertEqual(state.selectedTab, .camera)
    }

    func testNormalMenuBarOpenSelectsTodaysLibraryWhenCaptured() {
        let state = AppState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        state.prepareForMenuBarOpen(status: .captured, now: now)
        XCTAssertEqual(state.selectedTab, .library)
        XCTAssertEqual(state.selectedLibraryDay, Calendar.current.startOfDay(for: now))
    }
}
