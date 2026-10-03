import SwiftUI

struct CameraGuideView: View {
    let guidanceState: LiveFramingGuidanceState
    var guideOffset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let faceRect = FaceGuideGeometry.rect(in: size).offsetBy(dx: 0, dy: guideOffset)
            let centerX = size.width / 2
            let eyeY = FaceGuideGeometry.eyeLineY(in: size) + guideOffset
            let eyeTolerance = FaceGuideGeometry.eyeLineTolerance(in: size)

            ZStack {
                Ellipse()
                    .stroke(guideColor.opacity(0.65), lineWidth: guideLineWidth)
                    .frame(width: faceRect.width, height: faceRect.height)
                    .shadow(color: .black.opacity(0.8), radius: 1)
                    .position(x: faceRect.midX, y: faceRect.midY)

                Path { path in
                    path.move(to: CGPoint(x: centerX, y: faceRect.minY))
                    path.addLine(to: CGPoint(x: centerX, y: faceRect.maxY))
                }
                .stroke(
                    guideColor.opacity(0.42),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                .shadow(color: .black.opacity(0.8), radius: 1)

                // Show the same eye tolerance that determines capture readiness.
                Capsule()
                    .fill(eyeGuideColor.opacity(0.14))
                    .frame(width: faceRect.width, height: eyeTolerance * 2)
                    .position(x: centerX, y: eyeY)

                Path { path in
                    path.move(to: CGPoint(x: faceRect.minX, y: eyeY))
                    path.addLine(to: CGPoint(x: faceRect.maxX, y: eyeY))
                }
                .stroke(eyeGuideColor.opacity(0.9), lineWidth: 1.5)
                .shadow(color: .black.opacity(0.8), radius: 1)

                if let title = guidanceState.title {
                    Label(guidanceState == .ready ? L10n.string("Framing ready") : title, systemImage: guidanceState == .ready ? "checkmark.circle.fill" : "person.crop.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: ChameoLayout.compactControlSize)
                        .chameoReadableSurface(in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(guideColor.opacity(0.5), lineWidth: 1)
                        }
                        .padding(.bottom, ChameoLayout.sectionSpacing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.animation(.easeOut(duration: 0.15))
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .allowsHitTesting(false)
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

    private var eyeGuideColor: Color {
        switch guidanceState {
        case .ready, .adjusting(.holdStill):
            return .green
        case .neutral, .adjusting:
            return guideColor
        }
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
