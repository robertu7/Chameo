import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let contentSize = ChameoLayout.utilityWindowSize
    static let minimumContentSize = contentSize
    let state = SettingsState()
    private var localizationObservation: AnyCancellable?

    init(localizationController: LocalizationController,
         updateController: UpdateController,
         localPhotos: LocalPhotoSettingsController) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = L10n.string("Settings")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentViewController = NSHostingController(rootView:
            SettingsView(state: state)
                .environmentObject(localizationController)
                .environmentObject(updateController)
                .environmentObject(localPhotos)
        )
        window.fixContentSize(Self.contentSize)
        window.center()
        super.init(window: window)
        window.setFrameAutosaveName("ChameoSettingsCompact")
        window.fixContentSize(Self.contentSize)
        localizationObservation = localizationController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.window?.title = L10n.string("Settings") }
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
