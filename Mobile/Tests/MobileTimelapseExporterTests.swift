import UIKit
import XCTest
@testable import ChameoMobile

@MainActor
final class MobileTimelapseExporterTests: XCTestCase {
    func testEmptyExportFailsWithoutLeavingOutput() async {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString).mp4")
        do {
            try await MobileTimelapseExporter.encode(frames: [], to: output) { _ in }
            XCTFail("Expected an empty export to fail")
        } catch MobileTimelapseError.noFrames {
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationRemovesPartialOutput() async throws {
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let image = try XCTUnwrap(rendered.jpegData(compressionQuality: 0.9))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancelled-\(UUID().uuidString).mp4")
        let task = Task {
            try await MobileTimelapseExporter.encode(
                frames: Array(repeating: image, count: 120),
                to: output
            ) { _ in }
        }
        await Task.yield()
        task.cancel()

        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
