import AppKit

enum AccessibilityAnnouncement {
    static func post(
        _ message: String,
        priority: NSAccessibilityPriorityLevel = .medium
    ) {
        guard !message.isEmpty else {
            return
        }

        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: priority.rawValue,
            ]
        )
    }
}
