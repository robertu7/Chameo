import Foundation

struct AppVersion {
    let version: String
    let buildID: String

    static var current: AppVersion {
        let infoDictionary = Bundle.main.infoDictionary ?? [:]
        let version = infoDictionary["CFBundleShortVersionString"] as? String
        let buildID = infoDictionary["ChameoBuildID"] as? String

        return AppVersion(
            version: version?.nilIfEmpty ?? "0.1.0",
            buildID: buildID?.nilIfEmpty ?? "development"
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
