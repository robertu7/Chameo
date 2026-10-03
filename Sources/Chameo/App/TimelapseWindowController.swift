import AppKit
import Combine
import SwiftUI

/// A reusable window for the app-owned export; closing it never cancels generation.
@MainActor
final class TimelapseWindowController: NSWindowController, NSWindowDelegate {
    static let contentSize = ChameoLayout.utilityWindowSize
    static let minimumContentSize = contentSize
    private let export: TimelapseExportController
    private let libraryStore: LibraryStore
    private var localizationObservation: AnyCancellable?

    init(export: TimelapseExportController, libraryStore: LibraryStore,
         localizationController: LocalizationController,
         onTakeChameo: @escaping () -> Void = {}) {
        self.export = export
        self.libraryStore = libraryStore
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = L10n.string("Timelapse")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentViewController = NSHostingController(rootView:
            TimelapseExportView(
                onCreate: { [weak window] in export.chooseDestination(in: window) },
                onTakeChameo: { [weak window] in
                    window?.close()
                    onTakeChameo()
                }
            )
                .environmentObject(export)
                .environmentObject(libraryStore)
                .environmentObject(localizationController)
        )
        window.fixContentSize(Self.contentSize)
        window.center()
        super.init(window: window)
        window.delegate = self
        window.setFrameAutosaveName("ChameoTimelapseCompact")
        window.fixContentSize(Self.contentSize)
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
