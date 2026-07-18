import XCTest
@testable import Chameo

final class CaptureQualityHistoryStoreTests: XCTestCase {
    func testRecordsOnlyScoredAcceptedCaptures() {
        let defaults = makeDefaults()

        CaptureQualityHistoryStore.recordAccepted(.noFace, in: defaults)
        CaptureQualityHistoryStore.recordAccepted(.scored(0.7), in: defaults)

        XCTAssertEqual(
            CaptureQualityHistoryStore.acceptedScores(from: defaults),
            [0.7]
        )
    }

    func testHistoryKeepsOnlyMostRecentScores() {
        let defaults = makeDefaults()

        for value in 0...CaptureQualityPolicy.maximumHistoryCount {
            CaptureQualityHistoryStore.recordAccepted(
                .scored(Float(value) / 100),
                in: defaults
            )
        }

        let scores = CaptureQualityHistoryStore.acceptedScores(from: defaults)
        XCTAssertEqual(scores.count, CaptureQualityPolicy.maximumHistoryCount)
        XCTAssertEqual(scores.first!, 0.01, accuracy: 0.0001)
        XCTAssertEqual(scores.last!, 0.30, accuracy: 0.0001)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "CaptureQualityHistoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
