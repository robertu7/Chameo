import Foundation

/// Keeps edits separate from the saved schedule until the user finishes the picker.
struct ReminderDateTimeDraft {
    var day: Date
    var time: ReminderTimeInput

    init(date: Date, calendar: Calendar = .current, locale: Locale = .current) {
        day = date
        time = ReminderTimeInput(date: date, calendar: calendar, locale: locale)
    }

    var hour: Int {
        get { time.hour ?? -1 }
        set { time.selectHour(newValue) }
    }

    var minute: Int {
        get { time.minute ?? -1 }
        set { time.minuteText = String(format: "%02d", newValue) }
    }

    func resolvedDate(calendar: Calendar = .current) -> Date? {
        guard let hour = time.hour, let minute = time.minute else { return nil }
        var components = calendar.dateComponents([.era, .year, .month, .day, .isLeapMonth], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let date = calendar.date(from: components),
              calendar.isDate(date, inSameDayAs: day),
              calendar.component(.hour, from: date) == hour,
              calendar.component(.minute, from: date) == minute else {
            // A daylight-saving transition can make an otherwise valid time unavailable.
            return nil
        }
        return date
    }

    func scheduleDate(repeatMode: ReminderRepeat, calendar: Calendar = .current) -> Date? {
        if let date = resolvedDate(calendar: calendar) { return date }
        guard repeatMode != .none, time.hour != nil, time.minute != nil else { return nil }
        // Recurring times must remain selectable even when the stored day has a DST gap.
        var anchor = self
        anchor.day = Date(timeIntervalSinceReferenceDate: 0)
        return anchor.resolvedDate(calendar: calendar)
    }

    func nextDate(after now: Date, repeatMode: ReminderRepeat, weekday: Int?, calendar: Calendar = .current) -> Date? {
        guard let date = scheduleDate(repeatMode: repeatMode, calendar: calendar) else { return nil }
        return ReminderSchedule(date: date, repeatMode: repeatMode, weekday: weekday)
            .nextDate(after: now, calendar: calendar)
    }

    func validationError(after now: Date, repeatMode: ReminderRepeat, weekday: Int?, calendar: Calendar = .current) -> ValidationError? {
        guard time.hour != nil, time.minute != nil else { return .invalidTime }
        guard scheduleDate(repeatMode: repeatMode, calendar: calendar) != nil else { return .unavailableTime }
        guard nextDate(after: now, repeatMode: repeatMode, weekday: weekday, calendar: calendar) != nil else { return .pastDate }
        return nil
    }

    enum ValidationError {
        case invalidTime, unavailableTime, pastDate
    }
}
