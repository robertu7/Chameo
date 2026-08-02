import Foundation
import XCTest
@testable import ChameoCore

final class CaptureMetadataTests: XCTestCase {
    func testLegacyPendingMetadataDecodesWithoutQualityScore() throws {
        let json = #"{"capturedAt":0,"location":null}"#.data(using: .utf8)!
        let metadata = try JSONDecoder().decode(PendingChameoMetadata.self, from: json)
        XCTAssertNil(metadata.faceCaptureQualityScore)
    }
}
