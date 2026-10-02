import XCTest
@testable import Chameo

final class TimelapseProgressTests: XCTestCase {
    func testDownloadingUsesThePhotoFractionRatherThanCompletedFrames() throws {
        let progress = TimelapseProgress.downloadingPhoto(0, 0.45)
        XCTAssertEqual(try XCTUnwrap(progress.phaseFraction(total: 3)), 0.45, accuracy: 0.001)
        XCTAssertEqual(progress.phaseTitleKey, "Downloading from iCloud…")
        XCTAssertEqual(progress.announcementKey, progress.phaseTitleKey)
    }

    func testUnknownWorkDoesNotClaimADeterminatePercentage() {
        for progress in [TimelapseProgress.preparing, .loadingPhoto(1), .saving] {
            XCTAssertNil(progress.phaseFraction(total: 3))
        }
        XCTAssertNil(TimelapseProgress.downloadingPhoto(0, .nan).phaseFraction(total: 3))
        XCTAssertNil(TimelapseProgress.framesWritten(0).phaseFraction(total: 0))
    }

    func testKnownEncodingCountsAndDownloadFractionsStayInRange() throws {
        XCTAssertEqual(try XCTUnwrap(TimelapseProgress.framesWritten(1).phaseFraction(total: 4)), 0.25)
        XCTAssertEqual(TimelapseProgress.framesWritten(5).phaseFraction(total: 4), 1)
        XCTAssertEqual(TimelapseProgress.framesWritten(-1).phaseFraction(total: 4), 0)
        XCTAssertEqual(TimelapseProgress.downloadingPhoto(0, 1.2).phaseFraction(total: 3), 1)
        XCTAssertEqual(TimelapseProgress.downloadingPhoto(0, -0.2).phaseFraction(total: 3), 0)
        XCTAssertEqual(TimelapseProgress.framesWritten(1).announcementKey, "Encoding video…")
    }
}
