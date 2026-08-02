import XCTest
@testable import ChameoCore

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

    func testHidesMissingDatesAndPreservesInputOrderForTies() throws {
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
            "newest"
        ])
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
