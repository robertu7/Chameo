import XCTest
@testable import Chameo

final class UserFacingCopyTests: XCTestCase {
    func testAlignmentFallbackDoesNotClaimThePhotoWasSaved() throws {
        let errors: [FaceAlignmentError] = [
            .invalidImage,
            .noFace,
            .missingLandmarks,
            .processingFailed
        ]

        for error in errors {
            let message = L10n.string(
                error.localizationKey,
                localization: .english
            )
            XCTAssertFalse(message.localizedCaseInsensitiveContains("saved"))
            XCTAssertTrue(message.localizedCaseInsensitiveContains("save the original"))
        }
    }
}
