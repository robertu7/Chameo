import Foundation
import UserNotifications

enum ReminderService {
    static let requestIdentifier = "com.robertu.Chameo.chameoReminder"
    static let followUpIdentifierPrefix = "\(requestIdentifier).followUp."
    private static let maximumFollowUpRequests = 60

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func hasScheduledReminder() async -> Bool {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .contains { $0.identifier == requestIdentifier }
    }

    static func configureReminder(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int? = nil,
        hourlyFollowUpsEnabled: Bool
    ) async throws {
        let center = UNUserNotificationCenter.current()
        await removeAllReminderRequests(from: center)

        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else {
            throw ReminderError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "Take your Chameo"
        content.body = "Capture today's photo for your timeline."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(for: date, repeatMode: repeatMode, weekday: weekday),
            repeats: repeatMode != .none
        )
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        try await center.add(request)

        if hourlyFollowUpsEnabled {
            try await scheduleFollowUps(
                date: date,
                repeatMode: repeatMode,
                weekday: weekday,
                center: center
            )
        }
    }

    static func cancelReminder() async {
        await removeAllReminderRequests(from: UNUserNotificationCenter.current())
    }

    static func recordSelfieTaken(at date: Date = Date()) async {
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: "lastSelfieDate")

        guard UserDefaults.standard.bool(forKey: "reminderEnabled"),
              UserDefaults.standard.bool(forKey: "hourlyReminderFollowUpsEnabled") else {
            return
        }

        let storedDate = UserDefaults.standard.double(forKey: "reminderDate")
        let reminderDate = Date(timeIntervalSinceReferenceDate: storedDate)
        let repeatMode = ReminderRepeat(
            rawValue: UserDefaults.standard.string(forKey: "reminderRepeat") ?? ""
        ) ?? .none
        let weekday = UserDefaults.standard.integer(forKey: "reminderWeekday")

        try? await refreshFollowUps(
            date: reminderDate,
            repeatMode: repeatMode,
            weekday: weekday,
            now: date
        )
    }

    static func refreshFollowUpsFromStoredSettings(now: Date = Date()) async {
        guard UserDefaults.standard.bool(forKey: "reminderEnabled"),
              UserDefaults.standard.bool(forKey: "hourlyReminderFollowUpsEnabled") else {
            return
        }

        let reminderDate = Date(
            timeIntervalSinceReferenceDate: UserDefaults.standard.double(forKey: "reminderDate")
        )
        let repeatMode = ReminderRepeat(
            rawValue: UserDefaults.standard.string(forKey: "reminderRepeat") ?? ""
        ) ?? .none

        try? await refreshFollowUps(
            date: reminderDate,
            repeatMode: repeatMode,
            weekday: UserDefaults.standard.integer(forKey: "reminderWeekday"),
            now: now
        )
    }

    private static func dateComponents(for date: Date, repeatMode: ReminderRepeat, weekday: Int?) -> DateComponents {
        let calendar = Calendar.current

        switch repeatMode {
        case .none:
            return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        case .daily:
            return calendar.dateComponents([.hour, .minute], from: date)
        case .weekly:
            var components = calendar.dateComponents([.hour, .minute], from: date)
            components.weekday = weekday ?? calendar.component(.weekday, from: date)
            return components
        }
    }

    private static func refreshFollowUps(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date
    ) async throws {
        let center = UNUserNotificationCenter.current()
        await removeFollowUpRequests(from: center)
        try await scheduleFollowUps(
            date: date,
            repeatMode: repeatMode,
            weekday: weekday,
            center: center,
            now: now
        )
    }

    private static func scheduleFollowUps(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        center: UNUserNotificationCenter,
        now: Date = Date()
    ) async throws {
        let lastSelfieDate = UserDefaults.standard.object(forKey: "lastSelfieDate") as? Double
        let completedAt = lastSelfieDate.map(Date.init(timeIntervalSinceReferenceDate:))
        let followUps = ReminderFollowUpPlanner.followUps(
            reminderDate: date,
            repeatMode: repeatMode,
            weekday: weekday,
            now: now,
            completedAt: completedAt,
            limit: maximumFollowUpRequests
        )

        for followUp in followUps {
            let content = UNMutableNotificationContent()
            content.title = "Your Chameo is still waiting"
            content.body = "Take today's selfie to stop hourly reminders for today."
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: followUp.date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(
                UNNotificationRequest(identifier: followUp.identifier, content: content, trigger: trigger)
            )
        }
    }

    private static func removeAllReminderRequests(from center: UNUserNotificationCenter) async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter(isReminderIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func removeFollowUpRequests(from center: UNUserNotificationCenter) async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(followUpIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func isReminderIdentifier(_ identifier: String) -> Bool {
        identifier == requestIdentifier || identifier.hasPrefix(followUpIdentifierPrefix)
    }
}

struct ReminderFollowUp: Equatable {
    let identifier: String
    let date: Date
}

enum ReminderFollowUpPlanner {
    static func followUps(
        reminderDate: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date,
        completedAt: Date?,
        limit: Int,
        calendar: Calendar = .current
    ) -> [ReminderFollowUp] {
        guard limit > 0 else { return [] }

        var result: [ReminderFollowUp] = []
        var dayOffset = 0
        let today = calendar.startOfDay(for: now)
        let reminderTime = calendar.dateComponents([.hour, .minute], from: reminderDate)

        while result.count < limit && dayOffset < 365 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let occurrence = calendar.date(
                    bySettingHour: reminderTime.hour ?? 0,
                    minute: reminderTime.minute ?? 0,
                    second: 0,
                    of: day
                  ) else {
                break
            }

            let isOccurrenceDay: Bool
            switch repeatMode {
            case .none:
                isOccurrenceDay = calendar.isDate(occurrence, inSameDayAs: reminderDate)
            case .daily:
                isOccurrenceDay = true
            case .weekly:
                let reminderWeekday = weekday ?? calendar.component(.weekday, from: reminderDate)
                isOccurrenceDay = calendar.component(.weekday, from: day) == reminderWeekday
            }

            let isCompleted = completedAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false
            if isOccurrenceDay && !isCompleted {
                var followUp = calendar.date(byAdding: .hour, value: 1, to: occurrence)
                while let date = followUp,
                      calendar.isDate(date, inSameDayAs: occurrence),
                      result.count < limit {
                    if date > now {
                        result.append(
                            ReminderFollowUp(identifier: identifier(for: date, calendar: calendar), date: date)
                        )
                    }
                    followUp = calendar.date(byAdding: .hour, value: 1, to: date)
                }
            }

            if repeatMode == .none && day >= calendar.startOfDay(for: reminderDate) {
                break
            }
            dayOffset += 1
        }

        return result
    }

    private static func identifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return ReminderService.followUpIdentifierPrefix
            + String(format: "%04d%02d%02d-%02d%02d", components.year ?? 0, components.month ?? 0,
                     components.day ?? 0, components.hour ?? 0, components.minute ?? 0)
    }
}

enum ReminderError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        "Notification permission is required to schedule reminders."
    }
}
