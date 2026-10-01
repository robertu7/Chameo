import AppKit
import ImageIO
import XCTest
@testable import Chameo

@MainActor
final class LocalPhotoStoreTests: XCTestCase {
    func testDisabledByDefaultAndDoesNotWrite() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let settings = await fixture.store.settings()
        XCTAssertFalse(settings.isEnabled)
        let saved = try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        XCTAssertFalse(saved)
        XCTAssertTrue(try fixture.photos().isEmpty)
    }

    func testPreservesBytesFormatAndIndexAcrossRecreation() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        let data = try localTestJPEG()
        let snapshot = localTestSnapshot()
        try await fixture.store.saveOriginal(data, source: snapshot, fileExtension: "heic")
        let file = try XCTUnwrap(fixture.photos().first)
        XCTAssertEqual(file.pathExtension, "jpg")
        XCTAssertEqual(try Data(contentsOf: file), data)
        let recreated = fixture.recreateStore()
        let settings = await recreated.settings()
        XCTAssertTrue(settings.isEnabled)
        let copy = try await recreated.original(for: snapshot)
        XCTAssertEqual(copy?.data, data)
        XCTAssertTrue(try XCTUnwrap(copy).canRender(snapshot))
        XCTAssertFalse(try XCTUnwrap(copy).canRender(localTestSnapshot(modification: 2)))
    }

    func testConcurrentSavesProduceOneOriginalAndNoPartials() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        let data = try localTestJPEG()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await fixture.store.saveOriginal(data, source: localTestSnapshot())
                }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(try fixture.photos().count, 1)
        XCTAssertFalse(try fixture.contents().contains { $0.pathExtension == "partial" })
        try await fixture.store.saveOriginal(data, source: localTestSnapshot(id: "another"))
        XCTAssertEqual(try fixture.photos().count, 2)
    }

    func testChangingFolderKeepsEarlierOriginalAndDisablingLeavesFiles() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        let data = try localTestJPEG()
        try await fixture.store.saveOriginal(data, source: localTestSnapshot())
        let next = fixture.root.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: next, withIntermediateDirectories: true)
        try await fixture.store.selectFolder(next)
        let copy = try await fixture.store.original(for: localTestSnapshot())
        XCTAssertEqual(copy?.data, data)
        try await fixture.store.saveOriginal(data, source: localTestSnapshot(id: "second"))
        XCTAssertEqual(try fixture.photos().count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: next, includingPropertiesForKeys: nil).count, 1)
        try await fixture.store.setEnabled(false)
        let disabledCopy = try await fixture.store.original(for: localTestSnapshot())
        XCTAssertNil(disabledCopy)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testInvalidDestinationLeavesSettingAndExistingFilesUntouched() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        let previous = await fixture.store.settings()
        do {
            try await fixture.store.selectFolder(fixture.root.appendingPathComponent("missing"))
            XCTFail("Expected missing folder to fail")
        } catch {}
        let current = await fixture.store.settings()
        XCTAssertEqual(current, previous)
        XCTAssertTrue(try fixture.contents().isEmpty)
    }

    func testUserModifiedFileIsPreservedAndRejected() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        let file = try XCTUnwrap(fixture.photos().first)
        let changed = Data("user edited this file".utf8)
        try changed.write(to: file)
        do { _ = try await fixture.store.original(for: localTestSnapshot()); XCTFail("Expected integrity failure") }
        catch { XCTAssertEqual(error as? LocalPhotoError, .fileChanged) }
        do { try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot()); XCTFail("Must not replace user changes") }
        catch {}
        XCTAssertEqual(try Data(contentsOf: file), changed)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testCancelledSaveDoesNotCreateFile() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        let data = try localTestJPEG()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await fixture.store.saveOriginal(data, source: localTestSnapshot())
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(try fixture.contents().isEmpty)
    }

    func testStaleBookmarkIsRefreshedAndAccessIsBalanced() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        fixture.access.markStale()
        _ = try await fixture.store.activeFolderURL()
        XCTAssertEqual(fixture.access.bookmarkCount, 2)
        XCTAssertEqual(fixture.access.starts, fixture.access.stops)
    }

    func testCorruptIndexNeverOverwritesOriginalFiles() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.selectFolder(fixture.folder)
        try Data("broken index".utf8).write(to: fixture.indexURL)
        let store = fixture.recreateStore()
        do { try await store.saveOriginal(try localTestJPEG(), source: localTestSnapshot()); XCTFail("Expected index error") }
        catch {}
        XCTAssertTrue(try fixture.photos().isEmpty)
        XCTAssertEqual(try Data(contentsOf: fixture.indexURL), Data("broken index".utf8))
    }
}

final class LocalPhotoFixture: @unchecked Sendable {
    let root: URL
    let folder: URL
    let indexURL: URL
    let preferences: LocalPhotoPreferences
    let access = TestPhotoFolderAccess()
    let store: LocalPhotoStore
    private let defaults: UserDefaults
    private let suite: String

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("LocalPhotoTests-\(UUID().uuidString)")
        folder = root.appendingPathComponent("photos")
        indexURL = root.appendingPathComponent("index.json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        suite = "LocalPhotoTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        preferences = LocalPhotoPreferences(defaults: defaults)
        store = LocalPhotoStore(indexURL: indexURL, preferences: preferences, folderAccess: access)
    }

    func recreateStore() -> LocalPhotoStore {
        LocalPhotoStore(indexURL: indexURL, preferences: preferences, folderAccess: access)
    }
    func contents() throws -> [URL] { try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) }
    func photos() throws -> [URL] { try contents().filter { !$0.lastPathComponent.hasPrefix(".") } }
    func remove() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suite)
    }
}

final class TestPhotoFolderAccess: LocalPhotoFolderAccess, @unchecked Sendable {
    private let lock = NSLock()
    private var stale = false
    private var counts = (bookmarks: 0, starts: 0, stops: 0)
    var bookmarkCount: Int { lock.withLock { counts.bookmarks } }
    var starts: Int { lock.withLock { counts.starts } }
    var stops: Int { lock.withLock { counts.stops } }
    func markStale() { lock.withLock { stale = true } }
    func bookmark(for url: URL) throws -> Data {
        lock.withLock { counts.bookmarks += 1; stale = false }
        return Data(url.path.utf8)
    }
    func resolve(_ bookmark: Data) throws -> ResolvedLocalPhotoFolder {
        ResolvedLocalPhotoFolder(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)),
                                isStale: lock.withLock { stale })
    }
    func startAccessing(_ url: URL) -> Bool { lock.withLock { counts.starts += 1 }; return true }
    func stopAccessing(_ url: URL) { lock.withLock { counts.stops += 1 } }
}

func localTestSnapshot(id: String = "asset", modification: Double = 1, edited: Bool = false) -> LocalPhotoSnapshot {
    LocalPhotoSnapshot(identifier: id, createdAt: Date(timeIntervalSince1970: 0),
                       modificationDate: Date(timeIntervalSince1970: modification),
                       pixelWidth: 24, pixelHeight: 16, hasAdjustments: edited)
}

func localTestJPEG(orientation: Int = 1) throws -> Data {
    let context = try XCTUnwrap(CGContext(data: nil, width: 24, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 24, height: 16))
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()),
                              [kCGImagePropertyOrientation: orientation] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
}
