import SwiftUI
import UIKit

struct FullScreenRequirementReader: UIViewRepresentable {
    let onChange: (Bool, UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: ObserverView, context: Context) {
        uiView.onChange = onChange
        uiView.report()
    }

    final class ObserverView: UIView {
        var onChange: ((Bool, UIInterfaceOrientation) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        func report() {
            guard let window else { return }
            let screenBounds = window.screen.coordinateSpace.convert(
                window.screen.bounds,
                to: window.coordinateSpace
            )
            let isFullScreen = abs(window.bounds.width - screenBounds.width) < 1
                && abs(window.bounds.height - screenBounds.height) < 1
            onChange?(isFullScreen, window.windowScene?.interfaceOrientation ?? .portrait)
        }
    }
}
