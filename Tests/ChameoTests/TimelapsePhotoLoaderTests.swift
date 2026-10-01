import CoreGraphics
import Foundation
import XCTest
@testable import Chameo

@MainActor
final class TimelapsePhotoLoaderTests: XCTestCase {
    func testValidLocalOriginalWorksWithoutPhotosImageRequest() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG()
        try await fixture.store.saveOriginal(data, source: localTestSnapshot())
        let source = try TestTimelapsePhotoSource(data: data)
        source.failCurrentImage()
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        let image = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(image.width, 24)
        XCTAssertEqual(image.height, 16)
        XCTAssertEqual(source.originalRequests, 0)
        XCTAssertEqual(source.currentRequests, 0)
        let failures = await loader.failureCount
        XCTAssertEqual(failures, 0)
    }

    func testDownloadsOlderOriginalOnceAndReusesIt() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(source.originalRequests, 1)
        XCTAssertEqual(source.currentRequests, 0)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testPhotosEditKeepsOriginalAndUsesCurrentImage() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG()
        try await fixture.store.saveOriginal(data, source: localTestSnapshot())
        let source = try TestTimelapsePhotoSource(data: data, snapshot: localTestSnapshot(modification: 2, edited: true))
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        let image = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(source.currentRequests, 1)
        XCTAssertEqual(source.originalRequests, 0)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(fixture.photos().first)), data)
    }

    func testOlderEditedPhotoArchivesOriginalAndCombinesDownloadProgress() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG()
        let source = try TestTimelapsePhotoSource(data: data, snapshot: localTestSnapshot(edited: true))
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        let progress = LocalPhotoProgressProbe()
        let image = try await loader.image(for: "asset") { await progress.append($0) }
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(source.originalRequests, 1)
        XCTAssertEqual(source.currentRequests, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(fixture.photos().first)), data)
        let events = await progress.values
        XCTAssertEqual(events, events.sorted())
        XCTAssertEqual(events.last, 1)
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(source.originalRequests, 1)
    }

    func testEditDuringOriginalDownloadUsesCurrentPhotosImage() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        source.changeDuringDownload(to: localTestSnapshot(modification: 2, edited: true))
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        let image = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(source.currentRequests, 1)
        let stored = try await fixture.store.original(for: localTestSnapshot())
        XCTAssertFalse(try XCTUnwrap(stored).representsCurrentOriginal)
    }

    func testUserModifiedLocalPhotoFallsBackWithoutReplacingIt() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        let file = try XCTUnwrap(fixture.photos().first)
        let changed = Data("corrupt or edited file".utf8)
        try changed.write(to: file)
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(source.currentRequests, 1)
        XCTAssertEqual(source.originalRequests, 0)
        XCTAssertEqual(try Data(contentsOf: file), changed)
        let failures = await loader.failureCount
        XCTAssertEqual(failures, 1)
    }

    func testMissingLocalFileIsDownloadedAgain() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        try FileManager.default.removeItem(at: XCTUnwrap(fixture.photos().first))
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(source.originalRequests, 1)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testUnavailableFolderSkipsOriginalDownloadAndFallsBack() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.folder)
        try Data("blocked destination".utf8).write(to: fixture.folder)
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(source.currentRequests, 1)
        XCTAssertEqual(source.originalRequests, 0)
        let failures = await loader.failureCount
        XCTAssertEqual(failures, 1)
    }

    func testLocalWriteFailureStillUsesDownloadedOriginal() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        // The index parent becomes a file, simulating a persistence failure.
        let blocked = fixture.root.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        let store = LocalPhotoStore(indexURL: blocked.appendingPathComponent("index.json"),
                                   preferences: fixture.preferences, folderAccess: fixture.access, fixedFolderURL: fixture.folder)
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let loader = TimelapsePhotoLoader(store: store, source: source)
        let image = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(image.width, 24)
        XCTAssertEqual(source.currentRequests, 0)
        let failures = await loader.failureCount
        XCTAssertEqual(failures, 1)
    }

    func testDisabledStoreUsesPhotosEvenWithLocalOriginal() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        try await fixture.store.setEnabled(false)
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        _ = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(source.currentRequests, 1)
        XCTAssertEqual(source.originalRequests, 0)
    }

    func testLocalOriginalOrientationIsAppliedWithoutDownsizing() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG(orientation: 6)
        try await fixture.store.saveOriginal(data, source: localTestSnapshot())
        let loader = TimelapsePhotoLoader(store: fixture.store, source: try TestTimelapsePhotoSource(data: data))
        let image = try await loader.image(for: "asset", onDownload: { _ in })
        XCTAssertEqual(image.width, 16)
        XCTAssertEqual(image.height, 24)
    }

    func testCancelledDownloadDoesNotFallBackOrSaveOriginal() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        source.cancelOriginalDownload()
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        do { _ = try await loader.image(for: "asset", onDownload: { _ in }); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(source.currentRequests, 0)
        XCTAssertTrue(try fixture.photos().isEmpty)
        let failures = await loader.failureCount
        XCTAssertEqual(failures, 0)
    }

    func testUnavailableBothSourcesFailsExportImageLoading() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let source = try TestTimelapsePhotoSource(data: localTestJPEG())
        source.failOriginalDownload()
        source.failCurrentImage()
        let loader = TimelapsePhotoLoader(store: fixture.store, source: source)
        do { _ = try await loader.image(for: "asset", onDownload: { _ in }); XCTFail("Expected image failure") }
        catch { XCTAssertEqual(error as? TimelapseError, .imageUnavailable) }
        XCTAssertTrue(try fixture.photos().isEmpty)
    }
}

final class TestTimelapsePhotoSource: TimelapsePhotoSource, @unchecked Sendable {
    private let lock = NSLock()
    private let data: Data
    private let current: CGImage
    private var state: LocalPhotoSnapshot
    private var nextState: LocalPhotoSnapshot?
    private var originalError: Error?
    private var currentError: Error?
    private var originalCount = 0
    private var currentCount = 0
    var originalRequests: Int { lock.withLock { originalCount } }
    var currentRequests: Int { lock.withLock { currentCount } }

    init(data: Data, snapshot: LocalPhotoSnapshot = localTestSnapshot()) throws {
        self.data = data
        state = snapshot
        let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        current = try XCTUnwrap(context.makeImage())
    }

    func failCurrentImage() { lock.withLock { currentError = TimelapseError.imageUnavailable } }
    func failOriginalDownload() { lock.withLock { originalError = TimelapseError.imageUnavailable } }
    func cancelOriginalDownload() { lock.withLock { originalError = CancellationError() } }
    func changeDuringDownload(to snapshot: LocalPhotoSnapshot) { lock.withLock { nextState = snapshot } }
    func snapshot(for identifier: String) throws -> LocalPhotoSnapshot { lock.withLock { state } }

    func original(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> PhotoOriginalData {
        let (snapshot, error) = lock.withLock { originalCount += 1; return (state, originalError) }
        if let error { throw error }
        for value in [0.2, 0.8, 1] { await onDownload(value) }
        lock.withLock { if let nextState { state = nextState } }
        return PhotoOriginalData(data: data, fileExtension: "jpg", source: snapshot)
    }

    func currentImage(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> CGImage {
        let error = lock.withLock { currentCount += 1; return currentError }
        if let error { throw error }
        for value in [0.2, 0.8, 1] { await onDownload(value) }
        return current
    }
}

actor LocalPhotoProgressProbe {
    private(set) var values: [Double] = []
    func append(_ value: Double) { values.append(value) }
}
