import XCTest
@testable import Chameo

final class CaptureProgressTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testTrackingStartsWithFirstCaptureAndExcludesToday() throws {
        let progress = CaptureProgress.calculate(
            captureDates: [
                try date(2026, 6, 17, 8),
                try date(2026, 6, 18, 8),
                try date(2026, 6, 19, 8)
            ],
            now: try date(2026, 6, 19, 12),
            calendar: calendar
        )

        XCTAssertEqual(progress?.capturedDayCount, 2)
        XCTAssertEqual(progress?.elapsedDayCount, 2)
        XCTAssertEqual(progress?.missedDates, [])
    }

    func testProgressUsesMostRecentThirtyCompletedDays() throws {
        let progress = CaptureProgress.calculate(
            captureDates: [
                try date(2026, 5, 22),
                try date(2026, 6, 1),
                try date(2026, 6, 30)
            ],
            now: try date(2026, 7, 1, 12),
            calendar: calendar
        )

        XCTAssertEqual(progress?.elapsedDayCount, 30)
        XCTAssertEqual(progress?.capturedDayCount, 2)
        XCTAssertEqual(progress?.missedDates.count, 28)
        XCTAssertEqual(progress?.missedDates.first, try date(2026, 6, 2))
    }

    func testMultiplePhotosCountOnceAndMissingDayIsReported() throws {
        let progress = CaptureProgress.calculate(
            captureDates: [
                try date(2026, 6, 16, 8),
                try date(2026, 6, 16, 18),
                try date(2026, 6, 18, 8)
            ],
            now: try date(2026, 6, 19, 12),
            calendar: calendar
        )

        XCTAssertEqual(progress?.capturedDayCount, 2)
        XCTAssertEqual(progress?.elapsedDayCount, 3)
        XCTAssertEqual(progress?.missedDates, [try date(2026, 6, 17)])
    }

    func testNewAlbumHasNoCompletedTrackingDays() throws {
        XCTAssertNil(CaptureProgress.calculate(
            captureDates: [],
            now: try date(2026, 6, 19, 12),
            calendar: calendar
        ))

        let progress = CaptureProgress.calculate(
            captureDates: [try date(2026, 6, 19, 8)],
            now: try date(2026, 6, 19, 12),
            calendar: calendar
        )

        XCTAssertEqual(progress?.capturedDayCount, 0)
        XCTAssertEqual(progress?.elapsedDayCount, 0)
        XCTAssertEqual(progress?.missedDates, [])
    }

    func testProgressUsesTheProvidedLocalCalendar() throws {
        var bangkokCalendar = Calendar(identifier: .gregorian)
        bangkokCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Bangkok"))

        let progress = CaptureProgress.calculate(
            captureDates: [
                try date(2026, 6, 17, 18),
                try date(2026, 6, 18, 18)
            ],
            now: try date(2026, 6, 19, 5),
            calendar: bangkokCalendar
        )

        XCTAssertEqual(progress?.capturedDayCount, 1)
        XCTAssertEqual(progress?.elapsedDayCount, 1)
        XCTAssertEqual(progress?.missedDates, [])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
