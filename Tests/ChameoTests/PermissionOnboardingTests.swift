import XCTest
import AVFoundation
import Photos
@testable import Chameo

@MainActor
final class PermissionOnboardingTests: XCTestCase {
    func testCanContinueOnlyWhenCameraAndPhotosAreAuthorized() {
        let statuses: [RequiredPermissionStatus] = [
            .notDetermined,
            .authorized,
            .denied,
            .restricted,
        ]

        for cameraStatus in statuses {
            for photosStatus in statuses {
                let provider = StubRequiredPermissionProvider(
                    cameraStatus: cameraStatus,
                    photosStatus: photosStatus
                )
                let model = PermissionOnboardingModel(permissionProvider: provider)

                XCTAssertEqual(
                    model.canContinue,
                    cameraStatus == .authorized && photosStatus == .authorized,
                    "Unexpected gate for camera \(cameraStatus), Photos \(photosStatus)"
                )
            }
        }
    }

    func testSystemAuthorizationStatusesAreNormalized() {
        let cameraCases: [(AVAuthorizationStatus, RequiredPermissionStatus)] = [
            (.notDetermined, .notDetermined),
            (.authorized, .authorized),
            (.denied, .denied),
            (.restricted, .restricted),
        ]
        let photosCases: [(PHAuthorizationStatus, RequiredPermissionStatus)] = [
            (.notDetermined, .notDetermined),
            (.authorized, .authorized),
            (.limited, .authorized),
            (.denied, .denied),
            (.restricted, .restricted),
        ]

        for (systemStatus, expectedStatus) in cameraCases {
            XCTAssertEqual(
                SystemRequiredPermissionService.normalizedCameraStatus(systemStatus),
                expectedStatus
            )
        }

        for (systemStatus, expectedStatus) in photosCases {
            XCTAssertEqual(
                SystemRequiredPermissionService.normalizedPhotosStatus(systemStatus),
                expectedStatus
            )
        }
    }

    func testRequestRefreshesPermissionStatus() async {
        let provider = StubRequiredPermissionProvider(
            cameraStatus: .notDetermined,
            photosStatus: .notDetermined
        )
        provider.cameraStatusAfterRequest = .authorized
        let model = PermissionOnboardingModel(permissionProvider: provider)

        await model.request(.camera)

        XCTAssertEqual(provider.cameraRequestCount, 1)
        XCTAssertEqual(model.cameraStatus, .authorized)
        XCTAssertNil(model.permissionBeingRequested)
    }

    func testCompletionIsPersistedOnlyWhenBothPermissionsAreAuthorized() throws {
        let suiteName = "PermissionOnboardingTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let provider = StubRequiredPermissionProvider(
            cameraStatus: .authorized,
            photosStatus: .denied
        )
        let model = PermissionOnboardingModel(permissionProvider: provider)

        XCTAssertFalse(model.completeOnboarding(defaults: defaults))
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKey.hasCompletedPermissionOnboarding))

        provider.photosStatus = .authorized

        XCTAssertTrue(model.completeOnboarding(defaults: defaults))
        XCTAssertTrue(defaults.bool(forKey: AppPreferenceKey.hasCompletedPermissionOnboarding))
    }

    func testStartupPolicyShowsOnboardingUntilInitialPermissionsAreGranted() {
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: false,
                cameraStatus: .authorized,
                photosStatus: .authorized
            ),
            .permissionOnboarding
        )
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: true,
                cameraStatus: .notDetermined,
                photosStatus: .authorized
            ),
            .permissionOnboarding
        )
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: true,
                cameraStatus: .authorized,
                photosStatus: .notDetermined
            ),
            .permissionOnboarding
        )
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: true,
                cameraStatus: .authorized,
                photosStatus: .authorized
            ),
            .mainExperience
        )
    }

    func testStartupPolicyKeepsLaterPermissionRevocationContextual() {
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: true,
                cameraStatus: .denied,
                photosStatus: .authorized
            ),
            .mainExperience
        )
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: true,
                cameraStatus: .authorized,
                photosStatus: .restricted
            ),
            .mainExperience
        )
    }

    func testOnboardingWindowCentersInTheFullScreenFrame() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1_512, height: 982)
        let windowSize = NSSize(width: 420, height: 420)

        XCTAssertEqual(
            PermissionOnboardingWindowPlacement.centeredOrigin(
                windowSize: windowSize,
                screenFrame: screenFrame
            ),
            NSPoint(x: 546, y: 281)
        )
    }

    func testOnboardingWindowRetainsItsSizeAfterInstallingTheHostingView() {
        let provider = StubRequiredPermissionProvider(
            cameraStatus: .notDetermined,
            photosStatus: .notDetermined
        )
        let controller = PermissionOnboardingWindowController(
            permissionProvider: provider,
            onCompletion: {}
        )

        XCTAssertEqual(
            controller.window?.frame.size,
            NSSize(width: 420, height: 420)
        )
    }

}

@MainActor
private final class StubRequiredPermissionProvider: RequiredPermissionProviding {
    var cameraStatus: RequiredPermissionStatus
    var photosStatus: RequiredPermissionStatus
    var cameraStatusAfterRequest: RequiredPermissionStatus?
    var photosStatusAfterRequest: RequiredPermissionStatus?
    var cameraRequestCount = 0
    var photosRequestCount = 0

    init(
        cameraStatus: RequiredPermissionStatus,
        photosStatus: RequiredPermissionStatus
    ) {
        self.cameraStatus = cameraStatus
        self.photosStatus = photosStatus
    }

    func requestCameraAuthorization() async {
        cameraRequestCount += 1
        if let cameraStatusAfterRequest {
            cameraStatus = cameraStatusAfterRequest
        }
    }

    func requestPhotosAuthorization() async {
        photosRequestCount += 1
        if let photosStatusAfterRequest {
            photosStatus = photosStatusAfterRequest
        }
    }
}
