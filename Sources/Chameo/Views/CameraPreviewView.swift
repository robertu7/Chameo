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
    private var connectionObservation: NSKeyValueObservation?
    private var shouldMirror = true

    var previewLayer: AVCaptureVideoPreviewLayer {
        captureLayer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configurePreviewLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configurePreviewLayer()
    }

    private func configurePreviewLayer() {
        wantsLayer = true
        layer = captureLayer
        // The view can mount before the session has an input. Keep the requested
        // mirror state and reapply it whenever configuration creates a connection.
        connectionObservation = captureLayer.observe(\.connection, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.applyMirroring()
            }
        }
    }

    override func layout() {
        super.layout()
        captureLayer.frame = bounds
    }

    func setMirrored(_ mirrored: Bool) {
        shouldMirror = mirrored
        applyMirroring()
    }

    private func applyMirroring() {
        guard let connection = captureLayer.connection,
              connection.isVideoMirroringSupported else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = shouldMirror
    }
}
