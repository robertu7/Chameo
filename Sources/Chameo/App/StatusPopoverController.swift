import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusPopoverController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let cameraService: CameraService
    private let libraryStore: LibraryStore
    private let localizationController: LocalizationController
    private let updateController: UpdateController
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var standaloneWindowController: StandaloneChameoWindowController?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var libraryStatusObservation: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?
    private var localizationObservation: AnyCancellable?

    var isPopoverPresented: Bool {
        popover.isShown
    }

    init(
        appState: AppState,
        cameraService: CameraService,
        libraryStore: LibraryStore,
        localizationController: LocalizationController,
        updateController: UpdateController
    ) {
        self.appState = appState
        self.cameraService = cameraService
        self.libraryStore = libraryStore
        self.localizationController = localizationController
        self.updateController = updateController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()

        statusItem.autosaveName = "ChameoStatusItem"

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
        observeLocalization()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDayChanged(_:)),
            name: .NSCalendarDayChanged,
            object: nil
        )

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(
            width: ChameoLayout.popoverWidth,
            height: ChameoLayout.popoverHeight
        )
        popover.contentViewController = NSHostingController(rootView: makeContentView())
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            close()
        } else {
            appState.destination = .main
            switch libraryStore.dailyStatus() {
            case .captured:
                appState.selectedLibraryDay = Calendar.current.startOfDay(for: Date())
                appState.selectedTab = .library
            default:
                appState.selectedTab = .camera
            }
            showPopover()
        }
    }

    func showCamera() {
        appState.destination = .main
        appState.selectedTab = .camera
        showStandaloneWindow()
    }

    func showCameraPopover() {
        appState.destination = .main
        appState.selectedTab = .camera
        showPopover()
    }

    func showLibraryToday() {
        appState.destination = .main
        appState.selectedLibraryDay = Calendar.current.startOfDay(for: Date())
        appState.selectedTab = .library
        showStandaloneWindow()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        standaloneWindowController?.close()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startOutsideClickMonitoring()
        syncCameraLifecycle()
    }

    private func showStandaloneWindow() {
        if popover.isShown {
            close()
        }

        if standaloneWindowController == nil {
            standaloneWindowController = StandaloneChameoWindowController(
                rootView: makeContentView(),
                onClose: { [weak self] in
                    self?.cameraService.stop()
                }
            )
        }
        standaloneWindowController?.present()
        syncCameraLifecycle()
    }

    private func makeContentView() -> some View {
        ContentView()
            .environmentObject(appState)
            .environmentObject(cameraService)
            .environmentObject(libraryStore)
            .environmentObject(localizationController)
            .environmentObject(updateController)
            .environment(\.locale, localizationController.displayLocale)
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

    private func observeLocalization() {
        localizationObservation = localizationController.objectWillChange
            .sink { [weak self] _ in
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
            description = L10n.string("status.today.saved")
        case .pendingToday:
            iconName = "eye"
            description = L10n.string("status.today.pending")
        case .unknown:
            iconName = "eye"
            description = L10n.string("status.today.unavailable")
        case .missed, .future, .outsideTracking:
            iconName = "eye"
            description = L10n.string("status.today.take")
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

@MainActor
private final class StandaloneChameoWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init<Content: View>(
        rootView: Content,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: ChameoLayout.popoverWidth,
                    height: ChameoLayout.popoverHeight
                )
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Chameo"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
        window.setContentSize(
            NSSize(
                width: ChameoLayout.popoverWidth,
                height: ChameoLayout.popoverHeight
            )
        )
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKey()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

enum StatusMenuIcon {
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
