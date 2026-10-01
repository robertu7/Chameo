import XCTest
@testable import Chameo

@MainActor
final class PhotoDeletionServiceTests: XCTestCase {
    func testPhotosFailureLeavesLocalCopyUntouched() async {
        var didTrash = false
        do {
            _ = try await PhotoDeletionService.delete {
                throw DeletionTestError.photos
            } trashLocalCopy: {
                didTrash = true
            }
            XCTFail("Expected Photos deletion to fail")
        } catch {
            XCTAssertEqual(error as? DeletionTestError, .photos)
        }
        XCTAssertFalse(didTrash)
    }

    func testLocalFailureReportsPartialSuccessAfterPhotosDeletion() async throws {
        var didDelete = false
        let error = try await PhotoDeletionService.delete {
            didDelete = true
        } trashLocalCopy: {
            XCTAssertTrue(didDelete)
            throw DeletionTestError.local
        }
        XCTAssertTrue(didDelete)
        XCTAssertEqual(error as? DeletionTestError, .local)
    }

    func testSuccessfulDeletionTrashesOnlyAfterPhotosCompletes() async throws {
        var steps: [String] = []
        let error = try await PhotoDeletionService.delete {
            steps.append("photos")
        } trashLocalCopy: {
            steps.append("local")
        }
        XCTAssertNil(error)
        XCTAssertEqual(steps, ["photos", "local"])
    }
}

private enum DeletionTestError: Error {
    case photos, local
}
