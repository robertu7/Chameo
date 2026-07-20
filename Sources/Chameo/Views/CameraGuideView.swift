import SwiftUI

struct CameraGuideView: View {
    let guidanceState: LiveFramingGuidanceState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let faceRect = FaceGuideGeometry.rect(in: size)
            let centerX = size.width / 2
            let eyeY = FaceGuideGeometry.eyeLineY(in: size)

            ZStack {
                Ellipse()
                    .stroke(guideColor.opacity(0.82), lineWidth: guideLineWidth)
                    .frame(width: faceRect.width, height: faceRect.height)
                    .position(x: faceRect.midX, y: faceRect.midY)

                Path { path in
                    path.move(to: CGPoint(x: centerX, y: faceRect.minY))
                    path.addLine(to: CGPoint(x: centerX, y: faceRect.maxY))

                    path.move(to: CGPoint(x: faceRect.minX, y: eyeY))
                    path.addLine(to: CGPoint(x: faceRect.maxX, y: eyeY))
                }
                .stroke(
                    guideColor.opacity(0.76),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )

                if let title = guidanceState.title {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: ChameoLayout.compactControlSize)
                        .background(
                            .regularMaterial,
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(guideColor.opacity(0.5), lineWidth: 1)
                        }
                        .padding(.bottom, ChameoLayout.sectionSpacing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .allowsHitTesting(false)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: guidanceState
        )
    }

    private var guideColor: Color {
        switch guidanceState {
        case .neutral:
            return .white
        case .adjusting:
            return .orange
        case .ready:
            return .green
        }
    }

    private var guideLineWidth: CGFloat {
        guidanceState == .ready ? 1.75 : 1.25
    }

    private var accessibilityLabel: String {
        switch guidanceState {
        case .neutral:
            return L10n.string("Face guide")
        case .adjusting(let hint):
            return L10n.format("Framing guidance: %@", hint.title)
        case .ready:
            return L10n.string("Framing ready")
        }
    }
}
