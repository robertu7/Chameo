import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.setMirrored(mirrored)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
        nsView.setMirrored(mirrored)
    }
}

final class PreviewView: NSView {
    private let captureLayer = AVCaptureVideoPreviewLayer()

    var previewLayer: AVCaptureVideoPreviewLayer {
        captureLayer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = captureLayer
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = captureLayer
    }

    override func layout() {
        super.layout()
        captureLayer.frame = bounds
    }

    func setMirrored(_ mirrored: Bool) {
        guard let connection = captureLayer.connection,
              connection.isVideoMirroringSupported else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }
}
