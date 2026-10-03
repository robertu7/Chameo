import AppKit
import SwiftUI

private final class PermissionOnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum PermissionOnboardingWindowPlacement {
    static func centeredOrigin(
        windowSize: NSSize,
        screenFrame: NSRect
    ) -> NSPoint {
        NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
    }
}

@MainActor
final class PermissionOnboardingWindowController: NSWindowController, NSWindowDelegate {
    static let windowSize = ChameoLayout.onboardingWindowSize

    private let model: PermissionOnboardingModel
    private let onCompletion: () -> Void
    private var isCompletingOnboarding = false

    convenience init(
        localizationController: LocalizationController,
        onCompletion: @escaping () -> Void
    ) {
        self.init(
            permissionProvider: SystemRequiredPermissionService(),
            localizationController: localizationController,
            onCompletion: onCompletion
        )
    }

    init(
        permissionProvider: any RequiredPermissionProviding,
        localizationController: LocalizationController,
        onCompletion: @escaping () -> Void
    ) {
        self.model = PermissionOnboardingModel(permissionProvider: permissionProvider)
        self.onCompletion = onCompletion

        let window = PermissionOnboardingWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = L10n.string("Welcome to Chameo")
        window.isRestorable = false
        window.level = .floating

        super.init(window: window)

        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: PermissionOnboardingView(
                model: model,
                onContinue: { [weak self] in
                    self?.completeOnboarding()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                },
                onPermissionRequestFinished: { [weak self] in
                    self?.bringToFront()
                }
            )
            .environmentObject(localizationController)
            .environment(\.locale, localizationController.displayLocale)
        )
        window.fixContentSize(Self.windowSize)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        model.refresh()
        window?.contentView?.layoutSubtreeIfNeeded()
        centerOnActiveScreen()
        window?.invalidateShadow()
        bringToFront()
    }

    func refreshPermissionStatuses() {
        model.refresh()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isCompletingOnboarding else {
            NSApplication.shared.terminate(nil)
            return false
        }

        return true
    }

    private func completeOnboarding() {
        guard model.completeOnboarding() else {
            return
        }

        isCompletingOnboarding = true
        close()
        onCompletion()
    }

    private func bringToFront() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func centerOnActiveScreen() {
        guard let window,
              let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        window.setFrameOrigin(
            PermissionOnboardingWindowPlacement.centeredOrigin(
                windowSize: window.frame.size,
                screenFrame: screen.frame
            )
        )
    }
}
