import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusPopoverController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let cameraService: CameraService
    private let libraryStore: LibraryStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var libraryStatusObservation: AnyCancellable?

    init(appState: AppState, cameraService: CameraService, libraryStore: LibraryStore) {
        self.appState = appState
        self.cameraService = cameraService
        self.libraryStore = libraryStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Chameo")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        observeDailyStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDayChanged(_:)),
            name: .NSCalendarDayChanged,
            object: nil
        )

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 448, height: 448)
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(appState)
                .environmentObject(cameraService)
                .environmentObject(libraryStore)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            close()
        } else {
            switch libraryStore.dailyStatus() {
            case .captured:
                showLibraryToday()
            default:
                showCamera()
            }
        }
    }

    func showCamera() {
        appState.selectedTab = .camera
        show()
    }

    func showLibraryToday() {
        appState.selectedLibraryDay = Calendar.current.startOfDay(for: Date())
        appState.selectedTab = .library
        show()
    }

    func show() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startOutsideClickMonitoring()
        syncCameraLifecycle()
    }

    func close() {
        stopOutsideClickMonitoring()
        cameraService.stop()
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
        cameraService.stop()
    }

    private func syncCameraLifecycle() {
        if appState.selectedTab == .camera {
            cameraService.start()
        } else {
            cameraService.stop()
        }
    }

    private func observeDailyStatus() {
        libraryStatusObservation = Publishers.CombineLatest3(
            libraryStore.$assets,
            libraryStore.$hasLoaded,
            libraryStore.$errorMessage
        )
        .sink { [weak self] assets, hasLoaded, errorMessage in
            let hasUsableSnapshot = (hasLoaded || !assets.isEmpty)
                && (errorMessage == nil || !assets.isEmpty)
            let status = DailyCaptureHistory.status(
                for: Date(),
                captureDates: assets.compactMap(\.createdAt),
                isAvailable: hasUsableSnapshot
            )
            self?.updateStatusItem(for: status)
        }
    }

    @objc private func calendarDayChanged(_ notification: Notification) {
        updateStatusItem(for: libraryStore.dailyStatus())
    }

    private func updateStatusItem(for status: DailyCaptureStatus) {
        guard let button = statusItem.button else {
            return
        }

        let symbolName: String
        let description: String

        switch status {
        case .captured:
            symbolName = "camera.fill"
            description = "Today's Chameo is captured"
        case .pendingToday:
            symbolName = "camera"
            description = "Today's Chameo is not captured yet"
        case .unknown:
            symbolName = "questionmark.circle"
            description = "Today's Chameo status is unavailable"
        case .missed, .future, .outsideTracking:
            symbolName = "camera"
            description = "Take today's Chameo"
        }

        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: description
        )
        button.toolTip = description
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.closeIfClickIsOutsidePopover(event)
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            Task { @MainActor in
                self?.closeIfClickIsOutsidePopover(event)
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func closeIfClickIsOutsidePopover(_ event: NSEvent) {
        guard popover.isShown else { return }

        if event.window == popover.contentViewController?.view.window {
            return
        }

        if let button = statusItem.button,
           event.window == button.window,
           button.bounds.contains(button.convert(event.locationInWindow, from: nil)) {
            return
        }

        close()
    }
}
