import XCTest
@preconcurrency import UserNotifications
@testable import Chameo

final class TimelapseNotificationTests: XCTestCase {
    func testBodyAndOpenFolderRouteToExportWhileDismissAndReminderDoNot() {
        let id = UUID()
        let payload: [AnyHashable: Any] = [TimelapseNotificationPolicy.exportIDKey: id.uuidString]
        for action in [UNNotificationDefaultActionIdentifier, TimelapseNotificationPolicy.openFolderAction] {
            XCTAssertEqual(TimelapseNotificationPolicy.exportID(
                identifier: TimelapseNotificationPolicy.requestIdentifier, action: action, userInfo: payload), id)
        }
        XCTAssertNil(TimelapseNotificationPolicy.exportID(
            identifier: TimelapseNotificationPolicy.requestIdentifier,
            action: UNNotificationDismissActionIdentifier, userInfo: payload))
        XCTAssertNil(TimelapseNotificationPolicy.exportID(
            identifier: ReminderService.requestIdentifier,
            action: UNNotificationDefaultActionIdentifier, userInfo: payload))
        XCTAssertNil(TimelapseNotificationPolicy.exportID(
            identifier: TimelapseNotificationPolicy.requestIdentifier,
            action: UNNotificationDefaultActionIdentifier, userInfo: [:]))
        XCTAssertNil(ReminderNotificationResponsePolicy.destination(
            identifier: TimelapseNotificationPolicy.requestIdentifier,
            actionIdentifier: UNNotificationDefaultActionIdentifier, isCompletedToday: false))
    }

    func testAuthorizationPolicy() {
        XCTAssertFalse(TimelapseNotificationPolicy.canDeliver(.notDetermined))
        XCTAssertFalse(TimelapseNotificationPolicy.canDeliver(.denied))
        XCTAssertTrue(TimelapseNotificationPolicy.canDeliver(.authorized))
        XCTAssertTrue(TimelapseNotificationPolicy.canDeliver(.provisional))
    }

    @MainActor
    func testColdLaunchActionWaitsForHandler() {
        let request = DeferredTimelapseOpenRequest()
        let id = UUID()
        var opened: [UUID] = []
        request.performOrDefer(id)
        XCTAssertTrue(opened.isEmpty)
        request.installHandler { opened.append($0) }
        XCTAssertEqual(opened, [id])
        request.performOrDefer(id)
        XCTAssertEqual(opened, [id, id])
    }

    @MainActor
    func testMissingFileAndUnknownExportCannotOpen() {
        let defaults = UserDefaults(suiteName: "timelapse-result-" + UUID().uuidString)!
        let store = TimelapseResultStore(defaults: defaults)
        let id = UUID()
        store.save(id: id, url: URL(fileURLWithPath: "/private/tmp/absent-" + UUID().uuidString))
        XCTAssertThrowsError(try store.withURL(id: id) { _ in XCTFail("Missing file was opened") })
        XCTAssertThrowsError(try store.withURL(id: UUID()) { _ in XCTFail("Unknown export was opened") })
        let restored = TimelapseResultStore(defaults: defaults)
        XCTAssertEqual(restored.latest?.id, id)
    }
}

extension TimelapseNotificationTests {
    @MainActor
    func testCompletedFileBookmarkSurvivesStoreRelaunch() throws {
        let suite = "timelapse-bookmark-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("video".utf8).write(to: url)
        let result = TimelapseResultStore(defaults: defaults).save(id: UUID(), url: url)
        XCTAssertNotNil(result.bookmark)
        let restored = TimelapseResultStore(defaults: defaults)
        var opened: URL?
        try restored.withURL(id: result.id) { opened = $0 }
        XCTAssertEqual(opened?.standardizedFileURL, url.standardizedFileURL)
    }
}
