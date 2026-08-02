import UIKit
@preconcurrency import UserNotifications

nonisolated final class MobileNotificationDelegate: NSObject, UIApplicationDelegate,
    UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .openChameoCamera, object: nil)
        }
    }
}

extension Notification.Name {
    static let openChameoCamera = Notification.Name("OpenChameoCamera")
}
