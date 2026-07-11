@preconcurrency import AVFoundation
import Foundation

// AVCaptureSession requires blocking lifecycle work on a serial queue. This type
// contains that queue-owned state so CameraService can remain main-actor isolated.
final class CameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()

    private let sessionQueue = DispatchQueue(label: "com.robertu.Chameo.camera.session")
    private var isConfigured = false

    func start(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        sessionQueue.async { [self] in
            do {
                if !isConfigured {
                    try configureSession()
                    isConfigured = true
                }

                if !session.isRunning {
                    session.startRunning()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer {
            session.commitConfiguration()
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .unspecified
        ) else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)
    }
}
