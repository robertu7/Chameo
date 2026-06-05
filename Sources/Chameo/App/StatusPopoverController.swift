import AppKit
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
            show()
        }
    }

    func showCamera() {
        appState.selectedTab = .camera
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
