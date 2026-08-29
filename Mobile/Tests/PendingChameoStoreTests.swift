import ChameoCore
import XCTest
@testable import ChameoMobile

@MainActor
final class PendingChameoStoreTests: XCTestCase {
    func testPendingChameoRoundTripsAndCanBeDiscarded() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingChameoStore(directory: directory)
        let metadata = PendingChameoMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_000),
            location: CaptureLocation(
                latitude: 1,
                longitude: 2,
                altitude: 3,
                horizontalAccuracy: 4,
                capturedAt: Date(timeIntervalSince1970: 999)
            ),
            faceCaptureQualityScore: 0.8
        )
        let pending = PendingChameo(data: Data([1, 2, 3]), metadata: metadata)

        try await store.save(pending)
        let restored = try await store.load()

        XCTAssertEqual(restored?.data, pending.data)
        XCTAssertEqual(restored?.metadata, metadata)
        try await store.discard()
        let discarded = try await store.load()
        XCTAssertNil(discarded)
    }
}
