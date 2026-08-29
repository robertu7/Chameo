@preconcurrency import UserNotifications

enum ReminderNotificationOpenDestination: Equatable, Sendable {
    case camera
    case libraryToday
}

enum ReminderNotificationResponsePolicy {
    static func destination(
        identifier: String,
        actionIdentifier: String,
        isCompletedToday: Bool
    ) -> ReminderNotificationOpenDestination? {
        guard ReminderService.isReminderIdentifier(identifier),
              actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return nil
        }

        return isCompletedToday ? .libraryToday : .camera
    }
}
