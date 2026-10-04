import Foundation
import XCTest
@testable import Chameo

final class ReminderDateTimeDraftTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    func testEveryTimeChoiceKeepsTheSelectedDayAndRemovesSeconds() throws {
        let original = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 10, day: 4, hour: 9, minute: 15, second: 42)))
        var draft = ReminderDateTimeDraft(date: original, calendar: calendar)
        for hour in 0..<24 {
            for minute in 0..<60 {
                draft.hour = hour
                draft.minute = minute
                let date = try XCTUnwrap(draft.resolvedDate(calendar: calendar))
                XCTAssertTrue(calendar.isDate(date, inSameDayAs: original))
                XCTAssertEqual(calendar.component(.hour, from: date), hour)
                XCTAssertEqual(calendar.component(.minute, from: date), minute)
                XCTAssertEqual(calendar.component(.second, from: date), 0)
            }
        }
    }

    func testChangingDatePreservesTimeAcrossMonthAndYearBoundaries() throws {
        let original = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2027, month: 12, day: 31, hour: 23, minute: 59)))
        var draft = ReminderDateTimeDraft(date: original, calendar: calendar)
        draft.day = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2028, month: 2, day: 29)))
        let date = try XCTUnwrap(draft.resolvedDate(calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            DateComponents(year: 2028, month: 2, day: 29, hour: 23, minute: 59))
    }

    func testUnavailableDaylightSavingTimeIsRejectedInsteadOfSilentlyChanged() throws {
        let day = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 3, day: 8)))
        var draft = ReminderDateTimeDraft(date: day, calendar: calendar)
        draft.hour = 2
        draft.minute = 30
        XCTAssertNil(draft.resolvedDate(calendar: calendar))
        draft.hour = 3
        let date = try XCTUnwrap(draft.resolvedDate(calendar: calendar))
        XCTAssertEqual(calendar.component(.hour, from: date), 3)
        XCTAssertEqual(calendar.component(.minute, from: date), 30)
        XCTAssertTrue(calendar.isDate(date, inSameDayAs: day))
    }

    func testRepeatedDaylightSavingHourRemainsOnSelectedDate() throws {
        let day = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 11, day: 1)))
        var draft = ReminderDateTimeDraft(date: day, calendar: calendar)
        draft.hour = 1
        draft.minute = 30
        let date = try XCTUnwrap(draft.resolvedDate(calendar: calendar))
        XCTAssertTrue(calendar.isDate(date, inSameDayAs: day))
        XCTAssertEqual(calendar.component(.hour, from: date), 1)
        XCTAssertEqual(calendar.component(.minute, from: date), 30)
    }

    func testOneTimeReminderRejectsPastAndCurrentTimesBeforeCommit() throws {
        let now = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 10, day: 4, hour: 9, minute: 30)))
        var draft = ReminderDateTimeDraft(date: now, calendar: calendar)
        XCTAssertEqual(draft.validationError(after: now, repeatMode: .none, weekday: nil, calendar: calendar), .pastDate)
        draft.minute = 29
        XCTAssertEqual(draft.validationError(after: now, repeatMode: .none, weekday: nil, calendar: calendar), .pastDate)
        draft.minute = 31
        XCTAssertNil(draft.validationError(after: now, repeatMode: .none, weekday: nil, calendar: calendar))
    }

    func testRecurringPreviewUsesNextOccurrenceInsteadOfOldStoredDate() throws {
        let stored = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2025, month: 10, day: 4, hour: 9, minute: 30)))
        let now = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 10, day: 4, hour: 10)))
        let draft = ReminderDateTimeDraft(date: stored, calendar: calendar)
        let daily = try XCTUnwrap(draft.nextDate(after: now, repeatMode: .daily, weekday: nil, calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: daily),
            DateComponents(year: 2026, month: 10, day: 5, hour: 9, minute: 30))
        let weekly = try XCTUnwrap(draft.nextDate(after: now, repeatMode: .weekly, weekday: 2, calendar: calendar))
        XCTAssertEqual(weekly, daily) // The next Monday is October 5.
        XCTAssertNil(draft.validationError(after: now, repeatMode: .weekly, weekday: 2, calendar: calendar))
    }

    func testRecurringTimeCanBeEditedEvenWhenStoredDayHasDaylightSavingGap() throws {
        let now = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 3, day: 8, hour: 3, minute: 30)))
        var draft = ReminderDateTimeDraft(date: now, calendar: calendar)
        draft.hour = 2
        XCTAssertNil(draft.resolvedDate(calendar: calendar))
        XCTAssertEqual(draft.validationError(after: now, repeatMode: .none, weekday: nil, calendar: calendar), .unavailableTime)
        XCTAssertNil(draft.validationError(after: now, repeatMode: .daily, weekday: nil, calendar: calendar))
        let next = try XCTUnwrap(draft.nextDate(after: now, repeatMode: .daily, weekday: nil, calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next),
            DateComponents(year: 2026, month: 3, day: 9, hour: 2, minute: 30))
    }

    func testIncompleteAndInvalidTextIsPreservedUntilCorrected() throws {
        let day = try XCTUnwrap(calendar.date(from:
            DateComponents(year: 2026, month: 10, day: 5, hour: 9)))
        var draft = ReminderDateTimeDraft(date: day, calendar: calendar, locale: Locale(identifier: "en_GB"))
        draft.time.hourText = "99"
        draft.time.minuteText = ""
        XCTAssertEqual(draft.validationError(after: day, repeatMode: .daily, weekday: nil, calendar: calendar), .invalidTime)
        XCTAssertEqual(draft.time.hourText, "99")
        XCTAssertEqual(draft.time.minuteText, "")
        draft.time.hourText = "9"
        draft.time.minuteText = "5"
        XCTAssertNil(draft.validationError(after: day, repeatMode: .daily, weekday: nil, calendar: calendar))
        XCTAssertEqual(draft.time.hourText, "9")
        XCTAssertEqual(draft.time.minuteText, "5")
        XCTAssertEqual(draft.minute, 5)
    }
}
