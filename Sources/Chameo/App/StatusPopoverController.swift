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
    private var appearanceObservation: NSKeyValueObservation?

    init(appState: AppState, cameraService: CameraService, libraryStore: LibraryStore) {
        self.appState = appState
        self.cameraService = cameraService
        self.libraryStore = libraryStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()

        if let button = statusItem.button {
            button.image = StatusMenuIcon.image(
                named: "eye",
                appearance: NSApp.effectiveAppearance
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        observeDailyStatus()
        observeAppearance()
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

    private func observeAppearance() {
        appearanceObservation = NSApp.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusItem(for: self.libraryStore.dailyStatus())
            }
        }
    }

    @objc private func calendarDayChanged(_ notification: Notification) {
        updateStatusItem(for: libraryStore.dailyStatus())
    }

    private func updateStatusItem(for status: DailyCaptureStatus) {
        guard let button = statusItem.button else {
            return
        }

        let description: String
        let iconName: String

        switch status {
        case .captured:
            iconName = "eye-captured"
            description = "Today's Chameo is captured"
        case .pendingToday:
            iconName = "eye"
            description = "Today's Chameo is not captured yet"
        case .unknown:
            iconName = "eye"
            description = "Today's Chameo status is unavailable"
        case .missed, .future, .outsideTracking:
            iconName = "eye"
            description = "Take today's Chameo"
        }

        button.image = StatusMenuIcon.image(
            named: iconName,
            appearance: NSApp.effectiveAppearance
        )
        button.setAccessibilityLabel(description)
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

private enum StatusMenuIcon {
    static func image(named name: String, appearance: NSAppearance) -> NSImage {
        let resourceName = appearance.isDark ? "\(name)-dark" : name
        let resourceURL = Bundle.main.url(
            forResource: resourceName,
            withExtension: "pdf",
            subdirectory: "MenuBarIcons"
        ) ?? Bundle.module.url(
            forResource: resourceName,
            withExtension: "pdf",
            subdirectory: "MenuBarIcons"
        ) ?? Bundle.main.url(
            forResource: name,
            withExtension: "pdf",
            subdirectory: "MenuBarIcons"
        ) ?? Bundle.module.url(
            forResource: name,
            withExtension: "pdf",
            subdirectory: "MenuBarIcons"
        )

        if let resourceURL,
           let image = NSImage(contentsOf: resourceURL) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }

        let fallback = NSImage(
            systemSymbolName: "eye",
            accessibilityDescription: "Chameo"
        ) ?? NSImage(size: NSSize(width: 18, height: 18))
        fallback.isTemplate = true
        return fallback
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
