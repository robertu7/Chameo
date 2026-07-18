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

    func testNoFaceAlwaysSuggestsRetake() {
        XCTAssertEqual(
            CaptureQualityPolicy.suggestion(
                for: .noFace,
                acceptedScores: []
            ),
            .faceNotDetected
        )
    }

    func testScoreDoesNotTriggerWarningBeforeBaselineIsEstablished() {
        XCTAssertNil(
            CaptureQualityPolicy.suggestion(
                for: .scored(0.1),
                acceptedScores: Array(repeating: 0.7, count: 9)
            )
        )
    }

    func testScoreClearlyBelowBaselineSuggestsRetake() {
        XCTAssertEqual(
            CaptureQualityPolicy.suggestion(
                for: .scored(0.49),
                acceptedScores: Array(repeating: 0.6, count: 10)
            ),
            .retakeRecommended
        )
    }

    func testScoreNearBaselineDoesNotSuggestRetake() {
        XCTAssertNil(
            CaptureQualityPolicy.suggestion(
                for: .scored(0.51),
                acceptedScores: Array(repeating: 0.6, count: 10)
            )
        )
    }

    func testAnalysisFailureDoesNotSuggestRetake() {
        XCTAssertNil(
            CaptureQualityPolicy.suggestion(
                for: .analysisFailed,
                acceptedScores: Array(repeating: 0.8, count: 10)
            )
        )
    }
}
