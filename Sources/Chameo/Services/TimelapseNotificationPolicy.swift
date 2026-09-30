import Foundation
@preconcurrency import UserNotifications

enum TimelapseNotificationPolicy {
    static let requestIdentifier = "chameo.timelapse.completed"
    static let categoryIdentifier = "chameo.timelapse.completion"
    static let openFolderAction = "chameo.timelapse.openFolder"
    static let exportIDKey = "timelapseExportID"

    static func canDeliver(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    static func exportID(identifier: String, action: String, userInfo: [AnyHashable: Any]) -> UUID? {
        guard identifier == requestIdentifier,
              action == UNNotificationDefaultActionIdentifier || action == openFolderAction,
              let value = userInfo[exportIDKey] as? String else { return nil }
        return UUID(uuidString: value)
    }
}
