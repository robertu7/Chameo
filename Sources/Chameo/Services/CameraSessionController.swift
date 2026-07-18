@preconcurrency import AVFoundation
import Foundation

// AVCaptureSession requires blocking lifecycle work on a serial queue. This type
// contains that queue-owned state so CameraService can remain main-actor isolated.
final class CameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    var onActiveCameraChanged: ((ActiveCameraInfo) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.robertu.Chameo.camera.session")
    private let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
        mediaType: .video,
        position: .unspecified
    )
    private lazy var preferredCameraObserver = PreferredCameraObserver { [weak self] uniqueID in
        self?.systemPreferredCameraChanged(to: uniqueID)
    }

    private var isConfigured = false
    private var activeVideoInput: AVCaptureDeviceInput?
    private var isCaptureInProgress = false
    private var hasPendingPreferredCameraChange = false
    private var pendingPreferredCameraUniqueID: String?

    init() {
        _ = preferredCameraObserver
    }

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

    func capturePhoto(
        with settings: AVCapturePhotoSettings,
        mirrored: Bool,
        delegate: AVCapturePhotoCaptureDelegate
    ) {
        sessionQueue.async { [self] in
            isCaptureInProgress = true

            if let connection = photoOutput.connection(with: .video),
               connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }

            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func captureDidFinish() {
        sessionQueue.async { [self] in
            isCaptureInProgress = false

            guard hasPendingPreferredCameraChange else {
                return
            }

            let pendingUniqueID = pendingPreferredCameraUniqueID
            hasPendingPreferredCameraChange = false
            pendingPreferredCameraUniqueID = nil
            applyPreferredCamera(uniqueID: pendingUniqueID)
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer {
            session.commitConfiguration()
        }

        guard let device = preferredCamera() else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        activeVideoInput = input

        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)

        publishActiveCamera(device)
    }

    private func systemPreferredCameraChanged(to uniqueID: String?) {
        sessionQueue.async { [self] in
            guard isConfigured else {
                return
            }

            if isCaptureInProgress {
                hasPendingPreferredCameraChange = true
                pendingPreferredCameraUniqueID = uniqueID
                return
            }

            applyPreferredCamera(uniqueID: uniqueID)
        }
    }

    private func applyPreferredCamera(uniqueID: String?) {
        let device = uniqueID.flatMap(AVCaptureDevice.init(uniqueID:)) ?? preferredCamera()
        guard let device, device.uniqueID != activeVideoInput?.device.uniqueID else {
            return
        }

        do {
            try switchInput(to: device)
        } catch {
            // Keep the existing input when a newly preferred camera cannot be used.
        }
    }

    private func preferredCamera() -> AVCaptureDevice? {
        let discoveredDevices = discoverySession.devices
        let candidates = discoveredDevices.map(CameraSelectionCandidate.init)
        let preferredUniqueID = CameraSelectionPolicy.preferredUniqueID(
            systemPreferredUniqueID: AVCaptureDevice.systemPreferredCamera?.uniqueID,
            candidates: candidates
        )

        return preferredUniqueID.flatMap(AVCaptureDevice.init(uniqueID:))
    }

    private func switchInput(to device: AVCaptureDevice) throws {
        let newInput = try AVCaptureDeviceInput(device: device)
        let previousInput = activeVideoInput

        session.beginConfiguration()
        if let previousInput {
            session.removeInput(previousInput)
        }

        guard session.canAddInput(newInput) else {
            if let previousInput, session.canAddInput(previousInput) {
                session.addInput(previousInput)
            }
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }

        session.addInput(newInput)
        session.commitConfiguration()
        activeVideoInput = newInput
        publishActiveCamera(device)
    }

    private func publishActiveCamera(_ device: AVCaptureDevice) {
        let info = ActiveCameraInfo(
            uniqueID: device.uniqueID,
            name: device.localizedName,
            isContinuityCamera: device.isContinuityCamera,
            shouldMirrorPreview: CameraMirroringPolicy.shouldMirrorPreview(
                isContinuityCamera: device.isContinuityCamera
            )
        )
        onActiveCameraChanged?(info)
    }
}

struct ActiveCameraInfo: Equatable, Sendable {
    let uniqueID: String
    let name: String
    let isContinuityCamera: Bool
    let shouldMirrorPreview: Bool
}

struct CameraSelectionCandidate: Equatable, Sendable {
    let uniqueID: String
    let isBuiltIn: Bool

    init(uniqueID: String, isBuiltIn: Bool) {
        self.uniqueID = uniqueID
        self.isBuiltIn = isBuiltIn
    }

    init(device: AVCaptureDevice) {
        uniqueID = device.uniqueID
        isBuiltIn = device.deviceType == .builtInWideAngleCamera && !device.isContinuityCamera
    }
}

enum CameraSelectionPolicy {
    static func preferredUniqueID(
        systemPreferredUniqueID: String?,
        candidates: [CameraSelectionCandidate]
    ) -> String? {
        if let systemPreferredUniqueID,
           candidates.contains(where: { $0.uniqueID == systemPreferredUniqueID }) {
            return systemPreferredUniqueID
        }

        return candidates.first(where: \.isBuiltIn)?.uniqueID ?? candidates.first?.uniqueID
    }
}

enum CameraMirroringPolicy {
    static func shouldMirrorPreview(isContinuityCamera: Bool) -> Bool {
        !isContinuityCamera
    }
}

private final class PreferredCameraObserver: NSObject {
    private static let keyPath = "systemPreferredCamera"

    private let onChange: (String?) -> Void

    init(onChange: @escaping (String?) -> Void) {
        self.onChange = onChange
        super.init()
        AVCaptureDevice.self.addObserver(
            self,
            forKeyPath: Self.keyPath,
            options: [.new],
            context: nil
        )
    }

    deinit {
        AVCaptureDevice.self.removeObserver(self, forKeyPath: Self.keyPath)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == Self.keyPath else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        onChange((change?[.newKey] as? AVCaptureDevice)?.uniqueID)
    }
}
