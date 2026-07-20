import Foundation

enum AppStartupDestination: Equatable {
    case permissionOnboarding
    case mainExperience
}

enum AppStartupPolicy {
    static func destination(
        hasCompletedPermissionOnboarding: Bool,
        cameraStatus: RequiredPermissionStatus,
        photosStatus: RequiredPermissionStatus
    ) -> AppStartupDestination {
        guard hasCompletedPermissionOnboarding else {
            return .permissionOnboarding
        }

        if cameraStatus == .notDetermined || photosStatus == .notDetermined {
            return .permissionOnboarding
        }

        return .mainExperience
    }
}
