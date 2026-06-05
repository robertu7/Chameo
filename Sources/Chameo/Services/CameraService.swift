@preconcurrency import AVFoundation
import Foundation

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

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.robertu.Chameo.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDelegate: PhotoCaptureDelegate?
    private var isConfigured = false

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
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capturePhoto(mirrored: Bool) async throws -> Data {
        if case .ready = status {
            status = .capturing
        } else {
            throw CameraError.notReady
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                if let connection = photoOutput.connection(with: .video),
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
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        } onCancel: {
            Task { @MainActor in
                self.status = .ready
            }
        }
    }

    private func configureAndStart() {
        status = .idle

        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.isConfigured {
                    try self.configureSession()
                    self.isConfigured = true
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                Task { @MainActor in
                    self.status = .ready
                }
            } catch {
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                    self.status = .unavailable(error.localizedDescription)
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
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
