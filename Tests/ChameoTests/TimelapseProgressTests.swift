import XCTest
@testable import Chameo

final class TimelapseProgressTests: XCTestCase {
    func testDownloadDetailDescribesOnlyTheCurrentPhoto() {
        let progress = TimelapseProgress.downloadingPhoto(0, 0.45)
        XCTAssertEqual(progress.text(total: 3),
                       L10n.format("Downloading photo %lld of %lld from iCloud · %lld%%", Int64(1), Int64(3), Int64(45)))
        XCTAssertEqual(progress.phaseTitleKey, "Downloading from iCloud…")
        XCTAssertEqual(progress.announcementKey, progress.phaseTitleKey)
    }

    func testUnknownWorkIsDescribedWithoutAPercentage() {
        for progress in [TimelapseProgress.preparing, .loadingPhoto(1), .saving] {
            XCTAssertFalse(progress.text(total: 3).contains("%"))
        }
    }

    func testDownloadDetailClampsPercentages() {
        XCTAssertEqual(TimelapseProgress.downloadingPhoto(0, 1.2).text(total: 3),
                       L10n.format("Downloading photo %lld of %lld from iCloud · %lld%%", Int64(1), Int64(3), Int64(100)))
        XCTAssertEqual(TimelapseProgress.downloadingPhoto(0, -0.2).text(total: 3),
                       L10n.format("Downloading photo %lld of %lld from iCloud · %lld%%", Int64(1), Int64(3), Int64(0)))
        XCTAssertEqual(TimelapseProgress.framesWritten(1).announcementKey, "Encoding video…")
    }
}
