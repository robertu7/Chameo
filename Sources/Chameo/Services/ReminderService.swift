import Foundation
import UserNotifications

enum ReminderService {
    static let requestIdentifier = "com.robertu.Chameo.chameoReminder"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func hasScheduledReminder() async -> Bool {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .contains { $0.identifier == requestIdentifier }
    }

    static func configureReminder(date: Date, repeatMode: ReminderRepeat, weekday: Int? = nil) async throws {
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
            dateMatching: dateComponents(for: date, repeatMode: repeatMode, weekday: weekday),
            repeats: repeatMode != .none
        )
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
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
}

enum ReminderError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        "Notification permission is required to schedule reminders."
    }
}
