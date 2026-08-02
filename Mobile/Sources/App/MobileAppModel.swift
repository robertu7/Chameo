import ChameoCore
import Foundation
import Observation

@MainActor
@Observable
final class MobileAppModel {
    static let completedOnboardingKey = "hasCompletedPermissionOnboarding"
    static let languageKey = "language"

    var selectedRoute: AppRoute = .camera
    private(set) var hasCompletedOnboarding: Bool
    private(set) var language: AppLanguage

    let permissions: MobilePermissionService
    @ObservationIgnored private var locationServiceStorage: MobileLocationService?
    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        permissions: MobilePermissionService = MobilePermissionService()
    ) {
        self.defaults = defaults
        self.permissions = permissions
        locationServiceStorage = nil
        hasCompletedOnboarding = defaults.bool(forKey: Self.completedOnboardingKey)
        language = AppLanguage(
            rawValue: defaults.string(forKey: Self.languageKey) ?? ""
        ) ?? .automatic
    }

    var localization: AppLocalization {
        AppLocalization.resolve(preference: language)
    }

    /// Core Location can synchronously contact the system service while its
    /// manager is being created. Defer that work until Settings or a capture
    /// explicitly needs location so first launch can render immediately.
    var locationService: MobileLocationService {
        if let locationServiceStorage {
            return locationServiceStorage
        }
        let service = MobileLocationService()
        locationServiceStorage = service
        return service
    }

    var requiresOnboarding: Bool {
        !hasCompletedOnboarding
    }

    func completeOnboarding() -> Bool {
        permissions.refresh()
        guard permissions.cameraStatus.isGranted,
              permissions.photosStatus.isGranted else {
            return false
        }
        defaults.set(true, forKey: Self.completedOnboardingKey)
        hasCompletedOnboarding = true
        selectedRoute = .camera
        return true
    }

    func selectLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        defaults.set(language.rawValue, forKey: Self.languageKey)
        self.language = language
    }

    func route(to route: AppRoute) {
        selectedRoute = route
    }
}
