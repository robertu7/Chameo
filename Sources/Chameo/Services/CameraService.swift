@preconcurrency import AVFoundation
import Foundation

@MainActor
final class CameraService: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case ready
        case unavailable(String)
        case capturing
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastError: String?

    var session: AVCaptureSession {
        sessionController.session
    }

    private let sessionController = CameraSessionController()
    private var captureDelegate: PhotoCaptureDelegate?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.status = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            status = .unauthorized
        @unknown default:
            status = .unavailable("Unknown camera authorization state.")
        }
    }

    func stop() {
        sessionController.stop()
    }

    func capturePhoto(mirrored: Bool) async throws -> Data {
        if case .ready = status {
            status = .capturing
        } else {
            throw CameraError.notReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            if let connection = sessionController.photoOutput.connection(with: .video),
               connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }

            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { @MainActor in
                    self?.captureDelegate = nil
                    self?.status = .ready

                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        self?.lastError = error.localizedDescription
                        continuation.resume(throwing: error)
                    }
                }
            }

            captureDelegate = delegate
            sessionController.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureAndStart() {
        status = .idle

        sessionController.start { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }

                switch result {
                case .success:
                    self.status = .ready
                case .failure(let error):
                    self.lastError = error.localizedDescription
                    self.status = .unavailable(error.localizedDescription)
                }
            }
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.missingPhotoData))
            return
        }

        completion(.success(data))
    }
}

enum CameraError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput
    case missingPhotoData
    case notReady

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "No camera is available."
        case .cannotAddInput:
            return "The camera could not be added to the capture session."
        case .cannotAddOutput:
            return "The photo output could not be added to the capture session."
        case .missingPhotoData:
            return "The captured photo did not contain image data."
        case .notReady:
            return "The camera is not ready."
        }
    }
}
