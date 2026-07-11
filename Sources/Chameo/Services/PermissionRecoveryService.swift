import AppKit
import Foundation

enum PermissionRecoveryDestination {
    case camera
    case photos
    case location
    case notifications

    var title: String {
        switch self {
        case .camera:
            return "Open Camera Settings"
        case .photos:
            return "Open Photos Settings"
        case .location:
            return "Open Location Settings"
        case .notifications:
            return "Open Notifications Settings"
        }
    }

    var settingsURL: URL? {
        switch self {
        case .camera:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
        case .photos:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")
        case .location:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        case .notifications:
            return URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        }
    }
}

enum PermissionRecoveryService {
    @MainActor
    static func open(_ destination: PermissionRecoveryDestination) {
        guard let settingsURL = destination.settingsURL else {
            return
        }

        NSWorkspace.shared.open(settingsURL)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
