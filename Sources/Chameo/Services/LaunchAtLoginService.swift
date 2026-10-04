import Foundation
import ServiceManagement

struct LaunchAtLoginRegistration {
    let status: SMAppService.Status
    var isRegistered: Bool { status == .enabled || status == .requiresApproval }
    var requiresApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool, register: () throws -> Void, unregister: () throws -> Void) throws {
        if enabled && !isRegistered { try register() }
        if !enabled && isRegistered { try unregister() }
    }
}

enum LaunchAtLoginService {
    static var registration: LaunchAtLoginRegistration {
        LaunchAtLoginRegistration(status: SMAppService.mainApp.status)
    }
    static var isRegistered: Bool { registration.isRegistered }

    static func setEnabled(_ enabled: Bool) throws {
        try registration.setEnabled(enabled, register: SMAppService.mainApp.register,
                                    unregister: SMAppService.mainApp.unregister)
    }

    static func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
