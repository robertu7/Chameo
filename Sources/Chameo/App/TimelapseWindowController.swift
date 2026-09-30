import AppKit
import Combine
import SwiftUI

/// A reusable window for the app-owned export; closing it never cancels generation.
@MainActor
final class TimelapseWindowController: NSWindowController {
    static let contentSize = NSSize(width: 620, height: 620)
    private var localizationObservation: AnyCancellable?

    init(export: TimelapseExportController, libraryStore: LibraryStore,
         localizationController: LocalizationController) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L10n.string("Timelapse")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentViewController = NSHostingController(rootView:
            TimelapseExportView(onCreate: { [weak window] in export.chooseDestination(in: window) })
                .environmentObject(export)
                .environmentObject(libraryStore)
                .environmentObject(localizationController)
        )
        // Installing the content controller can resize the window, so constrain it afterward.
        window.contentMinSize = NSSize(width: 560, height: 580)
        window.setContentSize(Self.contentSize)
        window.center()
        super.init(window: window)
        window.setFrameAutosaveName("ChameoTimelapse")
        localizationObservation = localizationController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.window?.title = L10n.string("Timelapse") }
        }
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
