import XCTest
@testable import Chameo

final class DailyCaptureStatusTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    func testStatusDistinguishesCapturedPendingMissedAndUntrackedDays() throws {
        let captures = [
            try date(2026, 7, 10),
            try date(2026, 7, 12)
        ]
        let today = try date(2026, 7, 14)

        XCTAssertEqual(status(2026, 7, 9, captures: captures, today: today), .outsideTracking)
        XCTAssertEqual(status(2026, 7, 10, captures: captures, today: today), .captured)
        XCTAssertEqual(status(2026, 7, 11, captures: captures, today: today), .missed)
        XCTAssertEqual(status(2026, 7, 14, captures: captures, today: today), .pendingToday)
        XCTAssertEqual(status(2026, 7, 15, captures: captures, today: today), .future)
    }

    func testTodayIsCapturedWhenItHasAPhoto() throws {
        let today = try date(2026, 7, 14)

        XCTAssertEqual(
            status(2026, 7, 14, captures: [today], today: today),
            .captured
        )
    }

    func testNoCapturesLeavesPastOutsideTrackingAndTodayPending() throws {
        let today = try date(2026, 7, 14)

        XCTAssertEqual(status(2026, 7, 13, captures: [], today: today), .outsideTracking)
        XCTAssertEqual(status(2026, 7, 14, captures: [], today: today), .pendingToday)
    }

    func testUnavailableHistoryReturnsUnknown() throws {
        let date = try date(2026, 7, 14)

        XCTAssertEqual(
            DailyCaptureHistory.status(
                for: date,
                captureDates: [],
                today: date,
                calendar: calendar,
                isAvailable: false
            ),
            .unknown
        )
    }

    func testCalendarDatesAlwaysProducesSixCompleteWeeks() throws {
        let dates = DailyCaptureHistory.calendarDates(
            inMonthContaining: try date(2026, 7, 18),
            calendar: calendar
        )

        XCTAssertEqual(dates.count, 42)
        XCTAssertEqual(dates.first, try date(2026, 6, 29))
        XCTAssertEqual(dates.last, try date(2026, 8, 9))
    }

    private func status(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        captures: [Date],
        today: Date
    ) -> DailyCaptureStatus {
        DailyCaptureHistory.status(
            for: try! date(year, month, day),
            captureDates: captures,
            today: today,
            calendar: calendar
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )))
    }
}
