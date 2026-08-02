import CoreGraphics
import SwiftUI

enum ChameoLayout {
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

struct ChameoImageOutlineModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(outlineColor, lineWidth: 1)
            }
    }

    private var outlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.1)
    }
}

extension View {
    func chameoImageOutline(cornerRadius: CGFloat) -> some View {
        modifier(ChameoImageOutlineModifier(cornerRadius: cornerRadius))
    }
}
