import Foundation

enum AppBuildVariant: String {
    case release
    case test
}

struct AppDistributionConfiguration: Equatable {
    let bundleIdentifier: String
    let buildVariant: AppBuildVariant
    let defaultAlbumName: String
    let updatesEnabled: Bool
    let launchAtLoginEnabled: Bool

    init(infoDictionary: [String: Any]) {
        bundleIdentifier = infoDictionary["CFBundleIdentifier"] as? String
            ?? "com.robertu.Chameo"
        buildVariant = AppBuildVariant(
            rawValue: infoDictionary["ChameoBuildVariant"] as? String ?? ""
        ) ?? .test
        defaultAlbumName = infoDictionary["ChameoDefaultAlbumName"] as? String
            ?? "Chameo"
        updatesEnabled = infoDictionary["ChameoUpdatesEnabled"] as? Bool
            ?? false
        launchAtLoginEnabled = infoDictionary["ChameoLaunchAtLoginEnabled"] as? Bool
            ?? false
    }

    var isTestBuild: Bool {
        buildVariant == .test
    }
}

enum AppDistribution {
    static let current = AppDistributionConfiguration(
        infoDictionary: Bundle.main.infoDictionary ?? [:]
    )
}
