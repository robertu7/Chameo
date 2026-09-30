import AVFoundation
import CoreGraphics
import Photos
import XCTest
@testable import Chameo

final class TimelapseServiceTests: XCTestCase {
    func testFailureKeepsExistingDestinationAndCleansStaging() async throws {
        let url = try destination()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data("original".utf8).write(to: url)
        var staged: URL?
        do {
            try await TimelapseService.generateFile(to: url) { stagingURL in
                staged = stagingURL
                try Data("partial".utf8).write(to: stagingURL)
                throw TimelapseError.writingFailed
            }
            XCTFail("Expected failure")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(staged).deletingLastPathComponent().path))
    }

    func testCancellationBeforeCommitKeepsExistingFile() async throws {
        let url = try destination()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data("original".utf8).write(to: url)
        let task = Task {
            try await TimelapseService.generateFile(to: url) { staged in
                try Data("new".utf8).write(to: staged)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
    }

    func testSuccessfulCommitReplacesExistingVideo() async throws {
        let url = try destination()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data("original".utf8).write(to: url)
        try await TimelapseService.generateFile(to: url) { staged in
            try Data("complete".utf8).write(to: staged)
        }
        XCTAssertEqual(try Data(contentsOf: url), Data("complete".utf8))
    }

    func testFinalizationCanCancelWithoutFrameworkCallback() async {
        let task = Task { try await TimelapseService.waitForFinalization(isFinished: { false }) }
        await Task.yield()
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    private func destination() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("video.mp4")
    }
}

// Exercise the real encoder with generated pixels, without requiring Photos access.

extension TimelapseServiceTests {
    func testRealEncoderWritesAllFramesAndReportsSavingBeforeCommit() async throws {
        let url = try destination()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let events = ProgressEvents()
        let image = try testImage()
        try await TimelapseService.generate(
            assets: [ChameoAsset(asset: PHAsset()), ChameoAsset(asset: PHAsset())],
            to: url, onProgress: { event in await events.add(event) },
            imageLoader: { _, download in
                await download(0.5)
                return image
            }
        )
        let captured = await events.values
        XCTAssertEqual(captured, [.preparing, .loadingPhoto(0), .downloadingPhoto(0, 0.5),
                                  .framesWritten(1), .loadingPhoto(1), .downloadingPhoto(1, 0.5),
                                  .framesWritten(2), .saving])
        let duration = try await AVURLAsset(url: url).load(.duration)
        XCTAssertEqual(duration.seconds, 0.2, accuracy: 0.02)
        let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
        let size = try await XCTUnwrap(tracks.first).load(.naturalSize)
        XCTAssertEqual(size.width, 1080)
        XCTAssertEqual(size.height, 1080)
    }

    func testPhotoLoadingCancellationKeepsExistingVideo() async throws {
        let url = try destination()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data("original".utf8).write(to: url)
        let events = ProgressEvents()
        let task = Task {
            try await TimelapseService.generate(
                assets: [ChameoAsset(asset: PHAsset())], to: url,
                onProgress: { event in await events.add(event) },
                imageLoader: { _, _ in
                    try await Task.sleep(for: .seconds(30))
                    return try self.testImage()
                }
            )
        }
        for _ in 0..<500 {
            if await events.values.contains(.loadingPhoto(0)) { break }
            try await Task.sleep(for: .milliseconds(2))
        }
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
    }

    func testWriterReadinessCanCancelAndDetectFailure() async {
        let task = Task { try await TimelapseService.waitForWriterReadiness(isReady: { false }, isWriting: { true }) }
        await Task.yield()
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        do {
            try await TimelapseService.waitForWriterReadiness(isReady: { false }, isWriting: { false })
            XCTFail("Expected writer failure")
        } catch { XCTAssertEqual(error as? TimelapseError, .writingFailed) }
    }

    func testPhotoRequestCancellationResumesOnceAndRejectsLaterProgress() async throws {
        let state = TimelapseImageRequestState()
        let image = try testImage()
        do {
            let _: CGImage = try await withCheckedThrowingContinuation { continuation in
                XCTAssertTrue(state.install(continuation))
                XCTAssertTrue(state.shouldReportProgress())
                state.cancel(imageManager: .default())
                XCTAssertFalse(state.shouldReportProgress())
                state.resume(returning: image)
            }
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    private func testImage() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        return try XCTUnwrap(context.makeImage())
    }
}

private actor ProgressEvents {
    private(set) var values: [TimelapseProgress] = []
    func add(_ value: TimelapseProgress) { values.append(value) }
}

extension TimelapseServiceTests {
    func testSinglePhotoProducesOneTenthSecondVideo() async throws {
        let url = try destination()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let image = try testImage()
        try await TimelapseService.generate(
            assets: [ChameoAsset(asset: PHAsset())], to: url,
            imageLoader: { _, _ in image }
        )
        let duration = try await AVURLAsset(url: url).load(.duration)
        XCTAssertEqual(duration.seconds, 0.1, accuracy: 0.02)
    }
}
