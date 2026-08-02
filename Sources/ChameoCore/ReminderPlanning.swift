import Foundation

public enum ReminderRepeat: String, CaseIterable, Identifiable, Sendable {
    case none
    case daily
    case weekly

    public static var allCases: [ReminderRepeat] { [.daily, .weekly, .none] }
    public var id: String { rawValue }
}

public struct ReminderSchedule: Sendable {
    public let date: Date
    public let repeatMode: ReminderRepeat
    public let weekday: Int?

    public init(date: Date, repeatMode: ReminderRepeat, weekday: Int?) {
        self.date = date
        self.repeatMode = repeatMode
        self.weekday = weekday
    }

    public func nextDate(
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

public struct PlannedReminderNotification: Equatable, Sendable {
    public let identifier: String
    public let date: Date

    public init(identifier: String, date: Date) {
        self.identifier = identifier
        self.date = date
    }
}

public enum ReminderNotificationIdentifier {
    public static let request = "com.robertu.Chameo.chameoReminder"
    public static let primaryPrefix = "\(request).primary."
}

public enum ReminderNotificationPlanner {
    public static func notifications(
        reminderDate: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date,
        completedAt: Date?,
        limit: Int,
        calendar: Calendar = .current
    ) -> [PlannedReminderNotification] {
        guard limit > 0 else { return [] }
        let schedule = ReminderSchedule(
            date: reminderDate,
            repeatMode: repeatMode,
            weekday: weekday
        )
        var result: [PlannedReminderNotification] = []
        var cursor = now
        while result.count < limit {
            guard let occurrence = schedule.nextDate(after: cursor, calendar: calendar) else {
                break
            }
            let isCompleted = completedAt.map {
                calendar.isDate($0, inSameDayAs: occurrence)
            } ?? false
            if !isCompleted {
                result.append(notification(for: occurrence, calendar: calendar))
            }
            guard repeatMode != .none else { break }
            cursor = occurrence
        }
        return result
    }

    private static func notification(
        for date: Date,
        calendar: Calendar
    ) -> PlannedReminderNotification {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let identifier = ReminderNotificationIdentifier.primaryPrefix
            + String(
                format: "%04d%02d%02d-%02d%02d",
                components.year ?? 0,
                components.month ?? 0,
                components.day ?? 0,
                components.hour ?? 0,
                components.minute ?? 0
            )
        return PlannedReminderNotification(identifier: identifier, date: date)
    }
}
