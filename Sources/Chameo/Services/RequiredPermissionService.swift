@preconcurrency import AVFoundation
import Foundation
import Photos

enum RequiredPermissionKind: Equatable {
    case camera
    case photos
}

enum RequiredPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var isGranted: Bool {
        self == .authorized
    }
}

@MainActor
protocol RequiredPermissionProviding {
    var cameraStatus: RequiredPermissionStatus { get }
    var photosStatus: RequiredPermissionStatus { get }

    func requestCameraAuthorization() async
    func requestPhotosAuthorization() async
}

@MainActor
final class SystemRequiredPermissionService: RequiredPermissionProviding {
    var cameraStatus: RequiredPermissionStatus {
        Self.normalizedCameraStatus(
            AVCaptureDevice.authorizationStatus(for: .video)
        )
    }

    var photosStatus: RequiredPermissionStatus {
        Self.normalizedPhotosStatus(
            PhotoLibraryService.authorizationStatus()
        )
    }

    static func normalizedCameraStatus(
        _ status: AVAuthorizationStatus
    ) -> RequiredPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    static func normalizedPhotosStatus(
        _ status: PHAuthorizationStatus
    ) -> RequiredPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized, .limited:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    func requestCameraAuthorization() async {
        guard cameraStatus == .notDetermined else {
            return
        }

        _ = await AVCaptureDevice.requestAccess(for: .video)
    }

    func requestPhotosAuthorization() async {
        guard photosStatus == .notDetermined else {
            return
        }

        _ = await PhotoLibraryService.requestAuthorization()
    }
}
