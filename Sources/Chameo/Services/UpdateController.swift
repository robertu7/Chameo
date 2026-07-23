import Combine
import Sparkle

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false

    private let controller: SPUStandardUpdaterController
    private var hasStarted = false

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$automaticallyChecksForUpdates)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ isEnabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = isEnabled
    }
}
