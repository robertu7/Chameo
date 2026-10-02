import SwiftUI

private struct ReadableSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .overlay {
                shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.5 : 0), lineWidth: 1)
            }
    }
}

private struct GlassControlModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(Color(nsColor: .controlBackgroundColor), in: shape)
            } else {
                content.glassEffect(.regular.interactive(), in: shape)
            }
        }
        .overlay {
            shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.5 : 0), lineWidth: 1)
        }
    }
}

extension View {
    func chameoReadableSurface<S: InsettableShape>(in shape: S) -> some View {
        modifier(ReadableSurfaceModifier(shape: shape))
    }

    func chameoGlassControl<S: InsettableShape>(in shape: S) -> some View {
        modifier(GlassControlModifier(shape: shape))
    }
}
