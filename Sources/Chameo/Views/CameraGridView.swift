import SwiftUI

struct CameraGridView: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let thirdWidth = proxy.size.width / 3
                let thirdHeight = proxy.size.height / 3

                for index in 1...2 {
                    let x = thirdWidth * CGFloat(index)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))

                    let y = thirdHeight * CGFloat(index)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.65), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
