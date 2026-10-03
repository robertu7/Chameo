import AppKit
import CoreGraphics
import SwiftUI

enum ChameoLayout {
    static let utilityWindowWidth: CGFloat = 500
    static let utilityWindowHeight: CGFloat = 460
    static let onboardingWindowHeight: CGFloat = 560
    static let utilityWindowSize = CGSize(width: utilityWindowWidth, height: utilityWindowHeight)
    static let onboardingWindowSize = CGSize(width: utilityWindowWidth, height: onboardingWindowHeight)
    static let utilityWindowInset: CGFloat = 20

    static let popoverWidth: CGFloat = 448
    static let popoverHeight: CGFloat = 526
    static let contentWidth: CGFloat = 420
    static let contentHeight: CGFloat = 407
    static let previewWidth: CGFloat = 392
    static let livePreviewHeight: CGFloat = 349

    static let outerInset: CGFloat = 14
    static let sectionSpacing: CGFloat = 12
    static let compactSpacing: CGFloat = 6
    static let compactControlSize: CGFloat = 28
    static let timelapseButtonWidth: CGFloat = 120

    static let cornerRadius: CGFloat = 8
}

@MainActor
extension NSWindow {
    /// Install after the hosting controller and any saved frame have been restored.
    func fixContentSize(_ size: NSSize) {
        styleMask.remove(.resizable)
        collectionBehavior.insert(.fullScreenNone)
        contentMinSize = size
        contentMaxSize = size
        setContentSize(size)
        standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

struct ChameoImageOutlineModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(outlineColor, lineWidth: 1)
            }
    }

    private var outlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(contrast == .increased ? 0.5 : 0.1)
            : Color.black.opacity(contrast == .increased ? 0.5 : 0.1)
    }
}

extension View {
    func chameoImageOutline(cornerRadius: CGFloat) -> some View {
        modifier(ChameoImageOutlineModifier(cornerRadius: cornerRadius))
    }
}
