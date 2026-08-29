import XCTest
@testable import ChameoCore

final class AppRouteTests: XCTestCase {
    func testCameraIsAStableNotificationDestination() {
        XCTAssertEqual(AppRoute(rawValue: "camera"), .camera)
        XCTAssertEqual(AppRoute.camera.id, "camera")
    }

    func testAllPrimaryRoutesRemainAvailable() {
        XCTAssertEqual(Set(AppRoute.allCases), [.camera, .library, .settings])
    }
}
