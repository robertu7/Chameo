import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let contentSize = NSSize(width: 620, height: 560)
    static let minimumContentSize = NSSize(width: 560, height: 480)
    let state = SettingsState()
    private var localizationObservation: AnyCancellable?

    init(localizationController: LocalizationController,
         updateController: UpdateController,
         localPhotos: LocalPhotoSettingsController) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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
        window.contentMinSize = Self.minimumContentSize
        window.setContentSize(Self.contentSize)
        window.center()
        super.init(window: window)
        window.setFrameAutosaveName("ChameoSettings")
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
