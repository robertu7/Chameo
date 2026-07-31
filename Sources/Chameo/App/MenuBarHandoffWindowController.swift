import AppKit
import SwiftUI

@MainActor
final class MenuBarHandoffWindowController: NSWindowController, NSWindowDelegate {
    private static let windowSize = NSSize(width: 420, height: 300)

    private let onOpenChameo: () -> Void
    private let onDismiss: () -> Void
    private var hasFinished = false

    init(
        localizationController: LocalizationController,
        onOpenChameo: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onOpenChameo = onOpenChameo
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.string("Chameo is ready")
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: MenuBarHandoffView(
                onOpenChameo: { [weak self] in
                    self?.openChameo()
                }
            )
            .environmentObject(localizationController)
            .environment(\.locale, localizationController.displayLocale)
        )
        window.setContentSize(Self.windowSize)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard !hasFinished else {
            return
        }

        hasFinished = true
        onDismiss()
    }

    private func openChameo() {
        guard !hasFinished else {
            return
        }

        hasFinished = true
        close()
        onOpenChameo()
    }
}
