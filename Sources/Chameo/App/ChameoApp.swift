import AppKit
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let localizationController = LocalizationController()
    let updateController = UpdateController()
    let localPhotos = LocalPhotoSettingsController()
    private let appState = AppState()
    private let cameraService = CameraService()
    private let libraryStore = LibraryStore()
    private let timelapseExport = TimelapseExportController()
    private let timelapseOpenRequest = DeferredTimelapseOpenRequest()
    private let notificationOpenRequest = DeferredOpenRequest()
    private var statusPopoverController: StatusPopoverController?
    private var permissionOnboardingWindowController: PermissionOnboardingWindowController?
    private var reminderRefreshTask: Task<Void, Never>?
    private var libraryRefreshTask: Task<Void, Never>?

    private var updateTerminationTask: Task<Void, Never>?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard updateTerminationTask == nil else { return .terminateLater }
        timelapseExport.cancelDestinationPanel()
        if timelapseExport.state == .running {
            let alert = NSAlert()
            alert.messageText = L10n.string("Cancel timelapse and quit?")
            alert.informativeText = L10n.string("The unfinished export will be discarded. Any existing video at the destination will be kept.")
            alert.addButton(withTitle: L10n.string("Keep Generating"))
            alert.addButton(withTitle: L10n.string("Cancel Export and Quit"))
            if alert.runModal() != .alertSecondButtonReturn {
                if updateController.reminderBarrier.requiresCleanup {
                    Task { await updateController.reminderBarrier.cancelUpdate() }
                }
                return .terminateCancel
            }
        } else if !timelapseExport.isGenerating && !updateController.reminderBarrier.requiresCleanup {
            return .terminateNow
        }
        updateTerminationTask = Task {
            await timelapseExport.cancelAndWait()
            let mayTerminate = await updateController.reminderBarrier.prepareForTermination()
            updateTerminationTask = nil
            sender.reply(toApplicationShouldTerminate: mayTerminate)
            if !mayTerminate && updateController.reminderBarrier.requiresCleanup {
                NSAlert(error: ReminderError.updateTimedOut).runModal()
            }
        }
        return .terminateLater
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureUserDefaults()
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        installRefreshObservers()
        timelapseOpenRequest.installHandler { [weak self] id in
            guard let self else { return }
            self.timelapseExport.openResult(id: id)
            if let error = self.timelapseExport.resultActionError {
                let alert = NSAlert()
                alert.messageText = L10n.string("Could not open timelapse")
                alert.informativeText = error
                alert.addButton(withTitle: L10n.string("Close"))
                alert.runModal()
            }
        }

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

        if statusPopoverController == nil {
            startMainExperience(showCamera: false)
        }
        if statusPopoverController?.isPopoverPresented == true {
            return false
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
        if notification.request.identifier == TimelapseNotificationPolicy.requestIdentifier {
            return []
        }
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
        if let id = TimelapseNotificationPolicy.exportID(
            identifier: response.notification.request.identifier,
            action: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo
        ) {
            await MainActor.run { timelapseOpenRequest.performOrDefer(id) }
            return
        }
        guard let destination = ReminderNotificationResponsePolicy.destination(
            identifier: response.notification.request.identifier,
            actionIdentifier: response.actionIdentifier,
            isCompletedToday: ReminderService.hasSelfieTaken(on: Date())
        ) else {
            return
        }

        await MainActor.run {
            notificationOpenRequest.performOrDefer(destination)
        }
        await ReminderService.refreshRemindersFromStoredSettings()
    }

    private func configureUserDefaults() {
        let launchAtLogin = AppDistribution.current.launchAtLoginEnabled
            && LaunchAtLoginService.isEnabled

        UserDefaults.standard.register(defaults: [
            AppPreferenceKey.albumName: AppDistribution.current.defaultAlbumName,
            AppPreferenceKey.handsFreeCountdown: false,
            AppPreferenceKey.hasCompletedPermissionOnboarding: false,
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
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.statusPopoverController?.showCameraPopover()
        }
    }

    private func startMainExperience(showCamera: Bool) {
        updateController.start()

        if statusPopoverController == nil {
            statusPopoverController = StatusPopoverController(
                appState: appState,
                cameraService: cameraService,
                libraryStore: libraryStore,
                timelapseExport: timelapseExport,
                localizationController: localizationController,
                updateController: updateController,
                localPhotos: localPhotos
            )
            notificationOpenRequest.installHandler { [weak self] destination in
                self?.openFromNotification(destination)
            }
        }

        refreshAppState()

        if showCamera {
            statusPopoverController?.showCameraPopover()
        }
    }

    private func openFromNotification(_ destination: ReminderNotificationOpenDestination) {
        Task { @MainActor [weak self] in
            await Task.yield()
            switch destination {
            case .camera:
                self?.statusPopoverController?.showCamera()
            case .libraryToday:
                self?.statusPopoverController?.showLibraryToday()
            }
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
@MainActor
enum ChameoApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate

        // AppDelegate owns the menu bar experience and its auxiliary windows.
        // Keep the delegate alive because NSApplication holds it weakly.
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
