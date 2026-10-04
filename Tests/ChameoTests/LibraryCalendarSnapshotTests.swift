import Photos
import XCTest
@testable import Chameo

@MainActor
final class LibraryCalendarSnapshotTests: XCTestCase {
    func testSnapshotReusedUntilAssetsOrCalendarChange() async throws {
        let early = Date(timeIntervalSince1970: 1_785_802_500) // 2026-08-04 01:35 UTC
        let later = early.addingTimeInterval(3600)
        let photos = [early, later].enumerated().map { index, date in
            ChameoAsset(asset: CalendarTestPhoto(id: String(index), date: date))
        }
        let store = LibraryStore(assetDeleter: { _ in }, assetLoader: { _ in photos })
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        await store.reload(albumName: "Test")
        let first = store.calendarSnapshot(calendar: utc)
        XCTAssertTrue(first === store.calendarSnapshot(calendar: utc))
        let day = utc.startOfDay(for: early)
        XCTAssertEqual(first.assetsByDay[day]?.map(\.id), ["1", "0"])
        XCTAssertEqual(first.history.status(for: early, today: later), .captured)
        var pacific = utc
        pacific.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let changed = store.calendarSnapshot(calendar: pacific)
        XCTAssertFalse(first === changed)
        XCTAssertEqual(changed.assetsByDay.keys.first, pacific.startOfDay(for: early))
        _ = await store.deleteFromLibrary(photos[0], albumName: "Test")
        let deleted = store.calendarSnapshot(calendar: pacific)
        XCTAssertFalse(changed === deleted)
        XCTAssertEqual(deleted.assetsByDay.values.first?.map(\.id), ["1"])
        await store.reload(albumName: "Test")
        let reloaded = store.calendarSnapshot(calendar: pacific)
        XCTAssertFalse(deleted === reloaded)
        XCTAssertEqual(reloaded.assetsByDay.values.first?.count, 2)
    }

    func testIndexedHistoryKeepsStatusSemanticsAcrossDSTAndAvailability() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let next = calendar.date(byAdding: .day, value: 1, to: date)!
        let index = DailyCaptureDayIndex(captureDates: [date, date.addingTimeInterval(3600)], calendar: calendar)
        XCTAssertEqual(index.capturedDays.count, 1)
        XCTAssertEqual(index.status(for: date, today: next), .captured)
        XCTAssertEqual(index.status(for: next, today: next), .pendingToday)
        XCTAssertEqual(index.status(for: date, today: next, isAvailable: false), .unknown)
        XCTAssertEqual(index.status(for: calendar.date(byAdding: .day, value: -1, to: date)!, today: next), .outsideTracking)
        XCTAssertEqual(index.status(for: calendar.date(byAdding: .day, value: 1, to: next)!, today: next), .future)
        XCTAssertEqual(index.status(for: next, today: calendar.date(byAdding: .day, value: 1, to: next)!), .missed)
    }
}

private final class CalendarTestPhoto: PHAsset, @unchecked Sendable {
    let identifier: String
    let date: Date
    init(id: String, date: Date) { identifier = id; self.date = date; super.init() }
    override var localIdentifier: String { identifier }
    override var creationDate: Date? { date }
}
