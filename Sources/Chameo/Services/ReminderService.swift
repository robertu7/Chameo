import Foundation
import UserNotifications

enum ReminderService {
    static let requestIdentifier = "com.robertu.Chameo.chameoReminder"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func configureReminder(date: Date, repeatMode: ReminderRepeat) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else {
            throw ReminderError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "Take your Chameo"
        content.body = "Capture today's photo for your timeline."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(for: date, repeatMode: repeatMode),
            repeats: repeatMode != .none
        )
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }

    private static func dateComponents(for date: Date, repeatMode: ReminderRepeat) -> DateComponents {
        let calendar = Calendar.current

        switch repeatMode {
        case .none:
            return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        case .daily:
            return calendar.dateComponents([.hour, .minute], from: date)
        case .weekly:
            return calendar.dateComponents([.weekday, .hour, .minute], from: date)
        }
    }
}

enum ReminderError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        "Notification permission is required to schedule reminders."
    }
}
