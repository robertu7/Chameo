import XCTest
@testable import ChameoCore

final class AuthorizationTests: XCTestCase {
    func testLimitedPhotosAccessDoesNotSatisfyRequiredPermission() {
        XCTAssertFalse(RequiredPermissionStatus.limited.isGranted)
        XCTAssertTrue(RequiredPermissionStatus.authorized.isGranted)
    }

    func testLaterRevocationKeepsMainExperienceContextual() {
        XCTAssertEqual(
            AppStartupPolicy.destination(
                hasCompletedPermissionOnboarding: true,
                cameraStatus: .authorized,
                photosStatus: .limited
            ),
            .mainExperience
        )
    }
}
