import Foundation
import XCTest
@testable import Chameo

final class ReminderTimeInputTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testTwelveHourClockDistinguishesMidnightNoonAndAfternoon() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4)))
        var input = ReminderTimeInput(date: date, calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(input.usesTwelveHourClock)
        XCTAssertEqual(input.hourText, "12")
        XCTAssertEqual(input.hour, 0)
        input.isPM = true
        XCTAssertEqual(input.hour, 12)
        input.hourText = "1"
        XCTAssertEqual(input.hour, 13)
        input.hourText = "0"
        XCTAssertNil(input.hour)
        input.selectHour(23)
        XCTAssertEqual(input.hourText, "11")
        XCTAssertTrue(input.isPM)
        XCTAssertEqual(input.hour, 23)
    }

    func testTwentyFourHourClockAllowsUnpaddedAndLocalizedDigits() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4)))
        var input = ReminderTimeInput(date: date, calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertFalse(input.usesTwelveHourClock)
        input.hourText = " 9 "
        input.minuteText = "5"
        XCTAssertEqual(input.hour, 9)
        XCTAssertEqual(input.minute, 5)
        input.hourText = "٢٣"
        input.minuteText = "５９"
        XCTAssertEqual(input.hour, 23)
        XCTAssertEqual(input.minute, 59)
    }

    func testInvalidNumbersAreRejectedWithoutClampingOrRewriting() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4)))
        var input = ReminderTimeInput(date: date, calendar: calendar, locale: Locale(identifier: "en_GB"))
        for value in ["", "24", "99", "-1", "1.5", "abc", "123", "9:"] {
            input.hourText = value
            XCTAssertNil(input.hour, value)
            XCTAssertEqual(input.hourText, value)
        }
        for value in ["", "60", "99", "-1", "1.5", "abc", "123"] {
            input.minuteText = value
            XCTAssertNil(input.minute, value)
            XCTAssertEqual(input.minuteText, value)
        }
    }
}
