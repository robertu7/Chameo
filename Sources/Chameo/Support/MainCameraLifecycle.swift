import Combine

/// One owner coordinates both hosting views; a hidden view cannot restart the camera.
@MainActor
final class MainCameraLifecycle {
    private var observation: AnyCancellable?

    init(appState: AppState, start: @escaping () -> Void, stop: @escaping () -> Void) {
        observation = Publishers.CombineLatest(appState.$visibleMainSurface, appState.$selectedTab)
            .map { surface, tab in surface != nil && tab == .camera }
            .removeDuplicates()
            .sink { shouldRun in
                if shouldRun { start() } else { stop() }
            }
    }
}
