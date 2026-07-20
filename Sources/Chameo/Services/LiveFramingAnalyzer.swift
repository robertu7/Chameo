@preconcurrency import AVFoundation
import CoreMedia
import Vision

final class LiveFramingAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: (@Sendable (LiveFramingFrame) -> Void)?

    private let minimumAnalysisInterval = 0.2
    private var isEnabled = false
    private var lastAnalysisTime = CMTime.invalid

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            lastAnalysisTime = .invalid
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isEnabled,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if lastAnalysisTime.isValid {
            let elapsed = CMTimeGetSeconds(timestamp - lastAnalysisTime)
            guard elapsed >= minimumAnalysisInterval else {
                return
            }
        }
        lastAnalysisTime = timestamp

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return
        }

        let faces = (request.results ?? []).map { face in
            LiveFramingFaceObservation(
                boundingBox: face.boundingBox,
                eyeLineY: Self.eyeLineY(for: face)
            )
        }
        onFrame?(
            LiveFramingFrame(
                pixelWidth: CVPixelBufferGetWidth(pixelBuffer),
                pixelHeight: CVPixelBufferGetHeight(pixelBuffer),
                faces: faces
            )
        )
    }

    private static func eyeLineY(for face: VNFaceObservation) -> CGFloat? {
        let regions = [
            face.landmarks?.leftEye,
            face.landmarks?.rightEye,
        ].compactMap { $0 }
        let points = regions.flatMap(\.normalizedPoints)
        guard !points.isEmpty else {
            return nil
        }

        let averageY = points.reduce(CGFloat.zero) { partial, point in
            partial + CGFloat(point.y)
        } / CGFloat(points.count)
        return face.boundingBox.minY + averageY * face.boundingBox.height
    }
}
