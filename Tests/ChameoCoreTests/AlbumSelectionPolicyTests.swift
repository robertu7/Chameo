import XCTest
@testable import ChameoCore

final class AlbumSelectionPolicyTests: XCTestCase {
    func testRememberedDestinationWinsWhileItStillExists() {
        let candidates = [
            AlbumSelectionCandidate(identifier: "larger", eligibleChameoCount: 20),
            AlbumSelectionCandidate(identifier: "remembered", eligibleChameoCount: 2),
        ]

        XCTAssertEqual(
            AlbumSelectionPolicy.saveDestination(
                from: candidates,
                rememberedIdentifier: "remembered"
            ),
            "remembered"
        )
    }

    func testMissingRememberedDestinationSelectsLargestThenIdentifier() {
        let candidates = [
            AlbumSelectionCandidate(identifier: "z", eligibleChameoCount: 4),
            AlbumSelectionCandidate(identifier: "b", eligibleChameoCount: 7),
            AlbumSelectionCandidate(identifier: "a", eligibleChameoCount: 7),
        ]

        XCTAssertEqual(
            AlbumSelectionPolicy.saveDestination(
                from: candidates,
                rememberedIdentifier: "missing"
            ),
            "a"
        )
    }

    func testEligibilityRequiresBothPhotoMediaTypeAndCreationDate() {
        XCTAssertTrue(
            ChameoAssetEligibility.isEligible(isPhoto: true, creationDate: Date())
        )
        XCTAssertFalse(
            ChameoAssetEligibility.isEligible(isPhoto: true, creationDate: nil)
        )
        XCTAssertFalse(
            ChameoAssetEligibility.isEligible(isPhoto: false, creationDate: Date())
        )
    }
}
