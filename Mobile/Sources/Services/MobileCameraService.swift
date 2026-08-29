@preconcurrency import AVFoundation
import ChameoCore
import Foundation
import ImageIO
import Observation
@preconcurrency import Vision
import UIKit

enum MobileCameraStatus: Equatable {
    case idle
    case starting
    case ready
    case capturing
    case unavailable
}

@MainActor
@Observable
final class MobileCameraService {
    private(set) var status: MobileCameraStatus = .idle
    private(set) var liveFrame: LiveFramingFrame?
    let session: AVCaptureSession

    private let controller = MobileCameraSessionController()
    private var shouldRun = false

    init() {
        session = controller.session
        controller.onLiveFramingFrame = { [weak self] frame in
            Task { @MainActor in self?.liveFrame = frame }
        }
    }

    func start() {
        shouldRun = true
        guard status == .idle || status == .unavailable else { return }
        status = .starting
        controller.start { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard self.shouldRun else {
                    self.controller.stop()
                    self.status = .idle
                    return
                }
                self.status = result.isSuccess ? .ready : .unavailable
                self.controller.setLiveFramingEnabled(result.isSuccess)
            }
        }
    }

    func stop() {
        shouldRun = false
        controller.setLiveFramingEnabled(false)
        controller.stop()
        liveFrame = nil
        if status != .unavailable { status = .idle }
    }

    func capturePhoto() async throws -> Data {
        guard status == .ready else { throw MobileCameraError.notReady }
        status = .capturing
        defer { status = shouldRun ? .ready : .idle }
        return try await controller.capturePhoto()
    }

    func updateOrientation(_ orientation: UIInterfaceOrientation) {
        controller.setVideoRotationAngle(
            MobileCameraOrientationPolicy.clockwiseRotationAngle(
                for: orientation.mobileOrientation
            )
        )
    }
}

nonisolated private final class MobileCameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let analyzer = MobileLiveFramingAnalyzer()
    private let queue = DispatchQueue(label: "com.robertu.Chameo.mobile.camera")
    private var isConfigured = false
    private var captureDelegate: MobilePhotoCaptureDelegate?
    private var rotationAngle: CGFloat = 90
    var onLiveFramingFrame: (@Sendable (LiveFramingFrame) -> Void)? {
        didSet { analyzer.onFrame = onLiveFramingFrame }
    }

    func start(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        queue.async { [self] in
            do {
                if !isConfigured {
                    try configure()
                    isConfigured = true
                }
                if !session.isRunning { session.startRunning() }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setLiveFramingEnabled(_ enabled: Bool) {
        analyzer.setEnabled(enabled)
    }

    func setVideoRotationAngle(_ angle: CGFloat) {
        queue.async { [self] in
            rotationAngle = angle
            if let connection = videoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                if let connection = output.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false
                    }
                    if connection.isVideoRotationAngleSupported(rotationAngle) {
                        connection.videoRotationAngle = rotationAngle
                    }
                }
                let controller = self
                let delegate = MobilePhotoCaptureDelegate { result in
                    controller.queue.async { controller.captureDelegate = nil }
                    continuation.resume(with: result)
                }
                captureDelegate = delegate
                output.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            throw MobileCameraError.noFrontCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw MobileCameraError.configurationFailed }
        session.addInput(input)
        guard session.canAddOutput(output) else { throw MobileCameraError.configurationFailed }
        session.addOutput(output)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(
            analyzer,
            queue: DispatchQueue(
                label: "com.robertu.Chameo.mobile.camera.vision",
                qos: .userInitiated
            )
        )
        guard session.canAddOutput(videoOutput) else {
            throw MobileCameraError.configurationFailed
        }
        session.addOutput(videoOutput)
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
}

nonisolated private final class MobileLiveFramingAnalyzer: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onFrame: (@Sendable (LiveFramingFrame) -> Void)?
    private var enabled = false
    private var lastAnalysisTime = ContinuousClock.now - .seconds(1)

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled { lastAnalysisTime = .now - .seconds(1) }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard enabled,
              lastAnalysisTime.duration(to: .now) >= .milliseconds(250),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysisTime = .now

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        do {
            try handler.perform([request])
            let faces = (request.results ?? []).map { face in
                let eyeValues = [face.landmarks?.leftEye, face.landmarks?.rightEye]
                    .compactMap { region -> CGFloat? in
                        guard let region, region.pointCount > 0 else { return nil }
                        let average = region.normalizedPoints.reduce(CGFloat.zero) {
                            $0 + CGFloat($1.y)
                        } / CGFloat(region.pointCount)
                        return face.boundingBox.minY + average * face.boundingBox.height
                    }
                return LiveFramingFaceObservation(
                    boundingBox: face.boundingBox,
                    eyeLineY: eyeValues.isEmpty
                        ? nil : eyeValues.reduce(0, +) / CGFloat(eyeValues.count)
                )
            }
            onFrame?(
                LiveFramingFrame(
                    pixelWidth: CVPixelBufferGetWidth(pixelBuffer),
                    pixelHeight: CVPixelBufferGetHeight(pixelBuffer),
                    faces: faces
                )
            )
        } catch {
            onFrame?(LiveFramingFrame(
                pixelWidth: CVPixelBufferGetWidth(pixelBuffer),
                pixelHeight: CVPixelBufferGetHeight(pixelBuffer),
                faces: []
            ))
        }
    }
}

nonisolated private final class MobilePhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(MobileCameraError.noPhotoData))
        }
    }
}

nonisolated private extension Result where Success == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

nonisolated enum MobileCameraError: Error {
    case notReady
    case noFrontCamera
    case configurationFailed
    case noPhotoData
}
