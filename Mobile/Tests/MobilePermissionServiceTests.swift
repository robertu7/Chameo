import AVFoundation
import ChameoCore
import Photos
import XCTest
@testable import ChameoMobile

@MainActor
final class MobilePermissionServiceTests: XCTestCase {
    func testLimitedPhotosAuthorizationRemainsDistinct() {
        XCTAssertEqual(
            MobilePermissionService.photosStatus(from: .limited),
            .limited
        )
        XCTAssertFalse(
            MobilePermissionService.photosStatus(from: .limited).isGranted
        )
    }

    func testCameraAuthorizationMapping() {
        XCTAssertEqual(
            MobilePermissionService.cameraStatus(from: .authorized),
            .authorized
        )
        XCTAssertEqual(
            MobilePermissionService.cameraStatus(from: .denied),
            .denied
        )
    }
}
