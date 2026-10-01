import AppKit
import ImageIO
import XCTest
@testable import Chameo

@MainActor
final class LocalPhotoStoreTests: XCTestCase {
    func testEnabledByDefaultAndSavesWithoutFolderSelection() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let settings = await fixture.store.settings()
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.activeFolder?.displayPath, fixture.folder.path)
        let saved = try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        XCTAssertTrue(saved)
        XCTAssertEqual(try fixture.photos().count, 1)
        XCTAssertEqual(fixture.access.bookmarkCount, 0)
        XCTAssertEqual(fixture.access.starts, 0)
    }

    func testCreatesFixedFolderOnSaveButNotDuringInitialization() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.folder)
        let store = fixture.recreateStore()
        _ = await store.settings()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.folder.path))
        try await store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testPreservesBytesFormatAndIndexAcrossRecreation() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
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

    func testMigratesCustomFolderForFutureWritesAndKeepsEarlierOriginal() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG()
        try await fixture.store.saveOriginal(data, source: localTestSnapshot())
        let legacy = try await fixture.makeLegacyFolder()
        let store = fixture.recreateStore()
        let settings = await store.settings()
        XCTAssertEqual(settings.activeFolder?.displayPath, fixture.folder.path)
        let copy = try await store.original(for: localTestSnapshot())
        XCTAssertEqual(copy?.data, data)
        try await store.saveOriginal(data, source: localTestSnapshot(id: "second"))
        XCTAssertEqual(try fixture.photos().count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil).count, 1)
        let recreatedCopy = try await fixture.recreateStore().original(for: localTestSnapshot())
        XCTAssertEqual(recreatedCopy?.data, data)
        try await store.setEnabled(false)
        let disabledCopy = try await store.original(for: localTestSnapshot())
        XCTAssertNil(disabledCopy)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testBlockedFixedFolderCannotEnableAndDoesNotOverwriteUserFile() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.setEnabled(false)
        try FileManager.default.removeItem(at: fixture.folder)
        let data = Data("user file".utf8)
        try data.write(to: fixture.folder)
        let previous = await fixture.store.settings()
        do {
            try await fixture.store.setEnabled(true)
            XCTFail("Expected blocked folder to fail")
        } catch {}
        let current = await fixture.store.settings()
        XCTAssertEqual(current, previous)
        XCTAssertEqual(try Data(contentsOf: fixture.folder), data)
    }

    func testUserModifiedFileIsPreservedAndRejected() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
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
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        _ = try await fixture.makeLegacyFolder()
        let store = fixture.recreateStore()
        fixture.access.markStale()
        _ = try await store.original(for: localTestSnapshot())
        XCTAssertEqual(fixture.access.bookmarkCount, 1)
        XCTAssertEqual(fixture.access.starts, fixture.access.stops)
    }

    func testSavedOffSettingSurvivesMigrationAndRecreation() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let folder = LocalPhotoFolder(id: UUID(), bookmark: Data(fixture.root.path.utf8), displayPath: fixture.root.path)
        try fixture.preferences.save(LocalPhotoConfiguration(isEnabled: false, activeFolderID: folder.id, folders: [folder]))
        let store = fixture.recreateStore()
        let settings = await store.settings()
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.activeFolder?.displayPath, fixture.folder.path)
        let saved = try await store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        XCTAssertFalse(saved)
        XCTAssertTrue(try fixture.photos().isEmpty)
    }

    func testCorruptIndexNeverOverwritesOriginalFiles() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try Data("broken index".utf8).write(to: fixture.indexURL)
        let store = fixture.recreateStore()
        do { try await store.saveOriginal(try localTestJPEG(), source: localTestSnapshot()); XCTFail("Expected index error") }
        catch {}
        XCTAssertTrue(try fixture.photos().isEmpty)
        XCTAssertEqual(try Data(contentsOf: fixture.indexURL), Data("broken index".utf8))
    }
}

extension LocalPhotoStoreTests {
    func testAutomaticSaveRespectsRemovalAndExplicitSaveRestoresCopy() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG()
        let snapshot = localTestSnapshot()
        try await fixture.store.saveOriginal(data, source: snapshot)
        try FileManager.default.removeItem(at: XCTUnwrap(fixture.photos().first))
        let store = fixture.recreateStore()
        let automaticSave = try await store.saveOriginal(data, source: snapshot)
        XCTAssertFalse(automaticSave)
        XCTAssertTrue(try fixture.photos().isEmpty)
        let restored = try await store.saveOriginal(data, source: snapshot, restoreMissingCopy: true)
        XCTAssertTrue(restored)
        let copy = try await fixture.recreateStore().original(for: snapshot)
        XCTAssertEqual(copy?.data, data)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testTrashMovesOnlyIndexedCopyEvenWhenKeepingCopiesIsOff() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        let file = try XCTUnwrap(fixture.photos().first)
        let unrelated = fixture.folder.appendingPathComponent("user-photo.jpg")
        try Data("user-owned photo".utf8).write(to: unrelated)
        let trash = fixture.root.appendingPathComponent("trash")
        let store = LocalPhotoStore(indexURL: fixture.indexURL, preferences: fixture.preferences,
                                   folderAccess: fixture.access, fixedFolderURL: fixture.folder,
                                   trashItem: { try FileManager.default.moveItem(at: $0, to: trash) })
        try await store.setEnabled(false)
        try await store.trashOriginal(for: "unknown")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try await store.trashOriginal(for: "asset")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        try await store.trashOriginal(for: "asset")
        let remembered = try await fixture.recreateStore().hasSavedOriginal(for: "asset")
        XCTAssertTrue(remembered)
    }

    func testTrashPreservesModifiedCopyAndReportsFailure() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        let file = try XCTUnwrap(fixture.photos().first)
        let changed = Data("user edits".utf8)
        try changed.write(to: file)
        let store = LocalPhotoStore(indexURL: fixture.indexURL, preferences: fixture.preferences,
                                   folderAccess: fixture.access, fixedFolderURL: fixture.folder,
                                   trashItem: { _ in XCTFail("Must not trash a changed user file") })
        do { try await store.trashOriginal(for: "asset"); XCTFail("Expected changed file error") }
        catch { XCTAssertEqual(error as? LocalPhotoError, .fileChanged) }
        XCTAssertEqual(try Data(contentsOf: file), changed)
    }

    func testLegacyCopyCanBeTrashedWithBalancedFolderAccess() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot())
        let legacy = try await fixture.makeLegacyFolder()
        let trash = fixture.root.appendingPathComponent("trash")
        let store = LocalPhotoStore(indexURL: fixture.indexURL, preferences: fixture.preferences,
                                   folderAccess: fixture.access, fixedFolderURL: fixture.folder,
                                   trashItem: { try FileManager.default.moveItem(at: $0, to: trash) })
        try await store.trashOriginal(for: "asset")
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: legacy.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.path))
        XCTAssertGreaterThan(fixture.access.starts, 0)
        XCTAssertEqual(fixture.access.starts, fixture.access.stops)
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
        store = LocalPhotoStore(indexURL: indexURL, preferences: preferences, folderAccess: access, fixedFolderURL: folder)
    }

    func recreateStore() -> LocalPhotoStore {
        LocalPhotoStore(indexURL: indexURL, preferences: preferences, folderAccess: access, fixedFolderURL: folder)
    }

    /// Reproduce the old bookmark-backed preferences and indexed folder identity.
    func makeLegacyFolder() async throws -> URL {
        let current = await store.settings()
        let active = try XCTUnwrap(current.activeFolder)
        let legacy = root.appendingPathComponent("legacy")
        try FileManager.default.moveItem(at: folder, to: legacy)
        let oldFolder = LocalPhotoFolder(id: active.id, bookmark: Data(legacy.path.utf8), displayPath: legacy.path)
        try preferences.save(LocalPhotoConfiguration(isEnabled: current.isEnabled,
                                                    activeFolderID: oldFolder.id, folders: [oldFolder]))
        return legacy
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
