import AppKit
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let localizationController = LocalizationController()
    let updateController = UpdateController()
    private let appState = AppState()
    private let cameraService = CameraService()
    private let libraryStore = LibraryStore()
    private var statusPopoverController: StatusPopoverController?
    private var permissionOnboardingWindowController: PermissionOnboardingWindowController?
    private var menuBarHandoffWindowController: MenuBarHandoffWindowController?
    private var reminderRefreshTask: Task<Void, Never>?
    private var libraryRefreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureUserDefaults()
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        installRefreshObservers()

        let requiredPermissions = SystemRequiredPermissionService()
        switch AppStartupPolicy.destination(
            hasCompletedPermissionOnboarding: UserDefaults.standard.bool(
                forKey: AppPreferenceKey.hasCompletedPermissionOnboarding
            ),
            cameraStatus: requiredPermissions.cameraStatus,
            photosStatus: requiredPermissions.photosStatus
        ) {
        case .permissionOnboarding:
            presentPermissionOnboarding()
        case .mainExperience:
            startMainExperience(showCamera: false)
            presentMenuBarHandoffIfNeeded()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if let permissionOnboardingWindowController {
            permissionOnboardingWindowController.present()
            return false
        }

        if let menuBarHandoffWindowController {
            menuBarHandoffWindowController.present()
            return false
        }

        if statusPopoverController == nil {
            startMainExperience(showCamera: false)
        }
        statusPopoverController?.showCamera()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        reminderRefreshTask?.cancel()
        libraryRefreshTask?.cancel()
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
        MenuBarHandoffPreference.prepareForCurrentInstallation()

        let launchAtLogin = AppDistribution.current.launchAtLoginEnabled
            && LaunchAtLoginService.isEnabled

        UserDefaults.standard.register(defaults: [
            AppPreferenceKey.albumName: AppDistribution.current.defaultAlbumName,
            AppPreferenceKey.handsFreeCountdown: false,
            AppPreferenceKey.hasCompletedPermissionOnboarding: false,
            AppPreferenceKey.hasShownMenuBarHandoff: false,
            AppPreferenceKey.showFaceGuide: true,
            AppPreferenceKey.saveLocation: false,
            AppPreferenceKey.launchAtLogin: launchAtLogin,
            AppPreferenceKey.language: AppLanguage.automatic.rawValue
        ])
        UserDefaults.standard.set(
            launchAtLogin,
            forKey: AppPreferenceKey.launchAtLogin
        )
    }

    private func installRefreshObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAfterSystemEvent(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange(_:)),
            name: .chameoLanguageDidChange,
            object: nil
        )

        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshAfterSystemEvent(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshAfterSystemEvent(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(refreshAfterSystemEvent(_:)),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func refreshAfterSystemEvent(_ notification: Notification) {
        if let permissionOnboardingWindowController {
            permissionOnboardingWindowController.refreshPermissionStatuses()
            return
        }

        refreshAppState()
    }

    @objc private func languageDidChange(_ notification: Notification) {
        refreshReminderNotifications()
    }

    private func presentPermissionOnboarding() {
        let controller = PermissionOnboardingWindowController(
            localizationController: localizationController,
            onCompletion: { [weak self] in
                self?.finishPermissionOnboarding()
            }
        )
        permissionOnboardingWindowController = controller
        controller.present()
    }

    private func finishPermissionOnboarding() {
        permissionOnboardingWindowController = nil
        startMainExperience(showCamera: false)
        presentMenuBarHandoffIfNeeded()
    }

    private func presentMenuBarHandoffIfNeeded() {
        guard !UserDefaults.standard.bool(
            forKey: AppPreferenceKey.hasShownMenuBarHandoff
        ) else {
            return
        }

        let controller = MenuBarHandoffWindowController(
            localizationController: localizationController,
            onOpenChameo: { [weak self] in
                MenuBarHandoffPreference.markShown()
                self?.menuBarHandoffWindowController = nil
                self?.statusPopoverController?.showCamera()
            },
            onDismiss: { [weak self] in
                MenuBarHandoffPreference.markShown()
                self?.menuBarHandoffWindowController = nil
            }
        )
        menuBarHandoffWindowController = controller
        controller.present()
    }

    private func startMainExperience(showCamera: Bool) {
        updateController.start()

        if statusPopoverController == nil {
            statusPopoverController = StatusPopoverController(
                appState: appState,
                cameraService: cameraService,
                libraryStore: libraryStore,
                localizationController: localizationController,
                updateController: updateController
            )
        }

        refreshAppState()

        if showCamera {
            statusPopoverController?.showCamera()
        }
    }

    private func refreshAppState() {
        refreshReminderNotifications()
        refreshLibrary()
    }

    private func refreshReminderNotifications() {
        reminderRefreshTask?.cancel()
        reminderRefreshTask = Task {
            await ReminderService.refreshRemindersFromStoredSettings()
        }
    }

    private func refreshLibrary() {
        libraryRefreshTask?.cancel()

        switch PhotoLibraryService.authorizationStatus() {
        case .authorized, .limited:
            break
        case .notDetermined, .denied, .restricted:
            return
        @unknown default:
            return
        }

        let albumName = UserDefaults.standard.string(forKey: AppPreferenceKey.albumName)
            ?? AppDistribution.current.defaultAlbumName
        libraryRefreshTask = Task {
            await libraryStore.reload(albumName: albumName)
        }
    }
}

@main
struct ChameoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.localizationController)
                .environmentObject(appDelegate.updateController)
                .environment(\.locale, appDelegate.localizationController.displayLocale)
        }
    }
}
