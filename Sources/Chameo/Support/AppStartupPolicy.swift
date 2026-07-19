import Foundation

enum AppStartupDestination: Equatable {
    case permissionOnboarding
    case mainExperience
}

enum AppStartupPolicy {
    static func destination(hasCompletedPermissionOnboarding: Bool) -> AppStartupDestination {
        hasCompletedPermissionOnboarding ? .mainExperience : .permissionOnboarding
    }
}
