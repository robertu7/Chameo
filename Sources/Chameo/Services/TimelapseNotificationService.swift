import Foundation
@preconcurrency import UserNotifications

@MainActor
protocol TimelapseNotifying {
    func authorizationStatus() async -> UNAuthorizationStatus
    func prepareAuthorization() async -> UNAuthorizationStatus
    func deliver(exportID: UUID, filename: String) async throws
}

@MainActor
final class TimelapseNotificationService: TimelapseNotifying {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func registerCategory() async {
        let action = UNNotificationAction(
            identifier: TimelapseNotificationPolicy.openFolderAction,
            title: L10n.string("Open Folder"), options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: TimelapseNotificationPolicy.categoryIdentifier,
            actions: [action], intentIdentifiers: [], options: []
        )
        var categories = await center.notificationCategories()
        categories = categories.filter { $0.identifier != category.identifier }
        categories.insert(category)
        center.setNotificationCategories(categories)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func prepareAuthorization() async -> UNAuthorizationStatus {
        await registerCategory()
        if await authorizationStatus() == .notDetermined {
            // Authorization is app-wide: preserve sound support for daily
            // reminders even when the first request comes from an export.
            // Timelapse completion content itself never sets a sound.
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        return await authorizationStatus()
    }

    func deliver(exportID: UUID, filename: String) async throws {
        let status = await authorizationStatus()
        guard TimelapseNotificationPolicy.canDeliver(status) else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.string("Timelapse ready")
        content.body = filename
        content.categoryIdentifier = TimelapseNotificationPolicy.categoryIdentifier
        content.userInfo = [TimelapseNotificationPolicy.exportIDKey: exportID.uuidString]
        // The same identifier replaces only timelapse completion notifications.
        center.removeDeliveredNotifications(withIdentifiers: [TimelapseNotificationPolicy.requestIdentifier])
        try await center.add(UNNotificationRequest(
            identifier: TimelapseNotificationPolicy.requestIdentifier, content: content, trigger: nil
        ))
    }
}
