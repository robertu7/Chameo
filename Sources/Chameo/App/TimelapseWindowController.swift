import AppKit
import Combine
import SwiftUI

/// A reusable window for the app-owned export; closing it never cancels generation.
@MainActor
final class TimelapseWindowController: NSWindowController, NSWindowDelegate {
    static let contentSize = NSSize(width: ChameoLayout.utilityWindowWidth, height: 620)
    private let export: TimelapseExportController
    private let libraryStore: LibraryStore
    private var localizationObservation: AnyCancellable?

    init(export: TimelapseExportController, libraryStore: LibraryStore,
         localizationController: LocalizationController) {
        self.export = export
        self.libraryStore = libraryStore
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
        window.contentMinSize = NSSize(width: ChameoLayout.utilityWindowWidth, height: 580)
        window.contentMaxSize = NSSize(width: ChameoLayout.utilityWindowWidth, height: .greatestFiniteMagnitude)
        window.setContentSize(Self.contentSize)
        window.center()
        super.init(window: window)
        window.delegate = self
        window.setFrameAutosaveName("ChameoTimelapse")
        // Preserve the saved height and position while migrating older, wider windows.
        window.setContentSize(NSSize(width: Self.contentSize.width, height: window.contentLayoutRect.height))
        localizationObservation = localizationController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.window?.title = L10n.string("Timelapse") }
        }
    }

    required init?(coder: NSCoder) { nil }

    func windowWillClose(_ notification: Notification) {
        // prepare ignores busy exports, preserving generation and its frozen selection.
        export.prepare(assets: libraryStore.timelapseAssets())
    }

    func present() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
