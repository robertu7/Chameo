import AppKit
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let appState = AppState()
    private let cameraService = CameraService()
    private let libraryStore = LibraryStore()
    private var statusPopoverController: StatusPopoverController?
    private var reminderRefreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureUserDefaults()
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        installReminderRefreshObservers()
        statusPopoverController = StatusPopoverController(
            appState: appState,
            cameraService: cameraService,
            libraryStore: libraryStore
        )
        refreshReminderNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        reminderRefreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard ReminderService.shouldPresentReminderNotification(
            identifier: notification.request.identifier
        ) else {
            await ReminderService.refreshRemindersFromStoredSettings()
            return []
        }

        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard ReminderService.isReminderIdentifier(response.notification.request.identifier) else {
            return
        }

        guard ReminderService.shouldPresentReminderNotification(
            identifier: response.notification.request.identifier
        ) else {
            await ReminderService.refreshRemindersFromStoredSettings()
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

    private func installReminderRefreshObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshReminderNotificationsAfterSystemEvent),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshReminderNotificationsAfterSystemEvent),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshReminderNotificationsAfterSystemEvent),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshReminderNotificationsAfterSystemEvent),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func refreshReminderNotificationsAfterSystemEvent(_ notification: Notification) {
        refreshReminderNotifications()
    }

    private func refreshReminderNotifications() {
        reminderRefreshTask?.cancel()
        reminderRefreshTask = Task {
            await ReminderService.refreshRemindersFromStoredSettings()
        }
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
