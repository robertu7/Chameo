import XCTest
@testable import Chameo

final class TimelapseSelectionTests: XCTestCase {
    private struct Item: Equatable {
        let id: String
        let date: Date?
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testSelectsLatestItemPerDayInChronologicalOrder() throws {
        let items = [
            Item(id: "older-second-day", date: try date(2026, 6, 18, 8)),
            Item(id: "latest-first-day", date: try date(2026, 6, 17, 18)),
            Item(id: "latest-second-day", date: try date(2026, 6, 18, 20)),
            Item(id: "older-first-day", date: try date(2026, 6, 17, 7))
        ]

        let selected = TimelapseSelection.mostRecentDailyItems(
            from: items,
            limit: 30,
            calendar: calendar,
            date: \.date
        )

        XCTAssertEqual(selected.map(\.id), ["latest-first-day", "latest-second-day"])
    }

    func testKeepsOnlyMostRecentDaysAndSkipsMissingDates() throws {
        let items = [
            Item(id: "oldest", date: try date(2026, 6, 16, 8)),
            Item(id: "middle", date: try date(2026, 6, 17, 8)),
            Item(id: "newest", date: try date(2026, 6, 18, 8)),
            Item(id: "missing", date: nil)
        ]

        let selected = TimelapseSelection.mostRecentDailyItems(
            from: items,
            limit: 2,
            calendar: calendar,
            date: \.date
        )

        XCTAssertEqual(selected.map(\.id), ["middle", "newest"])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
