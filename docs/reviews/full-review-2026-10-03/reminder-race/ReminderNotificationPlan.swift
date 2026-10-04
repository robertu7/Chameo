import Foundation

struct PlannedReminderNotification: Equatable {
    let identifier: String
    let date: Date
}

enum ReminderNotificationIdentifier {
    static let request = "com.robertu.Chameo.chameoReminder"
    static let primaryPrefix = "\(request).primary."
}

enum ReminderNotificationPlanner {
    static func notifications(
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

            guard repeatMode != .none else {
                break
            }
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
