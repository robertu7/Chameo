import XCTest
@testable import Chameo

final class CameraSelectionPolicyTests: XCTestCase {
    func testSystemPreferredCameraWinsWhenAvailable() {
        let candidates = [
            CameraSelectionCandidate(uniqueID: "built-in", isBuiltIn: true),
            CameraSelectionCandidate(uniqueID: "continuity", isBuiltIn: false),
        ]

        XCTAssertEqual(
            CameraSelectionPolicy.preferredUniqueID(
                systemPreferredUniqueID: "continuity",
                candidates: candidates
            ),
            "continuity"
        )
    }

    func testBuiltInCameraIsFallbackWhenSystemPreferenceIsUnavailable() {
        let candidates = [
            CameraSelectionCandidate(uniqueID: "external", isBuiltIn: false),
            CameraSelectionCandidate(uniqueID: "built-in", isBuiltIn: true),
        ]

        XCTAssertEqual(
            CameraSelectionPolicy.preferredUniqueID(
                systemPreferredUniqueID: "disconnected",
                candidates: candidates
            ),
            "built-in"
        )
    }

    func testFirstAvailableCameraIsFallbackWithoutBuiltInCamera() {
        let candidates = [
            CameraSelectionCandidate(uniqueID: "external", isBuiltIn: false),
            CameraSelectionCandidate(uniqueID: "continuity", isBuiltIn: false),
        ]

        XCTAssertEqual(
            CameraSelectionPolicy.preferredUniqueID(
                systemPreferredUniqueID: nil,
                candidates: candidates
            ),
            "external"
        )
    }

    func testNoCameraReturnsNil() {
        XCTAssertNil(
            CameraSelectionPolicy.preferredUniqueID(
                systemPreferredUniqueID: nil,
                candidates: []
            )
        )
    }

    func testContinuityCameraPreviewIsNotMirrored() {
        XCTAssertFalse(
            CameraMirroringPolicy.shouldMirrorPreview(isContinuityCamera: true)
        )
    }

    func testOtherCameraPreviewsRemainMirrored() {
        XCTAssertTrue(
            CameraMirroringPolicy.shouldMirrorPreview(isContinuityCamera: false)
        )
    }
}
