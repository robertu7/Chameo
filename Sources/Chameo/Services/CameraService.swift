@preconcurrency import AVFoundation
import Foundation
import OSLog

@MainActor
final class CameraService: NSObject, ObservableObject {
    private static let logger = Logger(
        subsystem: "com.robertu.Chameo",
        category: "camera"
    )

    enum Status: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case ready
        case unavailable(LocalizedMessage)
        case capturing
        case switchingCamera

        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.requestingPermission, .requestingPermission),
                 (.unauthorized, .unauthorized),
                 (.ready, .ready),
                 (.unavailable, .unavailable),
                 (.capturing, .capturing),
                 (.switchingCamera, .switchingCamera):
                return true
            default:
                return false
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastError: LocalizedMessage?
    @Published private(set) var activeCameraID: String?
    @Published private(set) var activeCameraName: String?
    @Published private(set) var availableCameras: [CameraOption] = []
    @Published private(set) var isPreviewMirrored = true
    @Published private(set) var liveFramingGuidanceState: LiveFramingGuidanceState = .neutral

    var session: AVCaptureSession {
        sessionController.session
    }

    private let sessionController = CameraSessionController()
    private var captureDelegate: PhotoCaptureDelegate?
    private var shouldRunSession = false
    private var isLiveFramingGuidanceEnabled = false
    private var liveFramingGuidanceEvaluator = LiveFramingGuidanceEvaluator()

    override init() {
        super.init()
        sessionController.onActiveCameraChanged = { [weak self] info in
            Task { @MainActor in
                Self.logger.info(
                    "Active camera: \(info.name, privacy: .public), Continuity: \(info.isContinuityCamera, privacy: .public)"
                )
                self?.activeCameraID = info.uniqueID
                self?.activeCameraName = info.name
                self?.isPreviewMirrored = info.shouldMirrorPreview
                self?.resetLiveFramingGuidance()
            }
        }
        sessionController.onAvailableCamerasChanged = { [weak self] cameras in
            Task { @MainActor in
                let names = cameras.map(\.name).joined(separator: ", ")
                Self.logger.debug(
                    "Available cameras (\(cameras.count, privacy: .public)): \(names, privacy: .public)"
                )
                self?.availableCameras = cameras
            }
        }
        sessionController.onLiveFramingFrame = { [weak self] frame in
            Task { @MainActor in
                self?.consumeLiveFramingFrame(frame)
            }
        }
    }

    func start() {
        shouldRunSession = true
        updateLiveFramingAnalysis()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.shouldRunSession else {
                        return
                    }

                    if granted {
                        self.configureAndStart()
                    } else {
                        self.status = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            status = .unauthorized
        @unknown default:
            status = .unavailable(.localized("Camera access status is unavailable."))
        }
    }

    func stop() {
        shouldRunSession = false
        updateLiveFramingAnalysis()
        resetLiveFramingGuidance()
        if status != .unauthorized {
            status = .idle
        }
        sessionController.stop()
    }

    func capturePhoto(mirrored: Bool) async throws -> Data {
        if case .ready = status {
            status = .capturing
            updateLiveFramingAnalysis()
            resetLiveFramingGuidance()
        } else {
            throw CameraError.notReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off

            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { @MainActor in
                    self?.sessionController.captureDidFinish()
                    self?.captureDelegate = nil
                    if let self {
                        self.status = self.shouldRunSession ? .ready : .idle
                        self.updateLiveFramingAnalysis()
                    }

                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        self?.lastError = .error(error)
                        continuation.resume(throwing: error)
                    }
                }
            }

            captureDelegate = delegate
            sessionController.capturePhoto(
                with: settings,
                mirrored: mirrored,
                delegate: delegate
            )
        }
    }

    func selectCamera(uniqueID: String) async throws {
        guard case .ready = status else {
            throw CameraError.notReady
        }
        status = .switchingCamera
        updateLiveFramingAnalysis()
        resetLiveFramingGuidance()

        do {
            try await withCheckedThrowingContinuation { continuation in
                sessionController.selectCamera(uniqueID: uniqueID) { result in
                    continuation.resume(with: result)
                }
            }
            status = shouldRunSession ? .ready : .idle
            updateLiveFramingAnalysis()
        } catch {
            lastError = .error(error)
            Self.logger.error(
                "Camera selection failed: \(error.localizedDescription, privacy: .public)"
            )
            status = shouldRunSession ? .ready : .idle
            updateLiveFramingAnalysis()
            throw error
        }
    }

    func setLiveFramingGuidanceEnabled(_ enabled: Bool) {
        guard isLiveFramingGuidanceEnabled != enabled else {
            return
        }
        isLiveFramingGuidanceEnabled = enabled
        updateLiveFramingAnalysis()
        if !enabled {
            resetLiveFramingGuidance()
        }
    }

    private func configureAndStart() {
        status = .idle

        sessionController.start { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }

                guard self.shouldRunSession else {
                    self.sessionController.stop()
                    self.status = .idle
                    return
                }

                switch result {
                case .success:
                    self.status = .ready
                    self.updateLiveFramingAnalysis()
                case .failure(let error):
                    self.lastError = .error(error)
                    self.status = .unavailable(.error(error))
                }
            }
        }
    }

    private func updateLiveFramingAnalysis() {
        let shouldAnalyze = isLiveFramingGuidanceEnabled
            && shouldRunSession
            && status == .ready
        sessionController.setLiveFramingEnabled(shouldAnalyze)
    }

    private func consumeLiveFramingFrame(_ frame: LiveFramingFrame) {
        guard isLiveFramingGuidanceEnabled,
              shouldRunSession,
              status == .ready else {
            return
        }

        liveFramingGuidanceState = liveFramingGuidanceEvaluator.evaluate(
            frame: frame,
            previewSize: CGSize(
                width: ChameoLayout.previewWidth,
                height: ChameoLayout.livePreviewHeight
            ),
            mirrored: isPreviewMirrored
        )
    }

    private func resetLiveFramingGuidance() {
        liveFramingGuidanceState = liveFramingGuidanceEvaluator.reset()
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
    case cannotAddVideoOutput
    case cameraUnavailable
    case missingPhotoData
    case notReady

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return L10n.string("No camera is available.")
        case .cannotAddInput:
            return L10n.string("Could not connect to the selected camera.")
        case .cannotAddOutput:
            return L10n.string("Could not prepare the camera for photos.")
        case .cannotAddVideoOutput:
            return L10n.string("Could not start live framing.")
        case .cameraUnavailable:
            return L10n.string("The selected camera is no longer available.")
        case .missingPhotoData:
            return L10n.string("The camera did not return a photo. Try again.")
        case .notReady:
            return L10n.string("The camera is not ready yet. Try again.")
        }
    }
}
