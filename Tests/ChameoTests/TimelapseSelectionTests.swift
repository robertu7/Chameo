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

    func testIncludesEveryDatedItemInChronologicalOrder() throws {
        let items = [
            Item(id: "older-second-day", date: try date(2026, 6, 18, 8)),
            Item(id: "latest-first-day", date: try date(2026, 6, 17, 18)),
            Item(id: "latest-second-day", date: try date(2026, 6, 18, 20)),
            Item(id: "older-first-day", date: try date(2026, 6, 17, 7))
        ]

        let selected = TimelapseSelection.allItemsChronologically(
            from: items,
            date: \.date
        )

        XCTAssertEqual(selected.map(\.id), [
            "older-first-day",
            "latest-first-day",
            "older-second-day",
            "latest-second-day"
        ])
    }

    func testIncludesMissingDatesAndPreservesInputOrderForTies() throws {
        let sharedDate = try date(2026, 6, 17, 8)
        let items = [
            Item(id: "newest", date: try date(2026, 6, 18, 8)),
            Item(id: "first-at-shared-date", date: sharedDate),
            Item(id: "first-missing", date: nil),
            Item(id: "second-at-shared-date", date: sharedDate),
            Item(id: "oldest", date: try date(2026, 6, 16, 8)),
            Item(id: "second-missing", date: nil)
        ]

        let selected = TimelapseSelection.allItemsChronologically(
            from: items,
            date: \.date
        )

        XCTAssertEqual(selected.map(\.id), [
            "oldest",
            "first-at-shared-date",
            "second-at-shared-date",
            "newest",
            "first-missing",
            "second-missing"
        ])
    }

    func testMonthAndYearUseCalendarBoundariesAndExcludeUndatedPhotos() throws {
        let items = [
            Item(id: "undated", date: nil),
            Item(id: "previous-year", date: try date(2025, 12, 31, 23)),
            Item(id: "year-start", date: try date(2026, 1, 1, 0)),
            Item(id: "month-start", date: try date(2026, 9, 1, 0)),
            Item(id: "month-end", date: try date(2026, 9, 30, 23)),
            Item(id: "next-month", date: try date(2026, 10, 1, 0)),
            Item(id: "next-year", date: try date(2027, 1, 1, 0))
        ]
        var options = TimelapseExportOptions(date: try date(2026, 9, 15, 12))
        options.range = .month
        XCTAssertEqual(TimelapseSelection.items(from: items, options: options, calendar: calendar, date: \.date).map(\.id),
                       ["month-start", "month-end"])
        options.range = .year
        XCTAssertEqual(TimelapseSelection.items(from: items, options: options, calendar: calendar, date: \.date).map(\.id),
                       ["year-start", "month-start", "month-end", "next-month"])
        options.range = .allPhotos
        XCTAssertEqual(TimelapseSelection.items(from: items, options: options, calendar: calendar, date: \.date).last?.id,
                       "undated", "All Photos must still retain undated assets")
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
