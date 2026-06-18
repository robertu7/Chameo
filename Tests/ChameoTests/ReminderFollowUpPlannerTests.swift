import XCTest
@testable import Chameo

final class ReminderFollowUpPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDailyReminderSchedulesHourlyFollowUpsThroughEndOfDay() throws {
        let reminder = try date(2026, 6, 18, 9, 30)
        let now = try date(2026, 6, 18, 9, 0)

        let followUps = ReminderFollowUpPlanner.followUps(
            reminderDate: reminder,
            repeatMode: .daily,
            weekday: nil,
            now: now,
            completedAt: nil,
            limit: 20,
            calendar: calendar
        )

        XCTAssertEqual(followUps.first?.date, try date(2026, 6, 18, 10, 30))
        XCTAssertEqual(followUps[13].date, try date(2026, 6, 18, 23, 30))
        XCTAssertEqual(followUps[14].date, try date(2026, 6, 19, 10, 30))
    }

    func testCompletedDayIsSkipped() throws {
        let followUps = ReminderFollowUpPlanner.followUps(
            reminderDate: try date(2026, 6, 18, 18, 0),
            repeatMode: .daily,
            weekday: nil,
            now: try date(2026, 6, 18, 12, 0),
            completedAt: try date(2026, 6, 18, 11, 0),
            limit: 10,
            calendar: calendar
        )

        XCTAssertEqual(followUps.first?.date, try date(2026, 6, 19, 19, 0))
    }

    func testFollowUpsDoNotCrossMidnight() throws {
        let followUps = ReminderFollowUpPlanner.followUps(
            reminderDate: try date(2026, 6, 18, 23, 30),
            repeatMode: .none,
            weekday: nil,
            now: try date(2026, 6, 18, 12, 0),
            completedAt: nil,
            limit: 10,
            calendar: calendar
        )

        XCTAssertTrue(followUps.isEmpty)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
