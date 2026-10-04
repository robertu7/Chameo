import Foundation

struct ReminderSchedule {
    let date: Date
    let repeatMode: ReminderRepeat
    let weekday: Int?

    func nextDate(
        after referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch repeatMode {
        case .none:
            return date > referenceDate ? date : nil
        case .daily:
            return calendar.nextDate(
                after: referenceDate,
                matching: timeComponents(calendar: calendar),
                matchingPolicy: .nextTime,
                direction: .forward
            )
        case .weekly:
            var components = timeComponents(calendar: calendar)
            components.weekday = validWeekday(in: calendar)
            return calendar.nextDate(
                after: referenceDate,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            )
        }
    }

    private func timeComponents(calendar: Calendar) -> DateComponents {
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        return components
    }

    private func validWeekday(in calendar: Calendar) -> Int {
        guard let weekday, calendar.weekdaySymbols.indices.contains(weekday - 1) else {
            return calendar.component(.weekday, from: date)
        }
        return weekday
    }
}
