import XCTest
@testable import Chameo

final class FaceCaptureQualitySelectionTests: XCTestCase {
    func testLargestFaceDeterminesCaptureQuality() {
        let evaluation = FaceCaptureQualitySelection.evaluation(
            from: [
                FaceCaptureQualityCandidate(area: 0.1, score: 0.9),
                FaceCaptureQualityCandidate(area: 0.4, score: 0.6),
            ]
        )

        XCTAssertEqual(evaluation, .scored(0.6))
    }

    func testMissingScoreOnLargestFaceDoesNotUseAnotherPerson() {
        let evaluation = FaceCaptureQualitySelection.evaluation(
            from: [
                FaceCaptureQualityCandidate(area: 0.1, score: 0.9),
                FaceCaptureQualityCandidate(area: 0.4, score: nil),
            ]
        )

        XCTAssertEqual(evaluation, .scoreUnavailable)
    }

    func testNoFacesProducesNoFaceEvaluation() {
        XCTAssertEqual(
            FaceCaptureQualitySelection.evaluation(from: []),
            .noFace
        )
    }
}
