public enum RequiredPermissionKind: Equatable, Sendable {
    case camera
    case photos
}

public enum RequiredPermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    public var isGranted: Bool { self == .authorized }
}

public enum AppStartupDestination: Equatable, Sendable {
    case permissionOnboarding
    case mainExperience
}

public enum AppStartupPolicy {
    public static func destination(
        hasCompletedPermissionOnboarding: Bool,
        cameraStatus: RequiredPermissionStatus,
        photosStatus: RequiredPermissionStatus
    ) -> AppStartupDestination {
        guard hasCompletedPermissionOnboarding else { return .permissionOnboarding }
        if cameraStatus == .notDetermined || photosStatus == .notDetermined {
            return .permissionOnboarding
        }
        return .mainExperience
    }
}
