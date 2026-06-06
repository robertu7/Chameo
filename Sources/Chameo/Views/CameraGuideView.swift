import SwiftUI

struct CameraGuideView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let faceRect = faceGuideRect(in: size)
            let centerX = size.width / 2
            let eyeY = faceRect.minY + faceRect.height * 0.38

            ZStack {
                Ellipse()
                    .stroke(.white.opacity(0.72), lineWidth: 1.25)
                    .frame(width: faceRect.width, height: faceRect.height)
                    .position(x: faceRect.midX, y: faceRect.midY)

                Path { path in
                    path.move(to: CGPoint(x: centerX, y: faceRect.minY))
                    path.addLine(to: CGPoint(x: centerX, y: faceRect.maxY))

                    path.move(to: CGPoint(x: faceRect.minX, y: eyeY))
                    path.addLine(to: CGPoint(x: faceRect.maxX, y: eyeY))
                }
                .stroke(.white.opacity(0.68), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .allowsHitTesting(false)
    }

    private func faceGuideRect(in size: CGSize) -> CGRect {
        let width = min(size.width * 0.48, size.height * 0.42)
        let height = min(size.height * 0.78, width * 1.34)
        let originX = (size.width - width) / 2
        let originY = (size.height - height) / 2

        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
