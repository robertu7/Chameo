import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let appState = AppState()
    private let cameraService = CameraService()
    private let libraryStore = LibraryStore()
    private var statusPopoverController: StatusPopoverController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureUserDefaults()
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        statusPopoverController = StatusPopoverController(
            appState: appState,
            cameraService: cameraService,
            libraryStore: libraryStore
        )
        Task {
            await ReminderService.refreshFollowUpsFromStoredSettings()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard ReminderService.isReminderIdentifier(response.notification.request.identifier) else {
            return
        }

        await MainActor.run {
            statusPopoverController?.showCamera()
        }
    }

    private func configureUserDefaults() {
        UserDefaults.standard.register(defaults: [
            "showGrid": true,
            "saveLocation": false,
            "launchAtLogin": LaunchAtLoginService.isEnabled
        ])
        UserDefaults.standard.set(LaunchAtLoginService.isEnabled, forKey: "launchAtLogin")
    }
}

@main
struct ChameoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
