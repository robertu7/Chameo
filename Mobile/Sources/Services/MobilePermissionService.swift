@preconcurrency import AVFoundation
import ChameoCore
import Observation
@preconcurrency import Photos

@MainActor
@Observable
final class MobilePermissionService {
    private(set) var cameraStatus: RequiredPermissionStatus = .notDetermined
    private(set) var photosStatus: RequiredPermissionStatus = .notDetermined

    init() {
        refresh()
    }

    func refresh() {
        cameraStatus = Self.cameraStatus(
            from: AVCaptureDevice.authorizationStatus(for: .video)
        )
        photosStatus = Self.photosStatus(
            from: PHPhotoLibrary.authorizationStatus(for: .readWrite)
        )
    }

    func requestCamera() async {
        guard cameraStatus == .notDetermined else { return }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        refresh()
    }

    func requestPhotos() async {
        guard photosStatus == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        refresh()
    }

    static func cameraStatus(from status: AVAuthorizationStatus) -> RequiredPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    static func photosStatus(from status: PHAuthorizationStatus) -> RequiredPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .limited: .limited
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}
