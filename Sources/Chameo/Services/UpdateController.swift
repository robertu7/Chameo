import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    let reminderBarrier = UpdateReminderBarrier()
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false

    let isEnabled: Bool

    private var controller: SPUStandardUpdaterController?
    private var hasStarted = false

    init(isEnabled: Bool = AppDistribution.current.updatesEnabled) {
        self.isEnabled = isEnabled

        guard isEnabled else {
            controller = nil
            super.init()
            return
        }

        super.init()
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.controller = controller

        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$automaticallyChecksForUpdates)
    }

    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
        // Sparkle may retry termination without repeating willInstallUpdate.
        reminderBarrier.updateWillInstall()
        return true
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        reminderBarrier.updateWillInstall()
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock: @escaping () -> Void
    ) -> Bool {
        reminderBarrier.updateWillInstall()
        return false
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard reminderBarrier.requiresCleanup else { return }
        Task { await reminderBarrier.cancelUpdate() }
    }

    func start() {
        guard let controller, !hasStarted else { return }
        hasStarted = true
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ isEnabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = isEnabled
    }
}
