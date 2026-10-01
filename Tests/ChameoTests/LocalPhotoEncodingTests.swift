import AVFoundation
import CoreGraphics
import ImageIO
import Photos
import UserNotifications
import XCTest
@testable import Chameo

@MainActor
final class LocalPhotoEncodingTests: XCTestCase {
    func testLocalFirstResolverProducesReal1080SquareVideoAndPreservesCenterCrop() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try stripedJPEG()
        let snapshot = localTestSnapshot()
        try await fixture.store.saveOriginal(data, source: snapshot)
        let source = try TestTimelapsePhotoSource(data: data)
        source.failCurrentImage()
        let video = fixture.root.appendingPathComponent("video.mp4")
        let summary = try await TimelapseService.generate(
            assets: [ChameoAsset(asset: PHAsset()), ChameoAsset(asset: PHAsset())],
            to: video, localPhotos: fixture.store, photoSource: source
        )
        XCTAssertEqual(summary.localCopyFailures, 0)
        XCTAssertEqual(source.currentRequests, 0)
        XCTAssertEqual(source.originalRequests, 0)
        let asset = AVURLAsset(url: video)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 0.2, accuracy: 0.02)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1080))
        let formatDescriptions = try await track.load(.formatDescriptions)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(try XCTUnwrap(formatDescriptions.first)), kCMVideoCodecType_H264)
        let generator = AVAssetImageGenerator(asset: asset)
        let (frame, _) = try await generator.image(at: .zero)
        // The source's outer quarters are red and green. Center-cropping must
        // fill the square with its blue middle half, including near the edges.
        for x in [80, 540, 1000] {
            let pixel = try rgba(frame, x: x, y: 540)
            XCTAssertGreaterThan(pixel[2], 180)
            XCTAssertLessThan(pixel[0], 70)
            XCTAssertLessThan(pixel[1], 70)
        }
    }

    func testRealEncoderStillCompletesWhenLocalFolderFails() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.folder)
        try Data("blocked destination".utf8).write(to: fixture.folder)
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let video = fixture.root.appendingPathComponent("video.mp4")
        let summary = try await TimelapseService.generate(
            assets: [ChameoAsset(asset: PHAsset())], to: video,
            localPhotos: fixture.store, photoSource: source
        )
        XCTAssertEqual(summary.localCopyFailures, 1)
        XCTAssertEqual(source.currentRequests, 1)
        let duration = try await AVURLAsset(url: video).load(.duration)
        XCTAssertEqual(duration.seconds, 0.1, accuracy: 0.02)
    }

    func testExportCombinesLocalAndNotificationWarnings() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.folder)
        try Data("blocked destination".utf8).write(to: fixture.folder)
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let notices = LocalPhotoFailingNotifications()
        let controller = TimelapseExportController(notifications: notices, localPhotos: fixture.store,
                                                   photoSource: source, announce: { _ in })
        controller.prepare(assets: [ChameoAsset(asset: PHAsset())])
        controller.destinationChosen(fixture.root.appendingPathComponent("video.mp4"))
        for _ in 0..<500 {
            if notices.attempted { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard case .succeeded = controller.state else { return XCTFail("Expected successful export") }
        let note = try XCTUnwrap(controller.completionNote)
        XCTAssertTrue(note.contains("Some original photos"))
        XCTAssertTrue(note.contains("notification could not be sent"))
    }

    private func stripedJPEG() throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for (rect, color) in [
            (CGRect(x: 0, y: 0, width: 16, height: 32), CGColor(red: 1, green: 0, blue: 0, alpha: 1)),
            (CGRect(x: 16, y: 0, width: 32, height: 32), CGColor(red: 0, green: 0, blue: 1, alpha: 1)),
            (CGRect(x: 48, y: 0, width: 16, height: 32), CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        ] {
            context.setFillColor(color)
            context.fill(rect)
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func rgba(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let start = (y * image.width + x) * 4
        return Array(pixels[start..<(start + 4)])
    }
}

@MainActor
private final class LocalPhotoFailingNotifications: TimelapseNotifying {
    private(set) var attempted = false
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func prepareAuthorization() async -> UNAuthorizationStatus { .authorized }
    func deliver(exportID: UUID, filename: String) async throws {
        attempted = true
        throw LocalPhotoError.folderUnavailable
    }
}
