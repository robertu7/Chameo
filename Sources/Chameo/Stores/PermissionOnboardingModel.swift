import Foundation

@MainActor
final class PermissionOnboardingModel: ObservableObject {
    @Published private(set) var cameraStatus: RequiredPermissionStatus
    @Published private(set) var photosStatus: RequiredPermissionStatus
    @Published private(set) var permissionBeingRequested: RequiredPermissionKind?

    private let permissionProvider: any RequiredPermissionProviding

    init(permissionProvider: any RequiredPermissionProviding) {
        self.permissionProvider = permissionProvider
        self.cameraStatus = permissionProvider.cameraStatus
        self.photosStatus = permissionProvider.photosStatus
    }

    var canContinue: Bool {
        cameraStatus.isGranted && photosStatus.isGranted
    }

    func refresh() {
        cameraStatus = permissionProvider.cameraStatus
        photosStatus = permissionProvider.photosStatus
    }

    func request(_ permission: RequiredPermissionKind) async {
        guard permissionBeingRequested == nil else {
            return
        }

        permissionBeingRequested = permission
        defer {
            permissionBeingRequested = nil
            refresh()
        }

        switch permission {
        case .camera:
            await permissionProvider.requestCameraAuthorization()
        case .photos:
            await permissionProvider.requestPhotosAuthorization()
        }
    }

    @discardableResult
    func completeOnboarding(defaults: UserDefaults = .standard) -> Bool {
        refresh()
        guard canContinue else {
            return false
        }

        defaults.set(true, forKey: AppPreferenceKey.hasCompletedPermissionOnboarding)
        return true
    }
}
